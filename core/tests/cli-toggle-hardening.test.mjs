import test from 'node:test';
import assert from 'node:assert/strict';
import {hardenedCli} from '../../patches/prepare-cli-toggle-hardening.mjs';
const old=`import {createInterface} from 'node:readline/promises';
import {install,status,toggle,uninstall} from './lib/install.mjs';
else if(cmd==='on'||cmd==='off')print(toggle(h,cmd.toUpperCase()));
else if(cmd===undefined){if(!process.stdin.isTTY)print({product:'J Harness Core',version,...status(h),menu:['ON','OFF'],help:'jh on | jh off | jh status | jh doctor | jh start'});else{const rl=createInterface({input:process.stdin,output:process.stdout});print(status(h));try{const value=(await rl.question('J Harness: 1 ON / 2 OFF / Enter 종료: ')).trim();if(value==='1'||value==='2')print(toggle(h,value==='1'?'ON':'OFF'));}finally{rl.close();}}}
else throw Error('Usage: jh [environment inspect|environment plan|on|off|status|doctor|start|begin|advance|verify|skills|policy|progress|finish|uninstall]');`;
test('blocks non-interactive and PTY toggle paths',()=>{
  const x=hardenedCli(old);
  assert.match(x,/V8_SUPERVISOR_OWNER_ONLY_TOGGLE_UNAVAILABLE/);
  assert.match(x,/READ_ONLY_PENDING_TRUSTED_OS_USER_UI/);
  assert.doesNotMatch(x,/print\(toggle\(/);
  assert.doesNotMatch(x,/rl\.question/);
  assert.doesNotMatch(x,/from 'node:readline\/promises'/);
});
test('refuses drift, already patched sources and ambiguous anchors',()=>{
  assert.throws(()=>hardenedCli(''),/SOURCE_DRIFT_ABORTED/);
  assert.throws(()=>hardenedCli(old.replace("from './lib/install.mjs'","from './new/install.mjs'")),/SOURCE_DRIFT_ABORTED/);
  assert.throws(()=>hardenedCli(old+'\n'+old),/SOURCE_DRIFT_ABORTED/);
  assert.throws(()=>hardenedCli(hardenedCli(old)),/SOURCE_DRIFT_ABORTED/);
});
