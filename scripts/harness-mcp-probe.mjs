// AI Harness — MCP 읽기 전용 프로브
//
// Layer A 원본. Test-HarnessRuntime.ps1 이 런타임 설치 디렉터리로 복사한 뒤 실행한다.
// 그래야 bare specifier '@modelcontextprotocol/sdk/...' 가 그 런타임의 node_modules 에서 해석된다.
//
// 사용: node <this> <config.json>
// config: { command, args, env, tool, toolArgs, timeoutMs }
// 출력  : 한 줄 JSON. 실패해도 stdout 으로 구조화된 결과를 낸다.

import { readFileSync } from 'node:fs';

const out = (o) => { process.stdout.write(JSON.stringify(o)); };

let cfg;
try {
  cfg = JSON.parse(readFileSync(process.argv[2], 'utf8'));
} catch (e) {
  out({ ok: false, stage: 'config', error: String(e && e.message || e) });
  process.exit(2);
}

const timeoutMs = cfg.timeoutMs ?? 60000;
let client = null;

const timer = setTimeout(() => {
  out({ ok: false, stage: 'timeout', error: `probe exceeded ${timeoutMs}ms` });
  process.exit(3);
}, timeoutMs);

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

  client = new Client({ name: 'harness-probe', version: '1.0.0' });
  await client.connect(transport);

  const result = { ok: true, stage: 'handshake' };

  // ── 호출 순서가 중요하다 ────────────────────────────────────────────────
  // SDK 는 listTools() 결과로 도구별 출력 검증기를 캐시한다. 그 뒤 callTool 을 하면
  // outputSchema 를 선언한 도구가 structuredContent 를 반환하지 않을 때 클라이언트가 거부한다.
  //   MCP error -32600: Tool X has an output schema but did not return structured content
  // 이 런타임(3.4.4)이 정확히 그 상태다. 서버 자체는 정상 동작한다.
  // 따라서 검증 호출을 먼저 하고, 도구 목록은 그 뒤에 센다.
  if (cfg.tool) {
    try {
      const called = await client.callTool({ name: cfg.tool, arguments: cfg.toolArgs ?? {} });
      const text = (called.content ?? [])
        .filter((c) => c.type === 'text')
        .map((c) => c.text)
        .join('\n');

      // isError 만 믿지 않는다. 서버가 오류 상황을 성공한 호출로 반환하는 경우가 있다.
      result.stage = 'tool_call';
      result.is_error = called.isError === true;
      result.text = text;
      result.ok = called.isError !== true;
    } catch (callErr) {
      const msg = String(callErr && callErr.message || callErr);
      clearTimeout(timer);
      out({ ...result, ok: false, stage: /not found|unknown tool/i.test(msg) ? 'tool_missing' : 'tool_call_failed', error: msg });
      process.exit(4);
    }
  }

  // 도구 개수는 참고 정보다. 실패해도 검증 결과를 뒤집지 않는다.
  try {
    const tools = await client.listTools();
    const toolNames = (tools.tools ?? []).map((t) => t.name);
    result.tool_count = toolNames.length;
    result.tools = toolNames;
  } catch (listErr) {
    result.tool_count = null;
    result.list_error = String(listErr && listErr.message || listErr);
  }

  clearTimeout(timer);
  out(result);
  process.exit(result.ok ? 0 : 5);
} catch (e) {
  clearTimeout(timer);
  out({ ok: false, stage: 'exception', error: String(e && e.message || e) });
  process.exit(6);
} finally {
  try { if (client) await client.close(); } catch { /* 무시 */ }
}
