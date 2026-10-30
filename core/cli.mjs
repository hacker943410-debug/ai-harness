#!/usr/bin/env node
import path from 'node:path';import fs from 'node:fs';import process from 'node:process';import {spawn} from 'node:child_process';import {createInterface} from 'node:readline/promises';
import {home,version} from './lib/io.mjs';import {install,status,toggle,uninstall} from './lib/install.mjs';import {resolveCodex} from './lib/codex.mjs';
import * as hub from './lib/skills.mjs';import * as flow from './lib/workflow.mjs';import {events,projectState} from './lib/events.mjs';
const argv=process.argv.slice(2),tail=argv.indexOf('--'),commandArgs=tail<0?[]:argv.splice(tail+1);if(tail>=0)argv.pop();
function option(name,fallback){const i=argv.indexOf('--'+name);if(i<0)return fallback;const value=argv[i+1];if(value===undefined||value.startsWith('--'))throw Error('OPTION_VALUE_REQUIRED_'+name);argv.splice(i,2);return value;}
function flag(name){const i=argv.indexOf('--'+name);if(i<0)return false;argv.splice(i,1);return true;}
const print=value=>console.log(typeof value==='string'?value:JSON.stringify(value,null,2));
try{
 const h=home(option('codex-home')),project=path.resolve(option('project',process.cwd())),cmd=argv.shift();
 if(cmd==='install')print(install(h));
 else if(cmd==='status')print(status(h));
 else if(cmd==='doctor'){const observed=status(h);const located=resolveCodex();print({...observed,cli:{installed:!!located,version:observed.codexVersion??null,versionSource:'CACHED_AT_INSTALL_NOT_LIVE_EXECUTION',execution:located},environmentHome:home(),profileMismatch:home()!==h,projectHasAgents:fs.existsSync(path.join(project,'AGENTS.md')),projectHasOverride:fs.existsSync(path.join(project,'AGENTS.override.md')),notes:['Global instructions apply to new Codex sessions. Project guidance can override them.','No config.toml, authentication, MCP registration, service, or OS account changes are needed.','A linked file alone is not proof of model behavior.']});}
 else if(cmd==='on'||cmd==='off')print(toggle(h,cmd.toUpperCase()));
 else if(cmd==='uninstall')print(uninstall(h));
 else if(cmd==='begin')print(flow.begin(h,project,argv.join(' ')));
 else if(cmd==='advance')print(flow.advance(h,project,argv.shift(),option('note')));
 else if(cmd==='verify'){const result=flow.verify(h,project,commandArgs);print(result);if(result.result!=='PASS')process.exitCode=1;}
 else if(cmd==='finish')print(flow.finish(h,project,option('guide','README.md')));
 else if(cmd==='progress'){const state=projectState(h,project);const current=state?.verification?flow.fingerprint(project).sha256===state.verification.sourceAfter:null;print({state,verificationCurrent:current,currentVerificationResult:current===false?'STALE':state?.verification?.result??'NOT_RUN',events:events(h,project)});}
 else if(cmd==='policy'&&argv.shift()==='read')print(flow.policy(h,project,argv.shift(),{full:flag('full')}));
 else if(cmd==='learn')print(flow.learn(h,project,option('cause'),option('fix')));
 else if(cmd==='lessons'){const query=argv.join(' ').toLowerCase();print(flow.lessons(h,project,query));}
 else if(cmd==='skills'){
  const action=argv.shift();
  if(action==='list')print(hub.list(h,project));
  else if(action==='search')print(hub.search(h,project,argv.join(' ')));
  else if(action==='read')print(hub.readSkill(h,project,argv.shift()));
  else if(action==='inspect')print(hub.inspect(path.resolve(option('path'))));
  else if(action==='register')print(hub.register(h,path.resolve(option('path')),option('source'),option('review-sha256'),flag('approve')));
  else if(action==='record')print(hub.record(h,project,argv.shift(),option('result'),option('note')));
  else throw Error('SKILLS_list_search_read_inspect_register_record');
 }
 else if(cmd==='start'){
  const cli=resolveCodex();if(!cli)throw Error('CODEX_NOT_INSTALLED');const s=status(h);if(!['CONNECTED_FOR_NEW_SESSIONS','OFF_FOR_NEW_SESSIONS'].includes(s.effective))throw Error('CHECK_JH_DOCTOR_BEFORE_START');
  console.error('[J Harness] '+s.effective+' · new Codex session · no model/auth overrides');
  const child=spawn(cli.file,[...cli.prefix,...(argv.length?[argv.join(' ')]:[])],{cwd:project,env:{...process.env,CODEX_HOME:h},stdio:'inherit',windowsHide:false});child.on('error',e=>{console.error(e.message);process.exitCode=1;});child.on('exit',code=>{process.exitCode=code??1;});
 }
 else if(cmd===undefined){if(!process.stdin.isTTY)print({product:'J Harness Core',version,...status(h),menu:['ON','OFF'],help:'jh on | jh off | jh status | jh doctor | jh start'});else{const rl=createInterface({input:process.stdin,output:process.stdout});print(status(h));try{const value=(await rl.question('J Harness: 1 ON / 2 OFF / Enter 종료: ')).trim();if(value==='1'||value==='2')print(toggle(h,value==='1'?'ON':'OFF'));}finally{rl.close();}}}
 else throw Error('Usage: jh [on|off|status|doctor|start|begin|advance|verify|skills|policy|progress|finish|uninstall]');
}catch(error){console.error(JSON.stringify({product:'J Harness Core',result:'ERROR',reason:error.message}));process.exitCode=1;}
