/** Experimental owner-only fixture creator. No global installation, credentials or CLI. */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import crypto from 'node:crypto';

export const digest = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
export function inPath(outer, inner) {
  const rel = path.relative(outer, inner);
  return !rel || (rel !== '..' && !rel.startsWith('..' + path.sep) && !path.isAbsolute(rel));
}
function secureWrite(file, bytes, mode = 0o600) {
  fs.writeFileSync(file, bytes, {flag:'wx', mode});
  fs.chmodSync(file, mode);
}
export function createLab() {
  if (process.platform === 'win32' || typeof process.getuid !== 'function') throw Error('UNIX_LAB_ONLY');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'jh-phase1-lab-'));
  try {
    // Parent is executable but cannot be listed or mutated by the worker.
    fs.chmodSync(root, 0o711);
    const protectedDir = path.join(root, 'protected');
    const publicDir = path.join(root, 'public');
    const workspace = path.join(root, 'workspace');
    fs.mkdirSync(protectedDir, {mode:0o700});
    fs.mkdirSync(publicDir, {mode:0o711});
    fs.mkdirSync(workspace, {mode:0o777});
    fs.chmodSync(protectedDir, 0o700);
    fs.chmodSync(publicDir, 0o711);
    fs.chmodSync(workspace, 0o777);
    secureWrite(path.join(protectedDir, 'fixture.json'), JSON.stringify({product:'J Harness Phase1 Unix Laboratory', schema:1, production:false}) + '\n');
    const policy = Buffer.from(JSON.stringify({schema:1, id:'LAB_POLICY_ONLY', noRealCli:true})+'\n');
    secureWrite(path.join(protectedDir, 'policy.json'), policy);
    secureWrite(path.join(protectedDir, 'state.json'), JSON.stringify({schema:1, desired:'ON', epoch:1, policySha256:digest(policy)}) + '\n');
    return {root, protectedDir, publicDir, workspace, publicSocket:path.join(publicDir,'status.sock'),controlSocket:path.join(protectedDir,'control.sock')};
  } catch(e) {fs.rmSync(root,{recursive:true, force:true}); throw e;}
}
export function inspectTrustedLab(root, workspace) {
  if (process.platform === 'win32' || typeof process.getuid !== 'function') throw Error('UNIX_LAB_ONLY');
  const suppliedRoot = path.resolve(root);
  const rootInfo = fs.lstatSync(suppliedRoot);
  if (!rootInfo.isDirectory() || rootInfo.isSymbolicLink()) throw Error('UNTRUSTED_LAB_ROOT');
  const real = fs.realpathSync(root), realWork = fs.realpathSync(workspace);
  if (!path.basename(real).startsWith('jh-phase1-lab-') || fs.realpathSync(path.dirname(real)) !== fs.realpathSync(os.tmpdir())) throw Error('TEMP_LAB_ONLY');
  const workspaceInfo=fs.lstatSync(path.join(real, 'workspace'));
  if (!workspaceInfo.isDirectory() || workspaceInfo.isSymbolicLink() || workspaceInfo.uid !== process.getuid()) throw Error('UNTRUSTED_WORKSPACE');
  if (realWork !== path.join(real,'workspace') || inPath(real,realWork) === false || inPath(realWork,path.join(real,'protected'))) throw Error('LAB_PATH_INVALID');
  for (const ancestor of [real,path.join(real,'protected'),path.join(real,'public')]) {
    const s=fs.lstatSync(ancestor);
    if (!s.isDirectory() || s.isSymbolicLink() || s.uid !== process.getuid()) throw Error('UNTRUSTED_LAB_ROOT');
    if ((s.mode & 0o022) !== 0) throw Error('WRITABLE_BY_UNTRUSTED_IDENTITY');
  }
  if ((fs.statSync(path.join(real,'protected')).mode & 0o077)!==0) throw Error('PROTECTED_DIR_NOT_PRIVATE');
  for (const name of ['fixture.json','policy.json','state.json']) {
    const s=fs.lstatSync(path.join(real,'protected',name));
    if (!s.isFile() || s.isSymbolicLink() || s.uid!==process.getuid() || (s.mode & 0o077)!==0) throw Error('UNTRUSTED_PROTECTED_FILE');
  }
  const mark=JSON.parse(fs.readFileSync(path.join(real,'protected','fixture.json'),'utf8'));
  if (mark.schema!==1 || mark.production!==false || mark.product!=='J Harness Phase1 Unix Laboratory') throw Error('NOT_AN_ISOLATED_LAB');
  return {root:real,workspace:realWork};
}
