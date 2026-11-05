/**
 * Laboratory IPC broker, Linux/Unix only. NO live tool, CLI, install or toggle control.
 * A separate restricted UID MUST be used for AI worker tests. An agent calling
 * this broker while sharing its UID invalidates any isolation conclusion.
 */
import fs from 'node:fs';
import path from 'node:path';
import net from 'node:net';
import {digest,inspectTrustedLab} from './lab.mjs';

export function examineOwnerState(root) {
  try {
    const p=path.join(root,'protected');
    const file=path.join(p,'state.json');
    const f=fs.lstatSync(file);
    if (!f.isFile() || f.isSymbolicLink() || f.uid !== process.getuid() || (f.mode & 0o077)) throw Error('UNTRUSTED_STATE_PERMISSIONS');
    const s=JSON.parse(fs.readFileSync(file,'utf8'));
    const policy=fs.readFileSync(path.join(p,'policy.json'));
    if (s.schema!==1 || !Number.isSafeInteger(s.epoch) || s.epoch<1) throw Error('INVALID_STATE');
    if (!/^[0-9a-f]{64}$/.test(s.policySha256 || '') || digest(policy)!==s.policySha256) throw Error('POLICY_INTEGRITY_FAILURE');
    if(s.desired==='OFF')return {state:'UNMANAGED',desired:'OFF',epoch:s.epoch,reason:'USER_OFF_LAB_FIXTURE_ONLY'};
    if(s.desired!=='ON')throw Error('INVALID_TOGGLE_STATE');
    return {state:'BLOCKED',desired:'ON',epoch:s.epoch,reason:'OS_BOUNDARY_ONLY_NO_CLI_TOOL_GATE'};
  } catch(e) {
    return {state:'BLOCKED',desired:'UNKNOWN',epoch:null,reason:e.message?.slice(0,100) || 'TRUSTED_STATE_UNAVAILABLE'};
  }
}
const safeMessage=(obj)=> JSON.stringify(obj)+'\n';
function decision(root, req, isControl) {
  if (!req || typeof req!=='object' || Array.isArray(req) || typeof req.op !== 'string') return {decision:'DENY',reason:'INVALID_REQUEST'};
  // Even root-side control socket cannot toggle until trusted UI/auth service exists.
  if (req.op === 'toggle' || req.op==='change_policy' || req.op === 'push' || req.op==='deploy')
    return {decision:'DENY',reason:'USER_AUTHENTICATION_NOT_IMPLEMENTED'};
  if (req.op==='status' || req.op==='doctor') {
    const state=examineOwnerState(root);
    return {decision:'READ_ONLY',product:'J Harness',version:'8.0-supervisor-phase1-lab',...state,
      enforcement:'NOT_ATTESTED',launchAuthorized:false,realCli:'NOT_RUN',toggleAvailable:false,
      source:'TRUSTED_BROKER_OBSERVATION_NOT_WINDOWS_E2E',
      ...(req.op==='doctor'?{limitations:['NO_WINDOWS_SERVICE','NO_TRUSTED_ONOFF_UI','NO_CLI_GATE','NO_NETWORK_SANDBOX']}: {})};
  }
  return {decision:'DENY',reason:'UNKNOWN_OPERATION'};
}
function serve(socketPath, root, isControl) {
  return new Promise((resolve,reject)=>{
    const server=net.createServer(conn=>{
      let buf=''; conn.setEncoding('utf8');conn.setTimeout(2000);
      conn.on('timeout',()=>conn.destroy());
      conn.on('error',()=>{});
      conn.on('data',part=>{
        buf+=part;
        if (buf.length>8192) {conn.end(safeMessage({decision:'DENY',reason:'REQUEST_TOO_LARGE'}));return;}
        if (!buf.includes('\n'))return;
        try {
          const req=JSON.parse(buf.slice(0,buf.indexOf('\n')));
          conn.end(safeMessage(decision(root,req,isControl)));
        } catch { conn.end(safeMessage({decision:'DENY',reason:'MALFORMED_JSON'})); }
      });
    });
    server.on('error',reject);
    server.listen(socketPath,()=>{
      // Note: the directory containing control.sock is private to broker UID.
      fs.chmodSync(socketPath,isControl?0o600:0o666);
      resolve(server);
    });
  });
}
export async function startLabBroker(root, workspace) {
  const checked=inspectTrustedLab(root,workspace);
  const pub=path.join(checked.root,'public','status.sock');
  const ctl=path.join(checked.root,'protected','control.sock');
  if (fs.existsSync(pub) || fs.existsSync(ctl)) throw Error('EXISTING_SOCKET_PRESERVED_REVIEW_REQUIRED');
  const a=await serve(pub,checked.root,false);
  let b;
  try{b=await serve(ctl,checked.root,true);}catch(e){a.close();throw e;}
  const close=()=>Promise.all([a,b].map(server=>new Promise(r=>server.close(r))));
  return {publicSocket:pub,controlSocket:ctl,close};
}
