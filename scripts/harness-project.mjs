/** Project-only lifecycle transaction. Existing PowerShell installers own machine
 * runtime/config changes; this module never installs packages or changes product code. */
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { routeTask, validateResume } from './harness-engine.mjs';

export const PROJECT_FILE = '.ai/harness-project.json';
export const STATE_FILE = '.ai/harness-state.json';
const TRANSITION = '.ai/transition-manifest.yaml';
const MANAGED = [PROJECT_FILE, STATE_FILE, '.ai/HARNESS.md', '.ai/harness.yaml', 'AGENTS.md', TRANSITION];
const START = '<!-- AI-HARNESS:START -->';
const END = '<!-- AI-HARNESS:END -->';
const stamp = () => new Date().toISOString();
const hash = value => crypto.createHash('sha256').update(value).digest('hex');
const json = value => JSON.stringify(value, null, 2) + '\n';
const secretPattern = /-----BEGIN [A-Z ]*PRIVATE KEY-----|\b(?:gh[pousr]_|sk-)[A-Za-z0-9]{20,}|\bya29\.[A-Za-z0-9_-]{20,}|\bAIza[A-Za-z0-9_-]{30,}|\bxox[baprs]-[A-Za-z0-9-]{10,}/;
export function assertNoSecret(text) {
  if (secretPattern.test(text) || /"(?:private_key|client_secret|refresh_token|access_token|password)"\s*:\s*"[^"\s]+"/.test(text)) {
    throw new Error('SECRET_IN_STATE: move credential values to an environment variable or approved secret store before snapshotting.');
  }
  for (const match of text.matchAll(/^\s*(?:password|client_secret|refresh_token|access_token|api_key|secret|token|private_key)\s*:\s*(.+)$/gim)) {
    const value = match[1].trim();
    if (/^(?:null|["']{2}|\[(?:P\d{2}(?:,\s*)?)+\])$/.test(value)) continue;
    throw new Error('SECRET_IN_STATE: credential YAML scalars are forbidden in project state.');
  }
}
function utf8(bytes) {
  try { return new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes); }
  catch { throw new Error('ENCODING_CONFLICT: project instructions/state must use valid UTF-8; original bytes were preserved.'); }
}
function validateCommand(descriptor, name) {
  if (!descriptor || descriptor.required === false) return;
  if (typeof descriptor.command !== 'string' || !Array.isArray(descriptor.args) || descriptor.args.some(x => typeof x !== 'string') || descriptor.shell || descriptor.env) throw new Error('COMMAND_REQUIRES_ARGV: environment values and shell strings are not stored.');
  assertNoSecret(json(descriptor));
  if (descriptor.args.some(x => /^(?:--?(?:password|secret|token|api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret))(?:=|$)/i.test(x))) throw new Error(`CREDENTIAL_ARGUMENT_FORBIDDEN: ${name}`);
}
function knownLegacy(sourceRoot, text, kind, bindingRoot) {
  const reference = read(sourceRoot, 'harness/update/legacy/PROJECT_INIT_v5_1.md');
  if (!reference) return false;
  const init = utf8(reference);
  const section = kind === 'block' ? init.split('# 10. Adapter Managed Block')[1]?.split('# 11.')[0] : init.split('# 7. `.ai/HARNESS.md`')[1]?.split('# 8.')[0];
  const expected = section?.match(kind === 'block' ? /```markdown\r?\n([\s\S]*?)\r?\n```/ : /```text\r?\n([\s\S]*?)\r?\n```/)?.[1];
  if (!expected) return false;
  const normalize = s => s.replaceAll('\r\n', '\n').replaceAll('\\', '/').trim();
  const content = kind === 'bridge' ? text.replace(/^# AI Harness Project Bridge\r?\n\s*/, '') : text;
  const actualRoot = bindingRoot || text.match(/GLOBAL HARNESS ROOT:\s*\r?\n([^\r\n]+)/)?.[1]?.trim();
  return normalize(content) === normalize(expected.replaceAll('<실제 HARNESS_ROOT>', actualRoot || '').replaceAll('<HARNESS_ROOT>', actualRoot || ''));
}
function rootPath(root) {
  const absolute = path.resolve(root);
  if (!fs.existsSync(absolute) || !fs.statSync(absolute).isDirectory()) throw new Error('PROJECT_ROOT_MISSING');
  return fs.realpathSync(absolute);
}
export function safePath(root, relative) {
  if (!relative || path.isAbsolute(relative) || relative.includes('\\') || relative.split('/').some(x => !x || x === '..' || x === '.')) throw new Error('UNSAFE_RELATIVE_PATH');
  const full = path.resolve(root, relative);
  if (!full.startsWith(path.resolve(root) + path.sep)) throw new Error('PATH_ESCAPES_ROOT');
  let current = root;
  for (const part of relative.split('/')) {
    current = path.join(current, part);
    if (fs.existsSync(current) && fs.lstatSync(current).isSymbolicLink()) throw new Error('SYMLINK_BOUNDARY');
  }
  return full;
}
const read = (root, rel) => { const p = safePath(root, rel); return fs.existsSync(p) ? fs.readFileSync(p) : null; };
function readJson(root, rel, fallback = null) {
  const b = read(root, rel);
  if (!b) return fallback;
  try { return JSON.parse(utf8(b).replace(/^\uFEFF/, '')); }
  catch { throw new Error(`INVALID_CONTRACT: ${rel}`); }
}
function writeAtomic(root, rel, bytes) {
  const target = safePath(root, rel);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  const temp = target + '.tmp-' + crypto.randomUUID();
  try { fs.writeFileSync(temp, bytes, { flag: 'wx' }); fs.renameSync(temp, target); }
  finally { if (fs.existsSync(temp)) fs.unlinkSync(temp); }
}
function version(v) {
  if (v === null || v === undefined) return null;
  const m = String(v).trim().match(/^v?(\d+)\.(\d+)(?:\.(\d+))?$/);
  if (!m) throw new Error('UNKNOWN_VERSION_FORMAT');
  return `${m[1]}.${m[2]}.${m[3] || '0'}`;
}
function legacyBinding(text) {
  if (!text) return {};
  if (text.trim().startsWith('{')) {
    const parsed = JSON.parse(text);
    return parsed.harness || parsed;
  }
  // Only extract existing scalar binding fields. Unknown YAML fields are retained
  // verbatim as a compatibility reference; they are never executed as commands.
  const fields = {};
  const section = text.match(/(?:^|\n)harness:\s*\r?\n((?:[ \t]+[^\n]*\n?|\s*\n)*)/);
  if (!section) throw new Error('LEGACY_BINDING_NOT_RECOGNIZED');
  for (const key of ['version', 'root']) {
    const m = section[1].match(new RegExp(`^\\s+${key}:\\s*(.+)$`, 'm'));
    if (m) fields[key] = m[1].trim().replace(/^(["'])(.*)\1$/, '$2');
  }
  return fields;
}
function git(root, args) {
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8', timeout: 15000, windowsHide: true });
  return result.status === 0 ? result.stdout.trim() : null;
}
function managedFiles(project) {
  return [...MANAGED, ...['CLAUDE.md', 'GEMINI.md'].filter(x => fs.existsSync(safePath(project, x)))];
}
function fileHashes(root, files) {
  return Object.fromEntries(files.map(rel => { const b = read(root, rel); return [rel, b === null ? null : hash(b)]; }));
}
function block(text) {
  const first = text.indexOf(START), last = text.indexOf(END);
  if (first < 0 && last < 0) return null;
  if (first < 0 || last < first || text.indexOf(START, first + START.length) >= 0 || text.indexOf(END, last + END.length) >= 0) throw new Error('MALFORMED_MANAGED_BLOCK');
  return { start: first, end: last + END.length, text: text.slice(first, last + END.length) };
}
function replaceBlock(text, newBlock) {
  const old = block(text);
  return old ? text.slice(0, old.start) + newBlock + text.slice(old.end) : text + (text && !text.endsWith('\n') ? '\n' : '') + '\n' + newBlock + '\n';
}
function productInventory(root) {
  const rows = [];
  let count = 0;
  const skip = new Set(['.git', '.ai', 'node_modules', 'dist', 'build', '.next', '.venv', 'venv', '.harness-releases']);
  function walk(dir, prefix = '') {
    for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
      if (skip.has(entry.name)) continue;
      if (++count > 25000) throw new Error('INVENTORY_LIMIT: narrow large generated directories explicitly.');
      const rel = prefix + entry.name;
      const p = path.join(dir, entry.name);
      if (entry.isSymbolicLink()) { rows.push([rel, 'LINK', hash(fs.readlinkSync(p))]); continue; }
      if (entry.isDirectory()) walk(p, rel + '/');
      else if (entry.isFile()) {
        let bytes = fs.readFileSync(p);
        if (['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(rel)) {
          const text = utf8(bytes); const managed = block(text);
          if (managed) bytes = Buffer.from(text.slice(0, managed.start) + text.slice(managed.end));
          // A first managed block is append-only; track actual unmanaged bytes separately.
        }
        rows.push([rel, 'FILE', hash(bytes)]);
      }
    }
  }
  walk(root);
  return { files: rows, hash: hash(json(rows)) };
}
function productGuard(root) {
  const inventory = productInventory(root);
  // Instructions are separately checked byte-for-byte outside the managed span.
  return { hash: hash(json(inventory.files.filter(x => !['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(x[0])))), files: inventory.files.filter(x => !['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(x[0])) };
}
export function projectFingerprint(project) { return productGuard(rootPath(project)).hash; }
function commandsFor(project, supplied = {}, current = {}) {
  const configured = { ...(current.verification_commands || {}), ...(supplied.verification_commands || {}) };
  const pkg = readJson(project, 'package.json', {});
  const suggestions = Object.fromEntries(Object.keys(pkg.scripts || {}).filter(x => ['build', 'test', 'lint', 'typecheck', 'dev'].includes(x)).map(x => [x, ['npm', 'run', x]]));
  return { configured, suggestions };
}
function legacyState(project) {
  const raw = read(project, '.ai/current-state.md');
  if (!raw) return null;
  const text = utf8(raw); assertNoSecret(text);
  const value = heading => {
    const body = text.match(new RegExp(`(?:^|\\n)(?:#{1,4}\\s*)?${heading}:?\\s*\\r?\\n([\\s\\S]*?)(?=\\n\\s*\\n|\\n(?:#{1,4}\\s+|[A-Z][^\\n]+:)|$)`, 'i'))?.[1];
    return body?.trim().replace(/^[-*]\s*/, '') || null;
  };
  const goal = value('Current Goal'), phase = value('Current Phase'), next = value('Next Step');
  const unset = x => !x || /^(?:Not set|None|Await user task|INITIALIZED)$/i.test(x);
  return { path: '.ai/current-state.md', sha256: hash(raw), goal, phase, next_task: next,
    requires_mapping: !unset(goal) || !unset(phase) || (!goal && !phase && !text.includes('Status: INITIALIZED')) };
}
function stateReferenceHashes(project) {
  return fileHashes(project, ['.ai/current-state.md', '.ai/active-spec.md', '.ai/active-plan.md', '.ai/capability-lock.json']);
}
function commandRecord(project, name, descriptor) {
  if (!descriptor) return { name, status: 'NOT_CONFIGURED', required: true, evidence: [], reason: 'Configure an explicit argv command discovered from the project.' };
  if (descriptor.required === false) {
    if (!descriptor.reason || descriptor.reason.trim().length < 12) throw new Error(`N_A_REASON_REQUIRED: ${name}`);
    return { name, status: 'N/A', required: false, reason: descriptor.reason, evidence: [] };
  }
  if (typeof descriptor.command !== 'string' || !Array.isArray(descriptor.args) || descriptor.args.some(x => typeof x !== 'string') || descriptor.shell || descriptor.env) throw new Error('COMMAND_REQUIRES_ARGV: environment values and shell strings are not stored.');
  assertNoSecret(json(descriptor));
  if (descriptor.args.some(x => /(?:--?(?:password|secret|token|api-key)=)/i.test(x))) throw new Error('CREDENTIAL_ARGUMENT_FORBIDDEN');
  const before = performance.now(), at = stamp();
  const result = spawnSync(descriptor.command, descriptor.args, {
    cwd: project, encoding: 'utf8', timeout: Math.min(descriptor.timeout_ms || 120000, 300000),
    maxBuffer: 1024 * 1024, windowsHide: true, shell: false
  });
  // Never serialize command output: test logs may contain credentials. Keep a digest
  // and exit code; callers can capture a separately reviewed/redacted raw artifact.
  return { name, status: result.status === 0 && !result.error ? 'PASS' : 'FAIL', command: descriptor.command,
    args: descriptor.args, timestamp: at, exit_code: result.status, duration_ms: performance.now() - before,
    output_sha256: hash((result.stdout || '') + (result.stderr || '')), output_bytes: Buffer.byteLength((result.stdout || '') + (result.stderr || '')),
    failure_kind: result.error ? result.error.code || 'EXECUTION_ERROR' : null, evidence: [{ type: 'command', command: descriptor.command, args: descriptor.args, exit_code: result.status, timestamp: at, environment: 'local' }] };
}
function runVerification(project, commands, product) {
  const names = product ? ['build', 'test', 'critical_regression'] : Object.keys(commands);
  return Object.fromEntries(names.map(name => [name, commandRecord(project, name, commands[name])]));
}
function passed(records) { return Object.values(records).every(x => x.status === 'PASS' || (x.status === 'N/A' && x.required === false && x.reason)); }
function manifest(root) {
  const m = readJson(root, 'harness/manifest.yaml');
  if (!m || m.schema_version !== 3 || !m.harness?.version || !Array.isArray(m.required_runtime_files) || !Array.isArray(m.payload_files)) throw new Error('INVALID_SOURCE_MANIFEST');
  const v = version(read(root, 'HARNESS_VERSION')?.toString('utf8'));
  if (v !== version(m.harness.version)) throw new Error('SOURCE_VERSION_MISMATCH');
  const index = read(root, 'POLICY_INDEX.yaml')?.toString('utf8') || '';
  const im = index.match(/^harness_version:\s*["']?([\d.]+)/m);
  if (!im || version(im[1]) !== v || !/^policy_count:\s*26\s*$/m.test(index)) throw new Error('SOURCE_INDEX_MISMATCH');
  for (const rel of [...new Set([...m.required_runtime_files, ...m.payload_files])]) {
    if (!read(root, rel)) throw new Error(`MISSING_SOURCE_FILE: ${rel}`);
  }
  return m;
}
export function sourceIdentity(sourceRoot) {
  const root = rootPath(sourceRoot), m = manifest(root);
  const payload = [...new Set([...m.payload_files, 'harness/manifest.yaml'])].sort();
  const files = fileHashes(root, payload);
  return { version: version(m.harness.version), hash: hash(json(files)), files, manifest: m };
}
export function inspectProject(project, sourceRoot) {
  project = rootPath(project);
  const config = readJson(project, PROJECT_FILE, {});
  const state = readJson(project, STATE_FILE, null);
  const legacyBytes = read(project, '.ai/harness.yaml');
  const legacyText = legacyBytes ? utf8(legacyBytes) : null;
  if (legacyText) assertNoSecret(legacyText);
  const legacy = legacyBinding(legacyText);
  const versions = [config.harness?.version, legacy.version].filter(Boolean).map(version);
  if (new Set(versions).size > 1) throw new Error('LOCAL_VERSION_MISMATCH');
  const installed = versions[0] || null;
  const product = productGuard(project);
  const hasProduct = product.files.some(x => !/^(?:README|LICENSE|CHANGELOG|HARNESS_VERSION)(?:\.|$)/i.test(x[0]) && !x[0].startsWith('harness/'));
  const dirty = git(project, ['status', '--porcelain=v1', '--untracked-files=normal']);
  const target = sourceRoot ? sourceIdentity(sourceRoot) : null;
  const transition = readJson(project, TRANSITION, null);
  const pending = readJson(project, '.ai/harness-last-transaction.json', null);
  let pinnedStatus = 'UNKNOWN';
  if (config.harness?.root) {
    try { const pin = sourceIdentity(config.harness.root); pinnedStatus = pin.version === installed && pin.hash === config.harness.source_hash ? 'PASS' : 'FAIL'; }
    catch { pinnedStatus = 'FAIL'; }
  }
  const currentPhase = state?.current_phase || (hasProduct && dirty ? 'UNKNOWN' : '00_INTAKE');
  const development = state?.development_state || (hasProduct && dirty ? 'IN_PROGRESS' : hasProduct ? 'STABLE' : 'NOT_STARTED');
  return { project, has_product: hasProduct, installed_version: installed, target_version: target?.version,
    project_mode: state?.project_mode || (hasProduct ? 'MAINTENANCE' : 'GREENFIELD'), development_state: development,
    current_phase: currentPhase, operation_in_progress: state?.operation_in_progress || null,
    production: state?.production || false, beginner_mode: state?.beginner_mode ?? config.beginner_mode ?? true,
    known_failures: state?.known_failures || [], config, state, legacy, legacy_text: legacyText, pinned_source_status: pinnedStatus,
    product_hash: product.hash, product_files: product.files,
    git: { commit: git(project, ['rev-parse', 'HEAD']), branch: git(project, ['rev-parse', '--abbrev-ref', 'HEAD']), changed_files: dirty?.split('\n').filter(Boolean) || [] },
    transition_in_progress: pending?.status === 'APPLYING' || transition?.status === 'FROZEN_FOR_MIGRATION',
    harness_status: pending?.status === 'APPLYING' ? 'HARNESS_MIGRATION_IN_PROGRESS' : pinnedStatus === 'FAIL' ? 'HARNESS_REPAIR_REQUIRED' : !installed ? 'HARNESS_NOT_INSTALLED' : target && installed !== target.version ? 'HARNESS_VERSION_MISMATCH' : 'HARNESS_CURRENT' };
}
export function diagnoseProject(project) {
  project = rootPath(project);
  const config = readJson(project, PROJECT_FILE, {});
  const cmds = commandsFor(project, {}, config);
  const detected = ['Git', 'Runtime', 'Package Manager', 'Required CLI', 'Environment Variables', 'Repository Access', 'Build Command', 'Test Command', 'Lint Command', 'Type Check Command', 'Dev Server Command', 'Production Build Command', 'Deployment Target', 'Database', 'Migration Tool', 'Browser Test Capability'];
  const result = Object.fromEntries(detected.map(x => [x, { status: 'UNKNOWN', evidence: [] }]));
  result.Git = { status: spawnSync('git', ['--version'], { windowsHide: true }).status === 0 ? 'PASS' : 'NOT_CONFIGURED', evidence: ['git --version'] };
  result.Runtime = { status: Number(process.versions.node.split('.')[0]) >= 22 ? 'PASS' : 'FAIL', evidence: [`Node ${process.versions.node}`] };
  for (const [label, key] of [['Build Command', 'build'], ['Test Command', 'test'], ['Lint Command', 'lint'], ['Type Check Command', 'typecheck'], ['Dev Server Command', 'dev']]) {
    result[label] = { status: cmds.configured[key] ? 'CONFIGURED_NOT_RUN' : cmds.suggestions[key] ? 'DISCOVERED_NOT_RUN' : 'NOT_CONFIGURED', evidence: [] };
  }
  result['Environment Variables'] = { status: 'NAMES_ONLY', evidence: config.required_environment_variables || [], missing_names: (config.required_environment_variables || []).filter(x => !process.env[x]) };
  result['Repository Access'] = { status: git(project, ['rev-parse', '--is-inside-work-tree']) ? 'LOCAL_GIT_ACCESS' : 'UNKNOWN', evidence: ['remote access not tested'] };
  result['Package Manager'] = { status: fs.existsSync(safePath(project, 'package.json')) ? 'DISCOVERED_NOT_RUN' : 'NOT_CONFIGURED', evidence: [] };
  result['Deployment Target'] = { status: config.deployment_target ? 'CONFIGURED_NOT_VERIFIED' : 'UNKNOWN', evidence: [] };
  result.Database = { status: config.database ? 'CONFIGURED_NOT_VERIFIED' : 'UNKNOWN', evidence: [] };
  result['Migration Tool'] = { status: config.migration_tool ? 'CONFIGURED_NOT_VERIFIED' : 'NOT_CONFIGURED', evidence: [] };
  result['Browser Test Capability'] = { status: config.verification_commands?.e2e ? 'CONFIGURED_NOT_RUN' : 'NOT_CONFIGURED', evidence: [] };
  return { timestamp: stamp(), checks: result, suggested_commands: cmds.suggestions, recommendation: 'Resolve missing required tools and configure project verification argv before migration. UI work requires actual browser evidence; metadata alone is not PASS.' };
}
export function planProject({ project, sourceRoot, request = 'AI Harness v6.0으로 업데이트해줘.', config: supplied = {} }) {
  project = rootPath(project); sourceRoot = rootPath(sourceRoot);
  if (project === sourceRoot) throw new Error('SOURCE_IS_NOT_CONSUMER_PROJECT');
  const identity = sourceIdentity(sourceRoot);
  const detected = inspectProject(project, sourceRoot);
  const hadCanonicalState = Boolean(detected.state);
  if (supplied.state) {
    if (detected.state) {
      for (const [key, value] of Object.entries(supplied.state)) {
        if (Object.hasOwn(detected.state, key) && json(detected.state[key]) !== json(value)) throw new Error('STATE_OVERRIDE_CONFLICT: observed state cannot be downgraded by a migration plan.');
      }
    }
    detected.state = { ...(detected.state || {}), ...supplied.state };
    for (const key of ['development_state', 'project_mode', 'current_phase', 'operation_in_progress', 'production', 'beginner_mode']) if (key in supplied.state) detected[key] = supplied.state[key];
  }
  const route = routeTask(request, detected, { target_version: identity.version });
  const files = managedFiles(project);
  const before = fileHashes(project, files);
  const conflicts = [];
  const legacyProgress = !hadCanonicalState ? legacyState(project) : null;
  if (legacyProgress?.requires_mapping) {
    if (!supplied.state?.goal || !supplied.state?.current_phase || !supplied.state?.next_task || !supplied.state?.acceptance_criteria?.length) conflicts.push({ file: '.ai/current-state.md', kind: 'LEGACY_STATE_REQUIRES_MAPPING', reason: 'Map the existing goal/phase/criteria/decisions/next task into canonical state; completed work must not be reset.' });
    else if ((legacyProgress.goal && supplied.state.goal !== legacyProgress.goal) || (legacyProgress.phase && supplied.state.current_phase !== legacyProgress.phase) || (legacyProgress.next_task && supplied.state.next_task !== legacyProgress.next_task)) conflicts.push({ file: '.ai/current-state.md', kind: 'STATE_PRESERVATION_CONFLICT', reason: 'Mapped canonical state differs from the recorded legacy current work.' });
  }
  const base = detected.config.harness?.managed || {};
  for (const rel of files) {
    const bytes = read(project, rel);
    if (bytes) assertNoSecret(utf8(bytes));
    if (['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(rel)) {
      const existing = bytes ? block(utf8(bytes)) : null;
      const blockBase = detected.config.harness?.managed_blocks?.[rel];
      if (blockBase && existing && hash(existing.text) !== blockBase) conflicts.push({ file: rel, kind: 'CONFLICT', reason: 'Local managed rule differs from old upstream base.' });
      if (!blockBase && existing && !knownLegacy(sourceRoot, existing.text, 'block', detected.legacy.root)) conflicts.push({ file: rel, kind: 'CONFLICT', reason: 'Legacy/custom managed rules differ from the known upstream template; preserve and reconcile before activation.' });
    } else if (base[rel] && before[rel] !== base[rel] && ![PROJECT_FILE, STATE_FILE].includes(rel)) {
      conflicts.push({ file: rel, kind: 'CONFLICT', reason: 'Local customization differs from installed upstream baseline.' });
    } else if (!base[rel] && rel === '.ai/HARNESS.md' && bytes && !knownLegacy(sourceRoot, utf8(bytes), 'bridge', detected.legacy.root)) {
      conflicts.push({ file: rel, kind: 'CONFLICT', reason: 'Unknown project bridge is preserved until reconciled.' });
    }
  }
  if (detected.installed_version && !identity.manifest.compatibility.supported_from.some(x => x === detected.installed_version || x === detected.installed_version.split('.')[0] + '.x')) conflicts.push({ file: PROJECT_FILE, kind: 'CONFLICT', reason: 'Unsupported migration source.' });
  const state = detected.state || {
    goal: request, current_phase: detected.current_phase, completed_phases: [], acceptance_criteria: ['Install the Harness safely and start a guided goal interview.'], decisions: [],
    known_risks: [], known_failures: [], next_task: 'Run project initialization goal interview.',
    development_state: detected.development_state, project_mode: detected.project_mode, beginner_mode: detected.beginner_mode, phases: {}
  };
  if (detected.development_state === 'IN_PROGRESS' && (!state.goal || state.current_phase === 'UNKNOWN' || !state.next_task || !Array.isArray(state.acceptance_criteria) || !state.acceptance_criteria.length)) conflicts.push({ file: STATE_FILE, kind: 'MISSING_STATE', reason: 'Record current goal, phase, acceptance criteria and next task before checkpointing active work.' });
  const commands = commandsFor(project, supplied, detected.config);
  for (const [name, descriptor] of Object.entries(commands.configured)) validateCommand(descriptor, name);
  if (detected.has_product) for (const name of ['build', 'test', 'critical_regression']) if (!commands.configured[name]) conflicts.push({ file: PROJECT_FILE, kind: 'MISSING_VERIFICATION', reason: `Configure ${name} argv or a justified nonapplicable declaration.` });
  if (detected.transition_in_progress) conflicts.push({ file: TRANSITION, kind: 'INTERRUPTED_TRANSITION', reason: 'Recover or roll back the existing transaction before planning another.' });
  const status = route.timing === 'DEFERRED' ? 'DEFERRED' : conflicts.length ? 'BLOCKED' : 'READY';
  const custom = ['.agents/skills', '.claude/skills', '.ai/decisions', '.ai/current-state.md', '.ai/active-plan.md', '.ai/active-spec.md'].map(rel => ({ file: rel, disposition: 'LOCAL', action: 'PRESERVE' }));
  const plan = { kind: 'harness-project-migration-plan', schema_version: 3, created_at: stamp(), id: crypto.randomUUID(),
    project, source_root: sourceRoot, source_version: identity.version, source_hash: identity.hash, source_files: identity.files,
    status, request, route, from_version: detected.installed_version, to_version: identity.version, project_mode: detected.project_mode,
    before_hashes: before, state_reference_hashes: stateReferenceHashes(project), product_hash: detected.product_hash, git: detected.git, state,
    current_config: detected.config, legacy_binding: detected.legacy_text || null,
    verification_commands: commands.configured, diagnosis: diagnoseProject(project), conflicts, customizations: custom,
    actions: files.map(file => ({ file, action: before[file] ? 'MERGE' : 'ADD', current_role: before[file] ? 'Existing project binding/instruction' : 'Absent', v6_role: 'Pinned v6 lifecycle/update routing', risk: 'R2', dependencies: ['validated source', 'safe checkpoint'], verification: 'hash preservation + source validation + project regression' })),
    acceptance_criteria: ['Preserve product bytes, project rules, goal, current phase, completed phases and user decisions.', 'Validate source; run configured baseline and regression; audit and resume with evidence.', 'Provide exact harness-only rollback without discarding later edits.'],
    stop_conditions: ['conflict', 'unsafe active operation', 'source/plan drift', 'failed baseline/regression', 'incomplete preservation', 'missing checkpoint'],
    snapshot_root: supplied.snapshot_root || path.join(process.env.LOCALAPPDATA || os.homedir(), 'AI-Harness-Releases') };
  assertNoSecret(json(plan));
  return plan;
}
function acquireLock(project, recovery = false) {
  const rel = '.ai/harness-update.lock', p = safePath(project, rel);
  fs.mkdirSync(path.dirname(p), { recursive: true });
  if (fs.existsSync(p) && recovery) {
    const previous = readJson(project, rel);
    let alive = true;
    try { process.kill(previous.pid, 0); } catch (e) { if (e.code === 'ESRCH') alive = false; }
    if (alive) throw new Error('MIGRATION_LOCKED');
    fs.unlinkSync(p);
  }
  let fd;
  try { fd = fs.openSync(p, 'wx'); } catch { throw new Error('MIGRATION_LOCKED'); }
  fs.writeFileSync(fd, json({ pid: process.pid, at: stamp() }));
  return () => { fs.closeSync(fd); if (fs.existsSync(p)) fs.unlinkSync(p); };
}
function snapshotSource(plan) {
  const parent = path.resolve(plan.snapshot_root);
  let ancestor = path.parse(parent).root;
  for (const part of path.relative(ancestor, parent).split(path.sep)) {
    ancestor = path.join(ancestor, part);
    if (fs.existsSync(ancestor) && fs.lstatSync(ancestor).isSymbolicLink()) throw new Error('SNAPSHOT_SYMLINK_BOUNDARY');
  }
  fs.mkdirSync(parent, { recursive: true });
  if (fs.lstatSync(parent).isSymbolicLink()) throw new Error('SNAPSHOT_SYMLINK_BOUNDARY');
  const directory = path.join(parent, `${plan.to_version}-${plan.source_hash.slice(0, 16)}`);
  if (!fs.existsSync(directory)) {
    const staging = fs.mkdtempSync(path.join(parent, '.stage-'));
    for (const rel of Object.keys(plan.source_files)) {
      const bytes = read(plan.source_root, rel);
      if (hash(bytes) !== plan.source_files[rel]) throw new Error('SOURCE_DRIFT');
      assertNoSecret(bytes.toString('utf8'));
      writeAtomic(staging, rel, bytes);
    }
    try { fs.renameSync(staging, directory); }
    catch (e) { if (!fs.existsSync(directory)) throw e; }
  }
  if (fs.lstatSync(directory).isSymbolicLink()) throw new Error('SNAPSHOT_SYMLINK_BOUNDARY');
  const identity = sourceIdentity(directory);
  if (identity.hash !== plan.source_hash) throw new Error('IMMUTABLE_SNAPSHOT_DRIFT');
  return directory;
}
function gate(goal, evidence) { return { status: 'PASS', goal, acceptance_criteria: [goal], verification_method: 'Recorded deterministic runtime verification', evidence }; }
function resumeGates(journal) {
  const reference = `.ai/harness-transactions/${journal.id}.json`;
  return { harness_validation: gate('Pinned source validated', [reference + '#source_evidence']),
    transition_audit: gate('Preserved state and project rules', [reference + '#audit']),
    build_baseline: journal.baseline.build || { status: 'N/A', required: false, reason: 'Empty project has no product build yet.' },
    test_baseline: journal.baseline.test || { status: 'N/A', required: false, reason: 'Empty project has no product test suite yet.' },
    critical_regression: journal.after.critical_regression || gate('Empty project product-byte inventory remains unchanged', [reference + '#product_hash']),
    benchmark: gate('Transaction metrics recorded', [reference + '#metrics']) };
}
function recordWrite(project, journalRel, journal, rel, bytes) {
  journal.hash_history ||= {};
  const history = journal.hash_history[rel] ||= [];
  for (const known of [journal.before_hashes[rel], journal.after_hashes[rel], hash(bytes)]) {
    if (known !== undefined && !history.includes(known)) history.push(known);
  }
  journal.after_hashes[rel] = hash(bytes);
  writeAtomic(project, journalRel, json(journal));
  writeAtomic(project, rel, bytes);
}
export function applyPlan(plan) {
  if (typeof plan === 'string') plan = JSON.parse(fs.readFileSync(plan, 'utf8').replace(/^\uFEFF/, ''));
  if (plan.kind !== 'harness-project-migration-plan' || plan.schema_version !== 3 || plan.status !== 'READY') throw new Error('PLAN_NOT_READY');
  const project = rootPath(plan.project), source = rootPath(plan.source_root);
  // Recompute semantics, paths and conflicts from inputs. A hand-edited plan cannot
  // silently downgrade a conflict, change the source, or bypass unsafe timing.
  const fresh = planProject({ project, sourceRoot: source, request: plan.request, config: { verification_commands: plan.verification_commands, state: plan.state, snapshot_root: plan.snapshot_root } });
  if (fresh.status !== 'READY' || json(fresh.before_hashes) !== json(plan.before_hashes) || json(fresh.state_reference_hashes) !== json(plan.state_reference_hashes) || fresh.source_hash !== plan.source_hash || fresh.product_hash !== plan.product_hash) throw new Error('PLAN_DRIFT_OR_CONFLICT');
  for (const key of ['to_version', 'from_version', 'source_version', 'project_mode', 'legacy_binding', 'current_config', 'route', 'source_files', 'actions']) {
    if (json(fresh[key]) !== json(plan[key])) throw new Error('PLAN_SEMANTIC_DRIFT: validated version, local contract and operation semantics must match the reviewed plan.');
  }
  if (fresh.git.commit !== plan.git.commit || fresh.git.branch !== plan.git.branch) throw new Error('PLAN_SEMANTIC_DRIFT: project branch or baseline commit changed.');
  if (!/^[a-f0-9-]{36}$/.test(plan.id)) throw new Error('INVALID_PLAN_ID');
  assertNoSecret(json(plan));
  const reviewedId = plan.id;
  plan = { ...fresh, id: reviewedId };
  if (fs.existsSync(safePath(project, `.ai/harness-transactions/${plan.id}.json`))) throw new Error('JOURNAL_ALREADY_EXISTS: never overwrite previous transition evidence.');
  const release = acquireLock(project), at = performance.now();
  let journal;
  const journalRel = `.ai/harness-transactions/${plan.id}.json`;
  try {
    const snapshot = snapshotSource(plan);
    const files = Object.keys(fresh.before_hashes);
    const backups = Object.fromEntries(files.map(rel => { const bytes = read(project, rel); return [rel, bytes ? bytes.toString('base64') : null]; }));
    const baseline = runVerification(project, plan.verification_commands, fresh.route.intent === 'EXISTING_PROJECT_ADOPTION' || inspectProject(project).has_product);
    if (!passed(baseline)) throw new Error('BASELINE_FAILED_OR_UNKNOWN');
    if (productGuard(project).hash !== plan.product_hash || json(fileHashes(project, files)) !== json(plan.before_hashes) || json(stateReferenceHashes(project)) !== json(plan.state_reference_hashes)) throw new Error('BASELINE_CHANGED_PROJECT');
    journal = { kind: 'harness-project-transaction', schema_version: 3, id: plan.id, project, status: 'APPLYING', timestamp: stamp(),
      before_hashes: plan.before_hashes, after_hashes: {}, backups, baseline, after: {}, verification_commands: plan.verification_commands, source_evidence: { timestamp: stamp(), source_hash: plan.source_hash, version: plan.to_version, environment: 'local' },
      product_hash: plan.product_hash, checkpoint: { git: plan.git, state: plan.state, before_hashes: plan.before_hashes, recoverable: true, product_recovery: 'Product bytes are never modified by this transaction; uncommitted files remain in place.' } };
    writeAtomic(project, journalRel, json(journal));
    writeAtomic(project, '.ai/harness-last-transaction.json', json({ id: plan.id, path: journalRel, status: 'APPLYING' }));
    const state = structuredClone(fresh.state);
    const preserved = { current_goal: state.goal, current_phase: state.current_phase, next_task: state.next_task,
      completed_phases: state.completed_phases || [], acceptance_criteria: state.acceptance_criteria || [], decisions: state.decisions || [],
      project_mode: state.project_mode || plan.project_mode, beginner_mode: state.beginner_mode ?? fresh.route.beginner_mode, known_risks: state.known_risks || [], known_failures: state.known_failures || [] };
    const transition = { from_version: plan.from_version || 'NOT_INSTALLED', to_version: plan.to_version, project_mode: preserved.project_mode,
      development_state: 'FROZEN_FOR_MIGRATION', checkpoint: { journal: journalRel, rollback_point: journalRel, branch: plan.git.branch || 'NO_GIT_REPOSITORY', commit: plan.git.commit || 'FILESYSTEM_SNAPSHOT', before_hashes: plan.before_hashes, test_baseline: baseline,
        goal: preserved.current_goal, phase: preserved.current_phase, acceptance_criteria: preserved.acceptance_criteria, next_task: preserved.next_task,
        decisions: preserved.decisions, changed_files: plan.git.changed_files, git_status: plan.git.changed_files.length ? 'DIRTY_PRESERVED' : 'CLEAN_OR_NO_GIT',
        completed_work: preserved.completed_phases, unfinished_work: [preserved.next_task], test_results: baseline, known_failures: preserved.known_failures,
        migration_state: state.migration_state || 'NO_ACTIVE_MIGRATION_DETECTED', environment_changes: state.environment_changes || [] },
      current_phase: preserved.current_phase, completed_phases: preserved.completed_phases, current_work: { goal: preserved.current_goal, next_task: preserved.next_task, acceptance_criteria: preserved.acceptance_criteria },
      current_goal: preserved.current_goal, acceptance_criteria: preserved.acceptance_criteria, decisions: preserved.decisions,
      carry_forward: preserved, new_required_gates: ['independent-review', 'regression-baseline', 'security-review-if-applicable', 'rollback-check', 'production-verification-before-product-release'],
      deferred_rules: ['historical-code-refactor', 'completed-phase-reexecution'], conflicts: [], resume_from: { phase: preserved.current_phase, goal: preserved.current_goal, next_task: preserved.next_task },
      status: 'FROZEN_FOR_MIGRATION', rule_application: 'Future phases use v6; current phase evidence is carried forward; missing critical release gates are backfilled before release.' };
    recordWrite(project, journalRel, journal, TRANSITION, json(transition));
    const normalizedRoot = snapshot.replaceAll('\\', '/');
    const newBlock = `${START}\n## AI Harness v6\nPinned version: ${plan.to_version}. Read .ai/HARNESS.md before substantive work.\nFor install/update/migration intent, run the pinned scripts/harness-v6.mjs route and plan, then follow harness/update/UPDATE_PROTOCOL.md. Never overwrite custom rules or switch major rules inside active work without checkpoint/freeze.\nRequire acceptance, evidence, independent review and production verification when deploying. BEGINNER_MODE defaults ON. JIT only the current phase/task policies.\n${END}`;
    const outputs = {};
    for (const rel of files.filter(x => ['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(x))) outputs[rel] = replaceBlock(read(project, rel)?.toString('utf8') || '', newBlock);
    outputs['.ai/HARNESS.md'] = `# AI Harness Project Bridge\n\nPinned HARNESS_ROOT: ${normalizedRoot}\nHARNESS_VERSION: ${plan.to_version}\n\nCheck .ai/harness-project.json and .ai/harness-state.json first. Compare the pinned HARNESS_VERSION, harness/manifest.yaml and POLICY_INDEX.yaml; mismatch routes to harness/update/VERSION_DETECTION.md and blocks ordinary task execution until reconciled.\nRead ${normalizedRoot}/CORE.md, ROUTER.md and POLICY_INDEX.yaml, then JIT relevant runtime/update/Skill documents.\nA one-line Harness update request routes through ${normalizedRoot}/scripts/harness-v6.mjs, harness/runtime/harness-update-router.md and harness/update/UPDATE_PROTOCOL.md. Discover and validate a GitHub source candidate; never silently change the pinned root.\nKeep goals, phase, decisions, local rules, commands and beginner preference. Failed gates block progress; verification evidence is mandatory. No product code refactor during Harness migration.\n`;
    const binding = { schema_version: '3', harness: { ...(legacyBinding(plan.legacy_binding) || {}), version: plan.to_version, initialized_with: plan.from_version || plan.to_version, root: normalizedRoot, core: 'CORE.md', router: 'ROUTER.md', policy_index: 'POLICY_INDEX.yaml', policy_count: 26 }, runtime: { preload_all_policies: false, use_jit_policy_loading: true, use_jit_skill_loading: true, policy_load_trace: 'record_only' } };
    // Legacy custom YAML is preserved verbatim as a reference and in rollback backups.
    if (plan.legacy_binding) {
      const previousBinding = plan.legacy_binding.trim().startsWith('{') ? JSON.parse(plan.legacy_binding) : {};
      binding.legacy_customization_reference = previousBinding.legacy_customization_reference || plan.legacy_binding;
    }
    outputs['.ai/harness.yaml'] = json(binding);
    state.development_state = 'FROZEN_FOR_MIGRATION'; state.beginner_mode = preserved.beginner_mode; state.project_mode = preserved.project_mode;
    outputs[STATE_FILE] = json(state);
    const config = { ...fresh.current_config, schema_version: 3, beginner_mode: preserved.beginner_mode, verification_commands: plan.verification_commands,
      legacy_local_contract: fresh.current_config.legacy_local_contract || (plan.legacy_binding ? { status: 'ACTIVE_LOCAL_CONSTRAINTS', original: binding.legacy_customization_reference, precedence: 'Preserve user local constraints and resolve material conflicts before new upstream behavior.' } : null),
      harness: { ...(fresh.current_config.harness || {}), version: plan.to_version, root: normalizedRoot, source_hash: plan.source_hash,
        managed: Object.fromEntries(Object.entries(outputs).filter(([rel]) => !['AGENTS.md', 'CLAUDE.md', 'GEMINI.md', STATE_FILE].includes(rel)).map(([rel, text]) => [rel, hash(text)])),
        managed_blocks: Object.fromEntries(files.filter(x => ['AGENTS.md', 'CLAUDE.md', 'GEMINI.md'].includes(x)).map(rel => [rel, hash(newBlock)])) } };
    outputs[PROJECT_FILE] = json(config);
    for (const [rel, text] of Object.entries(outputs)) { assertNoSecret(text); recordWrite(project, journalRel, journal, rel, text); }
    journal.after = runVerification(project, plan.verification_commands, inspectProject(project).has_product);
    if (!passed(journal.after)) throw new Error('REGRESSION_FAILED_OR_UNKNOWN');
    if (productGuard(project).hash !== plan.product_hash) throw new Error('PRODUCT_DRIFT_DURING_MIGRATION');
    journal.audit = { status: 'PASS', timestamp: stamp(), carry_forward: preserved, conflicts: [], product_bytes_unchanged: true, critical_backfill: transition.new_required_gates, deferred: transition.deferred_rules };
    journal.metrics = { measurement_scope: 'actual harness project transaction; no model invocation', wall_time_ms: performance.now() - at, tool_calls: Object.values(journal.baseline).filter(x => x.status !== 'N/A').length + Object.values(journal.after).filter(x => x.status !== 'N/A').length,
      retry: 0, human_intervention: 0, files_changed: Object.keys(outputs).length, regression: 0, migration_success: true, resume_success: true,
      model_tokens: null, token_measurement_reason: 'No model provider usage is available for this deterministic transaction.' };
    const resumed = validateResume(transition, resumeGates(journal));
    state.development_state = 'RESUMING';
    state.last_migration = { version: plan.to_version, journal: journalRel, timestamp: stamp(), resume: resumed };
    outputs[STATE_FILE] = json(state); recordWrite(project, journalRel, journal, STATE_FILE, outputs[STATE_FILE]);
    transition.development_state = 'RESUMING'; transition.status = 'VERIFIED'; transition.audit = journal.audit; transition.verification = resumeGates(journal); transition.benchmark = journal.metrics;
    recordWrite(project, journalRel, journal, TRANSITION, json(transition));
    journal.status = 'VERIFIED'; journal.completed_at = stamp();
    writeAtomic(project, journalRel, json(journal));
    writeAtomic(project, '.ai/harness-last-transaction.json', json({ id: plan.id, path: journalRel, status: 'VERIFIED' }));
    return { status: 'PASS', project, harness_version: plan.to_version, harness_root: normalizedRoot, transition, evidence: journalRel, benchmark: journal.metrics, next_action: state.next_task };
  } catch (error) {
    if (journal) {
      try { restoreJournal(project, journal); journal.status = 'ROLLED_BACK'; }
      catch { journal.status = 'ROLLBACK_BLOCKED'; }
      journal.failure = error.message; writeAtomic(project, journalRel, json(journal));
      writeAtomic(project, '.ai/harness-last-transaction.json', json({ id: plan.id, path: journalRel, status: journal.status }));
      // Restored transition bytes stay exact. Failure evidence belongs in the journal.
    }
    throw error;
  } finally { release(); }
}
function restoreJournal(project, journal) {
  if (journal.kind !== 'harness-project-transaction' || journal.schema_version !== 3 || journal.project !== project) throw new Error('INVALID_ROLLBACK_JOURNAL');
  const allowed = new Set([...MANAGED, 'CLAUDE.md', 'GEMINI.md']);
  for (const [rel, backup] of Object.entries(journal.backups)) {
    if (!allowed.has(rel)) throw new Error('INVALID_ROLLBACK_TARGET');
    const expected = journal.before_hashes[rel];
    if ((backup === null ? null : hash(Buffer.from(backup, 'base64'))) !== expected) throw new Error('CORRUPT_CHECKPOINT');
    const current = read(project, rel); const currentHash = current ? hash(current) : null;
    if (currentHash !== expected && currentHash !== journal.after_hashes[rel] && !(journal.hash_history?.[rel] || []).includes(currentHash)) throw new Error('ROLLBACK_DRIFT: later edits require reconciliation.');
  }
  for (const [rel, backup] of Object.entries(journal.backups).reverse()) {
    if (backup === null) { const p = safePath(project, rel); if (fs.existsSync(p)) fs.unlinkSync(p); }
    else writeAtomic(project, rel, Buffer.from(backup, 'base64'));
  }
  if (json(fileHashes(project, Object.keys(journal.before_hashes))) !== json(journal.before_hashes)) throw new Error('ROLLBACK_VERIFICATION_FAILED');
}
export function rollbackProject(project) {
  project = rootPath(project);
  const release = acquireLock(project, true);
  try {
    const pointer = readJson(project, '.ai/harness-last-transaction.json');
    if (!pointer || pointer.path !== `.ai/harness-transactions/${pointer.id}.json`) throw new Error('NO_VALID_ROLLBACK_POINT');
    const journal = readJson(project, pointer.path);
    restoreJournal(project, journal);
    journal.rollback_verification = runVerification(project, journal.verification_commands || {}, inspectProject(project).has_product);
    journal.status = passed(journal.rollback_verification) ? 'ROLLED_BACK' : 'ROLLBACK_VERIFICATION_FAILED';
    writeAtomic(project, pointer.path, json(journal));
    writeAtomic(project, '.ai/harness-last-transaction.json', json({ ...pointer, status: journal.status }));
    // Keep the original transition manifest restored byte-for-byte.
    return { status: journal.status, evidence: pointer.path, verification: journal.rollback_verification, product_preserved: productGuard(project).hash === journal.product_hash };
  } finally { release(); }
}
export function verifyProject(project) {
  project = rootPath(project);
  const detected = inspectProject(project);
  const config = detected.config;
  if (!config.harness?.root) throw new Error('HARNESS_NOT_INSTALLED');
  const identity = sourceIdentity(config.harness.root);
  const mismatches = [];
  if (identity.version !== detected.installed_version || identity.hash !== config.harness.source_hash) mismatches.push('PINNED_SOURCE_DRIFT');
  for (const [rel, expected] of Object.entries(config.harness.managed || {})) if (fileHashes(project, [rel])[rel] !== expected) mismatches.push(rel);
  for (const [rel, expected] of Object.entries(config.harness.managed_blocks || {})) {
    const b = read(project, rel); if (!b || hash(block(b.toString('utf8'))?.text || '') !== expected) mismatches.push(rel);
  }
  const transition = readJson(project, TRANSITION, {});
  if (transition.status !== 'VERIFIED') mismatches.push('TRANSITION_NOT_VERIFIED');
  const records = runVerification(project, config.verification_commands || {}, detected.has_product);
  return { status: !mismatches.length && passed(records) ? 'PASS' : 'FAIL', mismatches, verification: records, timestamp: stamp(), source_hash: identity.hash };
}
