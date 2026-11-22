#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {contained,noLinks,sha256,validateRuntime} from './lib/portable-context.mjs';
import {bridgeStart,bridgeEnd,projectBridge} from './lib/project-bridge.mjs';

const source = path.dirname(fileURLToPath(import.meta.url));
const packageRoot = path.resolve(source, '../..');
const runtimeName = '.agents/j-harness';
const bindingName = '.ai/harness-project.json';
const upgradeRootName = '.jh-artifacts/j-harness-core/upgrades';
const launcherHashes = {
  'JHarness.cmd': 'ff81d970a1affc962829ea1710e02f9efec1893170262ab3e0d29bd9383087b4',
  'JHarness.ps1': 'f3aa61fb3d5bef96955d1cfa07c6f4d9001437c5ff8f147835fff3d11c3a0907',
};
const alpha = {
  distribution: '8.0.0-alpha.3',
  core: '8.0.0-core-beta.1',
  manifest: '8b3f4dc932d92525322cf8b733a518bc16679bec8efe161ac9e3e7e0e4a71224',
  portableGuide: '8d256875a31f8d0a6811b72d8c3d4dad7d165e6fe1829667ec0118ada4792e47',
  launcherHashes: {
    ...launcherHashes,
    'JHarness-README.md': '62d2b978f1ab57a369c28f2192db85a52da6a0ca621bd987cfedee69e9911aae',
  },
  recoveryLabel: 'ALPHA3',
};
const v81 = {
  distribution: '8.1.0',
  core: '8.1.0',
  manifest: 'dca504705cb5658ba5a1d113c2dc4f41957bec12d94287f488c0747be9e6970c',
  portableGuide: '5cbdd1d3f2461b14fd7016f05861d09365d45884f8a23cb9efbe767a83a11461',
  launcherHashes: {...launcherHashes,'JHarness-README.md':'04c21b6710468ab0339c53a266aefb5d8756ac4639d224ab9af28d65b5d37655'},
  recoveryLabel: 'V8_1_0',
};
const v82 = {
  distribution: '8.2.0',
  core: '8.2.0',
  manifest: '322d3a842e35d4ee204a6f24896707a1dcba870950182c1e7b03ba5fe857ac8e',
  portableGuide: '7574085e91d554fe46404b0531f62a0d33566c559ae4f9ec081c29bc47c96196',
  launcherHashes: {
    ...launcherHashes,
    'JHarness.ps1': '2e1444a2975d407c7f47e37faa487415cbd085955003be4248385de1c7709f17',
    'JHarness-README.md': 'affd3fb538fb2fba450f1723a9c8f98fd666cfd67c36917f0c8f665fa02379c2',
  },
  recoveryLabel: 'V8_2_0',
};
const previousBuild = pin => [alpha,v81,v82].find(build => build.manifest === pin);
const manifestHash = runtime => sha256(fs.readFileSync(contained(runtime, 'manifest.json')));
const decode = bytes => new TextDecoder('utf-8', {fatal:true,ignoreBOM:true}).decode(bytes);
const read = file => JSON.parse(decode(fs.readFileSync(file)).replace(/^\uFEFF/, ''));

function assertIdle(project) {
  const workflowFile = contained(project, '.jh-artifacts/j-harness-core/workflow.json');
  const stateFile = contained(project, '.ai/harness-state.json');
  if (fs.existsSync(workflowFile) && read(workflowFile)?.finished !== true) {
    throw Error('ACTIVE_WORKFLOW_BLOCKS_UPGRADE');
  }
  if (fs.existsSync(stateFile)) {
    const state = read(stateFile);
    if (state?.operation_in_progress ||
        (state?.development_state && !['STABLE','NOT_STARTED','COMPLETED'].includes(state.development_state))) {
      throw Error('ACTIVE_DEVELOPMENT_STATE_BLOCKS_UPGRADE');
    }
  }
}

// The installed schema has a top-level harness object. Replace only its three
// owned string tokens so other fields retain their exact formatting and values.
function patchBinding(bytes, targetVersion, targetHash, priorBuild) {
  const text = decode(bytes);
  const binding = JSON.parse(text.replace(/^\uFEFF/, ''));
  const managed = binding?.harness;
  if (binding?.schema_version !== 4 || binding.binding?.harness ||
      managed?.product !== 'J Harness Core' || managed.mode !== 'PROJECT_PORTABLE' ||
      managed.root !== runtimeName || managed.version !== priorBuild.core ||
      managed.manifest_sha256 !== priorBuild.manifest || managed.source_hash !== priorBuild.manifest) {
    throw Error('UNSUPPORTED_'+priorBuild.recoveryLabel+'_BINDING');
  }
  if (managed.manifestSha256 !== undefined) throw Error('AMBIGUOUS_MANIFEST_PIN_REQUIRES_REVIEW');
  const tokens = [...text.matchAll(/"(?:[^"\\]|\\[\s\S])*"|[{}\[\]:,]|[^\s{}\[\]:,"]+/g)];
  function property(objectIndex, name) {
    if (tokens[objectIndex]?.[0] !== '{') throw Error('MANAGED_JSON_OBJECT_REQUIRED');
    let depth = 0;
    const values = [];
    for (let index = objectIndex + 1; index < tokens.length; index++) {
      const token = tokens[index][0];
      if (token === '}' && depth === 0) break;
      if (depth === 0 && token.startsWith('"') && tokens[index+1]?.[0] === ':' && JSON.parse(token) === name) {
        values.push(index+2);
      }
      if (token === '{' || token === '[') depth++;
      if (token === '}' || token === ']') depth--;
    }
    if (values.length !== 1) throw Error('MANAGED_JSON_PROPERTY_MISSING_OR_DUPLICATE: '+name);
    return values[0];
  }
  const object = property(0, 'harness');
  const updates = Object.entries({version:targetVersion,manifest_sha256:targetHash,source_hash:targetHash})
    .map(([name,value]) => ({token:tokens[property(object,name)],value}))
    .sort((a,b) => b.token.index-a.token.index);
  return Buffer.from(updates.reduce((content,{token,value}) =>
    content.slice(0,token.index)+JSON.stringify(value)+content.slice(token.index+token[0].length),text));
}

function patchGuidance(bytes, version, priorBuild) {
  const text = decode(bytes);
  const start = text.indexOf(bridgeStart), end = text.indexOf(bridgeEnd);
  const after = end+bridgeEnd.length;
  if (start < 0 || end < start || text.lastIndexOf(bridgeStart) !== start || text.lastIndexOf(bridgeEnd) !== end ||
      text.slice(start,after) !== projectBridge(runtimeName,priorBuild.core,true)) {
    throw Error('MANAGED_PROJECT_BRIDGE_REQUIRES_REVIEW');
  }
  return Buffer.from(text.slice(0,start)+projectBridge(runtimeName,version,true)+text.slice(after));
}

function replacement(name,bytes,target,targetPin,priorBuild) {
  if (name === bindingName) return patchBinding(bytes,target.version,targetPin,priorBuild);
  if (name === 'AGENTS.md') return patchGuidance(bytes,target.version,priorBuild);
  if (sha256(bytes) !== priorBuild.launcherHashes[name]) throw Error('CUSTOM_LAUNCHER_REQUIRES_REVIEW: '+name);
  return fs.readFileSync(contained(packageRoot,name));
}

function inspectUpgrade(project, target, targetPin) {
  const runtime = contained(project,runtimeName);
  const priorPin = manifestHash(runtime);
  const result = {project,productVersion:target.distributionVersion,coreVersion:target.version,manifestSha256:targetPin};
  if (priorPin === targetPin) {
    if (validateRuntime(runtime,project).projectBinding !== 'BOUND_VERIFIED') throw Error('BOUND_TARGET_REQUIRED');
    return {result:{...result,result:'ALREADY_CURRENT',effective:'READY_LOCAL'},edits:[]};
  }
  const priorBuild = previousBuild(priorPin);
  if (!priorBuild) throw Error('ONLY_PINNED_ALPHA3_8_1_0_OR_8_2_0_PORTABLE_UPGRADE_SUPPORTED');
  const prior = validateRuntime(runtime,project);
  if (prior.version !== priorBuild.core || prior.distributionVersion !== priorBuild.distribution || prior.projectBinding !== 'BOUND_VERIFIED') {
    throw Error('BOUND_'+priorBuild.recoveryLabel+'_REQUIRED');
  }
  if (sha256(fs.readFileSync(contained(runtime,'PORTABLE.md'))) !== priorBuild.portableGuide ||
      fs.existsSync(contained(runtime,'tests'))) throw Error('CUSTOM_'+priorBuild.recoveryLabel+'_RUNTIME_REQUIRES_REVIEW');
  assertIdle(project);

  const edits = [bindingName,'AGENTS.md',...Object.keys(priorBuild.launcherHashes)].map(name => {
    const before = fs.readFileSync(contained(project,name));
    return {name,before,after:replacement(name,before,target,targetPin,priorBuild)};
  }).filter(({before,after}) => !before.equals(after));
  return {result:{...result,result:'PLAN_ONLY_NOT_UPGRADED',previousProductVersion:prior.distributionVersion,
    previousCoreVersion:prior.version,previousManifestSha256:priorPin,managedChanges:[runtimeName,...edits.map(x=>x.name)],
    previousVerification:'REVERIFY_AFTER_UPGRADE'},edits,priorBuild};
}

function writeNew(file,content) {
  const fd = fs.openSync(file,'wx',0o600);
  try { fs.writeFileSync(fd,content); fs.fsyncSync(fd); } finally { fs.closeSync(fd); }
}

function expectBytes(file,expected) {
  if (!fs.readFileSync(file).equals(expected)) throw Error('PROJECT_FILE_CHANGED_PRESERVED: '+path.basename(file));
}

function move(from,to) {
  noLinks(from);noLinks(to);
  if (fs.existsSync(to)) throw Error('UPGRADE_DESTINATION_ALREADY_EXISTS: '+path.basename(to));
  fs.renameSync(from,to);
}

function stageRuntime(destination,manifest) {
  // Windows Node 22 can crash in cpSync on a path containing Korean text.
  // Copy the validated inventory explicitly and verify it again before activation.
  fs.mkdirSync(destination);
  for (const rel of ['manifest.json',...manifest.files.map(file=>file.path)]) {
    const output = contained(destination,rel);
    fs.mkdirSync(path.dirname(output),{recursive:true});
    fs.copyFileSync(contained(source,rel),output,fs.constants.COPYFILE_EXCL);
  }
}

function doctor(runtime,project,expectedVersion,expectedProduct) {
  const env = Object.fromEntries(Object.entries(process.env).filter(([name]) => !/^NODE_(?:OPTIONS|PATH)$/i.test(name)));
  const processResult = spawnSync(contained(runtime,'vendor/win-x64/node.exe'),
    [contained(runtime,'portable.mjs'),'--project',project,'doctor'],{cwd:project,env,encoding:'utf8',windowsHide:true,timeout:30000});
  if (processResult.status !== 0) throw Error('UPGRADE_DOCTOR_FAILED: '+(processResult.stderr || processResult.error?.code || '').trim());
  const observed = JSON.parse(processResult.stdout);
  if (observed.effective !== 'READY_LOCAL' || observed.version !== expectedVersion || observed.runtimeIntegrity !== 'VERIFIED' ||
      (expectedProduct && (observed.distributionVersion !== expectedProduct || observed.projectBinding !== 'BOUND_VERIFIED'))) {
    throw Error('UPGRADE_DOCTOR_RESULT_MISMATCH');
  }
}

function assertStopped(pid) {
  if (!Number.isSafeInteger(pid) || pid < 1 || pid > 2147483647) throw Error('INVALID_UPGRADE_PROCESS_ID');
  try { process.kill(pid,0); }
  catch (error) {
    if (error.code === 'ESRCH') return;
    throw Error('UPGRADE_PROCESS_STATUS_UNKNOWN: '+error.code);
  }
  throw Error('UPGRADE_PROCESS_STILL_RUNNING');
}

function recoverUpgrade(project,target,targetPin,lockFile,recoveryLock) {
  const lockBytes = fs.readFileSync(lockFile);
  const {run,pid} = JSON.parse(lockBytes.toString('utf8'));
  if (typeof run !== 'string' || !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(run)) {
    throw Error('INVALID_UPGRADE_TRANSACTION_ID');
  }
  assertStopped(pid);
  const recovery = fs.openSync(recoveryLock,'wx',0o600);
  try {
    expectBytes(lockFile,lockBytes);
    const directory = contained(project,upgradeRootName+'/'+run);
    const journal = contained(directory,'journal.json');
    const completed = contained(directory,'receipt.json');
    const runtime = contained(project,runtimeName);
    const newPin = fs.existsSync(runtime) ? manifestHash(runtime) : null;
    let outcome;
    if (fs.existsSync(completed)) {
      const receipt = read(completed);
      if (receipt.result !== 'V8_PROJECT_UPGRADE_COMPLETE' || receipt.project !== project ||
          receipt.manifestSha256 !== targetPin || newPin !== targetPin) throw Error('COMPLETED_UPGRADE_REQUIRES_REVIEW');
      doctor(runtime,project,target.version,target.distributionVersion);
      outcome = 'COMPLETED_UPGRADE_VERIFIED';
    } else if (!fs.existsSync(journal)) {
      const priorBuild = previousBuild(newPin);
      if (!priorBuild || inspectUpgrade(project,target,targetPin).result.result !== 'PLAN_ONLY_NOT_UPGRADED') {
        throw Error('UNJOURNALED_UPGRADE_REQUIRES_REVIEW');
      }
      doctor(runtime,project,priorBuild.core);
      outcome = priorBuild.recoveryLabel+'_PREPARATION_INTERRUPTED_ORIGINAL_VERIFIED';
    } else {
      const plan = read(journal);
      const priorBuild = previousBuild(plan.previousManifestSha256);
      if (plan.result !== 'PREPARED' || plan.project !== project || plan.manifestSha256 !== targetPin ||
          !priorBuild || !Array.isArray(plan.files)) {
        throw Error('UPGRADE_JOURNAL_DOES_NOT_MATCH_PACKAGE');
      }
      assertIdle(project);
      const allowed = new Set([bindingName,'AGENTS.md',...Object.keys(priorBuild.launcherHashes)]);
      const edits = plan.files.map((row,index) => {
        if (!allowed.delete(row.name) || row.backup !== index+'.before') throw Error('INVALID_UPGRADE_RECOVERY_ENTRY');
        const file = contained(project,row.name);
        const before = fs.readFileSync(contained(directory,row.backup));
        const after = replacement(row.name,before,target,targetPin,priorBuild);
        if (sha256(before) !== row.beforeSha256 || sha256(after) !== row.afterSha256) throw Error('UPGRADE_BACKUP_DIGEST_MISMATCH');
        const current = fs.readFileSync(file);
        if (!current.equals(before) && !current.equals(after)) throw Error('PROJECT_FILE_CHANGED_PRESERVED: '+row.name);
        return {file,before,after,changed:!current.equals(before)};
      });
      if (allowed.has(bindingName) || allowed.has('AGENTS.md')) throw Error('INCOMPLETE_UPGRADE_CONTROL_BACKUP');
      const previous = contained(directory,'previous-runtime');
      if (newPin !== null && newPin !== priorBuild.manifest && newPin !== targetPin) throw Error('PROJECT_RUNTIME_CHANGED_PRESERVED');
      const original = newPin === priorBuild.manifest ? runtime : previous;
      if (manifestHash(original) !== priorBuild.manifest ||
          sha256(fs.readFileSync(contained(original,'PORTABLE.md'))) !== priorBuild.portableGuide ||
          fs.existsSync(contained(original,'tests'))) throw Error('PREVIOUS_RUNTIME_CHANGED_PRESERVED');
      validateRuntime(original,directory);
      if (newPin === targetPin) {
        validateRuntime(runtime,directory);
        move(runtime,contained(directory,'rejected-runtime'));
      }
      if (newPin !== priorBuild.manifest) move(previous,runtime);
      for (const edit of edits.reverse().filter(row => row.changed)) {
        expectBytes(edit.file,edit.after);
        const staged = contained(directory,'restore-'+randomUUID());
        writeNew(staged,edit.before);
        fs.renameSync(staged,edit.file);
      }
      doctor(runtime,project,priorBuild.core);
      outcome = priorBuild.recoveryLabel+'_RESTORED_VERIFIED';
    }
    fs.mkdirSync(directory,{recursive:true});
    const report = {result:outcome,project,transaction:upgradeRootName+'/'+run,recoveredUtc:new Date().toISOString()};
    writeNew(contained(directory,'recovery-'+randomUUID()+'.json'),JSON.stringify(report,null,2)+'\n');
    expectBytes(lockFile,lockBytes);
    fs.unlinkSync(lockFile);
    return report;
  } finally {
    fs.closeSync(recovery);
    fs.unlinkSync(recoveryLock);
  }
}

function applyUpgrade(project,target,targetPin,lockFile) {
  const run = randomUUID();
  const transaction = contained(project,upgradeRootName+'/'+run);
  fs.mkdirSync(path.dirname(lockFile),{recursive:true});
  const lock = fs.openSync(lockFile,'wx',0o600);
  let preserveLock = false;
  try {
    fs.writeFileSync(lock,JSON.stringify({run,pid:process.pid})+'\n');
    fs.fsyncSync(lock);
    const {result,edits,priorBuild} = inspectUpgrade(project,target,targetPin);
    if (result.result === 'ALREADY_CURRENT') return result;
    fs.mkdirSync(transaction);
    const runtime = contained(project,runtimeName);
    const previous = contained(transaction,'previous-runtime');
    const staged = contained(transaction,'candidate-runtime');
    const rejected = contained(transaction,'rejected-runtime');
    const control = edits.map((edit,index) => ({
      ...edit,file:contained(project,edit.name),backup:contained(transaction,index+'.before'),
      candidate:contained(transaction,index+'.after'),restore:contained(transaction,index+'.restore'),
    }));
    const receipt = {...result,transaction:upgradeRootName+'/'+run,
      files:control.map(x=>({name:x.name,backup:path.basename(x.backup),beforeSha256:sha256(x.before),afterSha256:sha256(x.after)}))};
    const log = (name,status) => writeNew(contained(transaction,name+'.json'),JSON.stringify({...receipt,...status},null,2)+'\n');
    let priorMoved = false, targetMoved = false;
    const changed = [];
    try {
      for (const file of control) {
        writeNew(file.backup,file.before);
        writeNew(file.candidate,file.after);
      }
      stageRuntime(staged,target);
      validateRuntime(staged,transaction);
      if (manifestHash(staged) !== targetPin) throw Error('CANDIDATE_CHANGED_DURING_STAGING');
      log('journal',{result:'PREPARED',preparedUtc:new Date().toISOString()});
      const checked = inspectUpgrade(project,target,targetPin);
      if (checked.result.result !== 'PLAN_ONLY_NOT_UPGRADED') throw Error('PROJECT_VERSION_CHANGED_DURING_STAGING');
      for (const file of control) expectBytes(file.file,file.before);
      move(runtime,previous); priorMoved = true;
      move(staged,runtime); targetMoved = true;
      for (const file of control) {
        noLinks(file.file);
        expectBytes(file.file,file.before);
        fs.renameSync(file.candidate,file.file);
        changed.push(file);
      }
      doctor(runtime,project,target.version,target.distributionVersion);
      const completion = {result:'V8_PROJECT_UPGRADE_COMPLETE',effective:'READY_LOCAL',completedUtc:new Date().toISOString()};
      log('receipt',completion);
      return {...receipt,...completion};
    } catch (error) {
      let recovery = 'ORIGINAL_FILES_PRESERVED';
      try {
        for (const file of changed) {
          noLinks(file.file);
          expectBytes(file.file,file.after);
        }
        if (targetMoved) {
          validateRuntime(runtime,transaction);
          if (manifestHash(runtime) !== targetPin) throw Error('CANDIDATE_RUNTIME_CHANGED_PRESERVED');
          move(runtime,rejected);
        }
        if (priorMoved) {
          if (manifestHash(previous) !== priorBuild.manifest) throw Error('PREVIOUS_RUNTIME_CHANGED_PRESERVED');
          validateRuntime(previous,transaction);
          move(previous,runtime);
        }
        for (const file of changed.reverse()) {
          noLinks(file.file);
          expectBytes(file.file,file.after);
          writeNew(file.restore,file.before);
          fs.renameSync(file.restore,file.file);
        }
        if (priorMoved) {
          doctor(runtime,project,priorBuild.core);
          recovery = priorBuild.recoveryLabel+'_RESTORED_VERIFIED';
        }
      } catch (restoreError) {
        preserveLock = true;
        recovery = 'MANUAL_RECOVERY_REQUIRED: '+restoreError.message;
      }
      log('failure',{result:'BLOCKED',error:error.message,recovery});
      throw Error(error.message+'; '+recovery+'; backup: '+receipt.transaction);
    }
  } finally {
    fs.closeSync(lock);
    if (!preserveLock) fs.unlinkSync(lockFile);
  }
}

try {
  const [action,projectPath] = process.argv.slice(2);
  if (!['Plan','Install','Recover'].includes(action) || !projectPath || process.argv.length !== 4) throw Error('Usage: upgrade.mjs Plan|Install|Recover <project>');
  noLinks(projectPath);
  const project = fs.realpathSync.native(path.resolve(projectPath));
  if (!fs.statSync(project).isDirectory() || project === path.parse(project).root) throw Error('PROJECT_DIRECTORY_REQUIRED');
  const target = validateRuntime(source,packageRoot);
  if (target.version !== target.distributionVersion || !/^8\.2\.\d+(?:-[0-9A-Za-z.-]+)?$/.test(target.distributionVersion)) {
    throw Error('EXPECTED_V82_PORTABLE_PACKAGE');
  }
  const targetPin = manifestHash(source);
  const lock = contained(project,upgradeRootName+'/upgrade.lock');
  const recoveryLock = contained(project,upgradeRootName+'/recover.lock');
  if (fs.existsSync(recoveryLock)) throw Error('UPGRADE_RECOVERY_IN_PROGRESS_OR_REQUIRES_REVIEW');
  let result;
  if (action === 'Recover') {
    if (!fs.existsSync(lock)) throw Error('NO_INTERRUPTED_UPGRADE');
    result = recoverUpgrade(project,target,targetPin,lock,recoveryLock);
  } else {
    if (fs.existsSync(lock)) throw Error('UPGRADE_IN_PROGRESS_OR_RECOVERY_REQUIRED: '+path.relative(project,lock));
    const preview = inspectUpgrade(project,target,targetPin).result;
    result = action === 'Plan' || preview.result === 'ALREADY_CURRENT' ? preview : applyUpgrade(project,target,targetPin,lock);
  }
  console.log(JSON.stringify(result,null,2));
} catch (error) {
  console.error(JSON.stringify({result:'BLOCKED',reason:error.message}));
  process.exitCode = 2;
}
