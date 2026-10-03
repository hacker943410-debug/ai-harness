#!/usr/bin/env node
/** Self-contained v6 entry point; machine installers continue to use PowerShell. */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { inspectProject, planProject, applyPlan, rollbackProject, verifyProject, diagnoseProject, safePath, sourceIdentity, assertNoSecret, projectFingerprint } from './harness-project.mjs';
import { routeTask, transitionPhase, PHASES } from './harness-engine.mjs';

const source = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const [command, ...argv] = process.argv.slice(2);
const options = {};
for (let i = 0; i < argv.length; i++) {
  if (!argv[i].startsWith('--') || !argv[i + 1] || argv[i + 1].startsWith('--')) throw new Error('Options require explicit --name value pairs.');
  options[argv[i].slice(2)] = argv[++i];
}
const readJson = file => JSON.parse(fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
const output = value => process.stdout.write(JSON.stringify(value, null, 2) + '\n');
const write = (file, value) => { fs.mkdirSync(path.dirname(path.resolve(file)), { recursive: true }); fs.writeFileSync(file, JSON.stringify(value, null, 2) + '\n'); };
try {
  let result;
  const project = options.project ? path.resolve(options.project) : process.cwd();
  const request = options.request || 'AI Harness v6.0으로 업데이트해줘.';
  switch (command) {
    case 'inspect': result = inspectProject(project, options.source || source); break;
    case 'route': {
      const detected = inspectProject(project, options.source || source);
      if (detected.pinned_source_status === 'FAIL') throw new Error('PINNED_SOURCE_DRIFT: repair the pinned runtime before ordinary work.');
      result = routeTask(request, detected); break;
    }
    case 'diagnose': result = diagnoseProject(project); break;
    case 'plan': {
      result = planProject({ project, sourceRoot: options.source || source, request, config: options.config ? readJson(options.config) : {} });
      if (options.out) {
        const outPath = path.resolve(options.out);
        const rel = path.relative(project, outPath).replaceAll('\\', '/');
        if (!rel.startsWith('../')) {
          safePath(project, rel);
          if (!rel.startsWith('.ai/')) throw new Error('PLAN_OUTPUT_MUST_NOT_OVERWRITE_PRODUCT: use .ai/ or an external artifact directory.');
        }
        if (fs.existsSync(outPath)) throw new Error('PLAN_OUTPUT_EXISTS: preserve the existing plan or select another path.');
        write(outPath, result);
      }
      break;
    }
    case 'apply': if (!options.plan) throw new Error('--plan required'); result = applyPlan(readJson(options.plan)); break;
    case 'rollback': result = rollbackProject(project); break;
    case 'verify': result = verifyProject(project); break;
    case 'phase': {
      if (!options.phase || !options.contract) throw new Error('--phase and --contract required');
      const statePath = safePath(fs.realpathSync(project), '.ai/harness-state.json');
      const old = readJson(statePath);
      if (old.development_state === 'FROZEN_FOR_MIGRATION') throw new Error('FEATURE_CHANGE_FROZEN');
      const binding = inspectProject(project, options.source || source);
      if (binding.harness_status !== 'HARNESS_CURRENT') throw new Error('HARNESS_VERSION_MISMATCH');
      const pin = sourceIdentity(binding.config.harness.root);
      if (pin.hash !== binding.config.harness.source_hash || pin.version !== binding.installed_version) throw new Error('PINNED_SOURCE_DRIFT');
      const contract = readJson(options.contract);
      const fingerprint = projectFingerprint(project);
      const normalizeEvidence = (gate, recorded = false) => {
        if (gate.status === 'N/A') return gate;
        const entries = Array.isArray(gate.evidence) ? gate.evidence : [gate.evidence].filter(Boolean);
        const records = entries.map(record => {
          const ref = typeof record === 'string' ? record : record?.ref || record?.path || record?.artifact;
          if (!ref || /^(?:https?:\/\/)/.test(ref)) throw new Error('LOCAL_EVIDENCE_ARTIFACT_REQUIRED');
          const evidencePath = safePath(fs.realpathSync(project), ref.split('#')[0]);
          if (!fs.existsSync(evidencePath) || !fs.statSync(evidencePath).isFile()) throw new Error('EVIDENCE_ARTIFACT_MISSING');
          const digest = crypto.createHash('sha256').update(fs.readFileSync(evidencePath)).digest('hex');
          if (recorded && (!record.sha256 || record.sha256 !== digest)) throw new Error('EVIDENCE_ARTIFACT_DRIFT: reverify or backfill the affected gate.');
          if (typeof record === 'object' && record.sha256 && digest !== record.sha256) throw new Error('EVIDENCE_ARTIFACT_DRIFT');
          return { ...(typeof record === 'object' ? record : {}), ref, sha256: digest, recorded_at: typeof record === 'object' && record.recorded_at || new Date().toISOString() };
        });
        return { ...gate, evidence: records };
      };
      const requestedIndex = PHASES.indexOf(options.phase);
      const recordedGates = { ...old.phases };
      for (const [key, id] of Object.entries({ acceptance: '04_ACCEPTANCE', verification: '09_AUTOMATED_VERIFICATION', review: '10_INDEPENDENT_REVIEW', release: '11_RELEASE_VERIFICATION', deployment: '12_DEPLOY' })) {
        if (old[key] && !recordedGates[id]) recordedGates[id] = old[key];
      }
      for (const [id, previous] of Object.entries(recordedGates)) {
        if (PHASES.indexOf(id) >= requestedIndex || !['PASS', 'DEPLOYED', 'VERIFIED_PRODUCTION', 'N/A'].includes(previous.status)) continue;
        normalizeEvidence(previous, true);
        if (PHASES.indexOf(id) >= 9 && previous.subject_fingerprint !== fingerprint) throw new Error('VERIFICATION_SUBJECT_DRIFT: changed product requires verification again.');
      }
      result = transitionPhase(old, options.phase, normalizeEvidence(contract));
      result.phases[options.phase].subject_fingerprint = fingerprint;
      for (const id of Object.keys(result.phases)) if (PHASES.indexOf(id) > requestedIndex) result.phases[id] = { ...result.phases[id], status: 'NOT_STARTED', invalidated_by: options.phase };
      if (projectFingerprint(project) !== fingerprint) throw new Error('VERIFICATION_SUBJECT_DRIFT');
      assertNoSecret(JSON.stringify(result));
      write(statePath, result);
      break;
    }
    default: throw new Error('Use inspect, route, diagnose, plan, apply, rollback, verify, or phase. See harness/update/UPDATE_PROTOCOL.md.');
  }
  output(result);
  if (['FAIL', 'BLOCKED', 'DEFERRED', 'ROLLBACK_VERIFICATION_FAILED'].includes(result.status)) process.exitCode = result.status === 'DEFERRED' ? 3 : 1;
} catch (error) {
  output({ status: 'BLOCKED', error: error.message, next_action: 'Read the recorded plan/conflict or rollback evidence; resolve the cause before retrying. No completion claim is made.' });
  process.exitCode = 1;
}
