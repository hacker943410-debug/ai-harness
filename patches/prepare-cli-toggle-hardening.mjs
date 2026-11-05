#!/usr/bin/env node
/**
 * Local, opt-in v8 source patch preparer. Defaults to preview; no GitHub API,
 * no OS/credential changes, no running Codex. Use --apply ONLY in user-reviewed
 * local checkout of feature/v8-environment-bootstrap-phase2, not in production.
 */
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

export function hardenedCli(source) {
  const pairs = [
    ["import {install,status,toggle,uninstall} from './lib/install.mjs';", "import {install,status,uninstall} from './lib/install.mjs';"],
    ["import {createInterface} from 'node:readline/promises';", ''],
    ["else if(cmd==='on'||cmd==='off')print(toggle(h,cmd.toUpperCase()));", "else if(cmd==='on'||cmd==='off')throw Error('V8_SUPERVISOR_OWNER_ONLY_TOGGLE_UNAVAILABLE');"],
    [
      "else if(cmd===undefined){if(!process.stdin.isTTY)print({product:'J Harness Core',version,...status(h),menu:['ON','OFF'],help:'jh on | jh off | jh status | jh doctor | jh start'});else{const rl=createInterface({input:process.stdin,output:process.stdout});print(status(h));try{const value=(await rl.question('J Harness: 1 ON / 2 OFF / Enter 종료: ')).trim();if(value==='1'||value==='2')print(toggle(h,value==='1'?'ON':'OFF'));}finally{rl.close();}}}",
      "else if(cmd===undefined)print({product:'J Harness Core',version,...status(h),menu:'READ_ONLY_PENDING_TRUSTED_OS_USER_UI',toggle:'BLOCKED_UNTIL_SEPARATE_SUPERVISOR',help:'jh status | jh doctor'});"
    ],
    [
      'Usage: jh [environment inspect|environment plan|on|off|status|doctor|start|begin|advance|verify|skills|policy|progress|finish|uninstall]',
      'Usage: jh [environment inspect|environment plan|status|doctor|start|begin|advance|verify|skills|policy|progress|finish|uninstall]; ON/OFF requires a future trusted OS UI'
    ],
  ];
  let next = source;
  for (const [before,after] of pairs) {
    const first=next.indexOf(before);
    if (first<0 || next.indexOf(before,first+before.length)>=0)
      throw Error('SOURCE_DRIFT_ABORTED: required exact unique anchor not found');
    next=next.slice(0,first)+after+next.slice(first+before.length);
  }
  return next;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root=process.argv[2];const apply=process.argv[3]==='--apply';
  try {
    if (!root || !path.isAbsolute(root)) throw Error('ABSOLUTE_REPOSITORY_CHECKOUT_PATH_REQUIRED');
    const file=path.join(root,'core','cli.mjs');
    if (fs.lstatSync(file).isSymbolicLink()) throw Error('SYMLINK_REFUSED');
    const source=fs.readFileSync(file,'utf8'), result=hardenedCli(source);
    const sha=bytes=>crypto.createHash('sha256').update(bytes).digest('hex');
    if (apply) {
      const tmp=file+'.supervisor-phase0.tmp';
      fs.writeFileSync(tmp,result,{flag:'wx'});
      try {fs.renameSync(tmp,file);} finally {if(fs.existsSync(tmp))fs.unlinkSync(tmp);}
    }
    console.log(JSON.stringify({phase:'SUPERVISOR_PHASE0',mode:apply?'LOCAL_APPLIED':'PREVIEW_ONLY',file,
      beforeSha256:sha(source),afterSha256:sha(result),changed:source!==result,
      noOSBoundaryClaim:true,mainOrReleaseNotTouched:true},null,2));
  } catch(error){console.error(JSON.stringify({result:'BLOCKED',reason:error.message}));process.exitCode=2;}
}
