// AI Harness — Drive 스냅샷 발행 (불변)
//
// Layer A 원본. Publish-HarnessSnapshot.ps1 이 런타임 설치 디렉터리로 복사한 뒤 실행한다.
// 그래야 bare specifier '@modelcontextprotocol/sdk/...' 가 그 런타임의 node_modules 에서 해석된다.
//
// 사용: node <this> <config.json>
// config: { command, args, env, localRoot, driveRoot, label, files:[{rel}], timeoutMs }
// 출력  : 한 줄 JSON.
//
// ── 이 스크립트가 "동기화"가 아니라 "스냅샷"인 이유 ──────────────────────────
// 정본은 GitHub 다. Drive 는 사본이다. 사본을 계속 갱신하려 하면 세 가지가 따라온다.
//   1. 삭제 패스가 필요하다. 없으면 지운 파일이 Drive 에 영원히 남는다.
//   2. update 실패 시 create 로 넘어가면 같은 이름의 파일이 하나 더 생긴다.
//      Drive 는 한 폴더에 동명 파일을 허용하므로 조용히 중복된다.
//   3. "지금 Drive 에 있는 것이 어느 시점의 것인가"를 아무도 답할 수 없다.
// 그래서 갱신하지 않는다. 라벨이 붙은 폴더에 한 번 쓰고 끝낸다.
// 이미 있으면 덮어쓰지 않고 거부한다. 새 스냅샷은 새 라벨로 만든다.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const out = (o) => { process.stdout.write(JSON.stringify(o)); };

let cfg;
try {
  cfg = JSON.parse(readFileSync(process.argv[2], 'utf8'));
} catch (e) {
  out({ ok: false, stage: 'config', error: String((e && e.message) || e) });
  process.exit(2);
}

const timeoutMs = cfg.timeoutMs ?? 900000;
let client = null;
const timer = setTimeout(() => {
  out({ ok: false, stage: 'timeout', error: `snapshot exceeded ${timeoutMs}ms` });
  process.exit(3);
}, timeoutMs);

const text = (r) => (r.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');

try {
  const { Client } = await import('@modelcontextprotocol/sdk/client/index.js');
  const { StdioClientTransport } = await import('@modelcontextprotocol/sdk/client/stdio.js');

  // Windows 의 .cmd 는 직접 spawn 할 수 없으므로 cmd.exe 를 경유한다.
  const isWin = process.platform === 'win32';
  const useShim = isWin && /\.(cmd|bat)$/i.test(cfg.command);
  const transport = new StdioClientTransport({
    command: useShim ? 'cmd.exe' : cfg.command,
    args: useShim ? ['/d', '/s', '/c', cfg.command, ...(cfg.args ?? [])] : (cfg.args ?? []),
    env: { ...process.env, ...(cfg.env ?? {}) },
    stderr: 'pipe',
  });

  client = new Client({ name: 'harness-drive-snapshot', version: '1.0.0' });
  await client.connect(transport);

  const snapshotRoot = `${cfg.driveRoot}/${cfg.label}`;

  // ── 불변성 가드 ─────────────────────────────────────────────────────────
  // 이미 그 라벨이 있으면 아무것도 하지 않는다. 반쯤 덮어쓴 스냅샷은
  // 없는 스냅샷보다 나쁘다. 어느 파일이 언제 것인지 알 수 없기 때문이다.
  let existing = null;
  try {
    const r = await client.callTool({ name: 'resolve_file_path', arguments: { path: snapshotRoot, type: 'folder' } });
    if (r.isError !== true) {
      const t = text(r);
      // 못 찾았다는 응답도 성공한 도구 호출로 올 수 있다. 문구가 아니라 id 유무로 본다.
      if (/[A-Za-z0-9_-]{20,}/.test(t) && !/not\s*found|no\s*such|존재하지/i.test(t)) existing = t.trim();
    }
  } catch { /* 해석 실패는 "없음" 으로 본다. 아래 create 가 사실을 말해 준다. */ }

  if (existing && !cfg.overwriteAcknowledged) {
    clearTimeout(timer);
    out({
      ok: false, stage: 'exists', drive_folder: snapshotRoot,
      error: `스냅샷 라벨이 이미 있습니다: ${snapshotRoot}. 스냅샷은 덮어쓰지 않습니다. 새 라벨로 발행하세요.`,
    });
    process.exit(7);
  }

  const summary = { ok: true, stage: 'upload', drive_folder: snapshotRoot, created: 0, skipped: [], failed: [] };

  // 스냅샷은 스스로를 설명해야 한다. 폴더만 보고 "이게 어느 커밋이냐"를
  // 알 수 없으면 사본으로서 쓸모가 없다.
  if (cfg.snapshotManifest) {
    try {
      const r = await client.callTool({
        name: 'create_file',
        arguments: { name: 'SNAPSHOT.json', content: cfg.snapshotManifest, parentPath: snapshotRoot, type: 'text' },
      });
      if (r.isError === true) throw new Error(text(r) || 'create_file failed');
      summary.created++;
    } catch (e) {
      // 설명 파일을 못 만들면 그 스냅샷은 출처 불명이다. 여기서 멈춘다.
      clearTimeout(timer);
      out({ ok: false, stage: 'manifest', drive_folder: snapshotRoot, error: String((e && e.message) || e) });
      process.exit(8);
    }
  }

  for (const f of cfg.files) {
    const abs = join(cfg.localRoot, ...f.rel.split('/'));
    let buf;
    try {
      buf = readFileSync(abs);
    } catch (e) {
      summary.failed.push({ path: f.rel, error: `read: ${String((e && e.message) || e)}` });
      continue;
    }
    // 이진 파일은 문자열로 올릴 수 없다. utf8 로 강제하면 조용히 손상된다.
    if (buf.includes(0)) {
      summary.skipped.push({ path: f.rel, reason: 'binary' });
      continue;
    }

    const slash = f.rel.lastIndexOf('/');
    const name = slash < 0 ? f.rel : f.rel.slice(slash + 1);
    const parent = slash < 0 ? snapshotRoot : `${snapshotRoot}/${f.rel.slice(0, slash)}`;

    try {
      // type:'text' 를 명시하지 않으면 이름으로 형식을 추론해 .md 가 Google Docs 로 변환된다.
      // 스냅샷은 원본 그대로여야 하므로 항상 평문으로 올린다.
      const r = await client.callTool({
        name: 'create_file',
        arguments: { name, content: buf.toString('utf8'), parentPath: parent, type: 'text' },
      });
      if (r.isError === true) throw new Error(text(r) || 'create_file failed');
      summary.created++;
    } catch (e) {
      summary.failed.push({ path: f.rel, error: String((e && e.message) || e) });
    }
  }

  summary.ok = summary.failed.length === 0;
  clearTimeout(timer);
  out(summary);
  process.exit(summary.ok ? 0 : 5);
} catch (e) {
  clearTimeout(timer);
  out({ ok: false, stage: 'exception', error: String((e && e.message) || e) });
  process.exit(6);
} finally {
  try { if (client) await client.close(); } catch { /* 무시 */ }
}
