import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { sourceIdentity } from './harness-project.mjs';
import { PHASES, routeTask } from './harness-engine.mjs';

export function validateHarness(root) {
  root = fs.realpathSync(root);
  const issues = [], add = (code, message) => issues.push({ code, message });
  let identity;
  try { identity = sourceIdentity(root); } catch (error) { add('SOURCE_CONTRACT', error.message); }
  const policyIndex = fs.readFileSync(path.join(root, 'POLICY_INDEX.yaml'), 'utf8');
  const refs = [...policyIndex.matchAll(/^\s+file:\s*"([^"]+)"/gm)].map(x => x[1]);
  if (refs.length !== 26 || new Set(refs).size !== 26) add('POLICY_INDEX', '26 unique existing policies must remain registered.');
  for (const ref of refs) if (!fs.existsSync(path.join(root, 'policies', ref))) add('MISSING_POLICY', ref);
  for (const file of ['.claude-plugin/marketplace.json', 'plugins/ai-harness/.claude-plugin/plugin.json']) {
    const value = JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
    const versions = file.includes('marketplace') ? [value.metadata.version, ...value.plugins.map(x => x.version)] : [value.version];
    for (const v of versions) if (v !== identity?.version) add('ADAPTER_VERSION_MISMATCH', file);
  }
  const docs = [...fs.readdirSync(path.join(root, 'harness/runtime')).filter(x => x.endsWith('.md')).map(x => 'harness/runtime/' + x),
    ...fs.readdirSync(path.join(root, 'harness/update')).filter(x => x.endsWith('.md')).map(x => 'harness/update/' + x),
    'AGENTS.md', 'CORE.md', 'ROUTER.md', 'PROJECT_INIT.md', 'MIGRATION_NOTES.md', 'CHANGELOG.md'];
  for (const rel of docs) {
    const file = path.join(root, rel);
    if (!fs.existsSync(file)) { add('MISSING_DOCUMENT', rel); continue; }
    const text = fs.readFileSync(file, 'utf8');
    for (const match of text.matchAll(/\[[^\]]+\]\(([^\s)]+)\)/g)) {
      const target = match[1].split('#')[0];
      if (!target || /^(?:https?:|app:|mailto:)/i.test(target)) continue;
      if (!fs.existsSync(path.resolve(path.dirname(file), decodeURIComponent(target)))) add('BROKEN_LINK', `${rel}: ${target}`);
    }
  }
  if (PHASES.length !== 16 || new Set(PHASES).size !== 16) add('PHASE_GRAPH', 'Full lifecycle requires 16 unique phases.');
  for (const request of ['새 프로젝트 시작해줘', '기존 프로젝트에 Harness 설치해줘', '현재 Harness를 v6으로 업데이트해줘', '개발 중인데 Harness 최신버전 적용해줘', '운영 장애가 발생했어', 'DB 구조를 바꿔야 해', 'Framework major version 올려줘']) {
    try {
      const route = routeTask(request, { has_product: !request.startsWith('새'), installed_version: request.includes('Harness') && !request.includes('설치') ? '5.1.0' : null });
      if (!route.workflow.length || route.workflow.some(x => !PHASES.includes(x))) add('DEAD_ROUTING', request);
      for (const rel of route.jit_files) if (!fs.existsSync(path.join(root, rel))) add('MISSING_JIT_REFERENCE', rel);
    } catch (error) { add('ROUTER_ERROR', error.message); }
  }
  return { status: issues.length ? 'FAIL' : 'PASS', timestamp: new Date().toISOString(), harness_version: identity?.version, source_hash: identity?.hash, checks: ['manifest/index/version/payload', '26-policy-preservation', 'adapter-version', 'runtime/update-links', 'phase-graph', 'representative-routing-and-jit-references'], issues };
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const i = process.argv.indexOf('--root'); const root = i >= 0 ? process.argv[i + 1] : path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  let report;
  try { report = validateHarness(root); } catch (error) { report = { status: 'FAIL', issues: [{ code: 'VALIDATOR_ERROR', message: error.message }] }; }
  process.stdout.write(JSON.stringify(report, null, 2) + '\n');
  if (report.status !== 'PASS') process.exitCode = 1;
}
