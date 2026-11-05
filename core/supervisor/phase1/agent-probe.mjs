#!/usr/bin/env node
/** This program MUST be started by the test runner as an independent low-rights UID. */
import fs from 'node:fs';
import path from 'node:path';
import {request,readStatus} from './client.mjs';
const [root,workspace]=process.argv.slice(2);
if(!root||!workspace)process.exit(2);
const result={actorUid:process.getuid?.(),protectedRead:'UNKNOWN',protectedWrite:'UNKNOWN',controlPipe:'UNKNOWN',workspaceWrite:'UNKNOWN',publicToggle:'UNKNOWN',publicPolicyChange:'UNKNOWN',status:null};
function probe(fn){try{fn();return 'ALLOWED'}catch(e){return e.code || 'ERROR'}}
result.protectedRead=probe(()=>fs.readFileSync(path.join(root,'protected','policy.json')));
result.protectedWrite=probe(()=>fs.writeFileSync(path.join(root,'protected','policy.json'),'TAMPERED'));
result.workspaceWrite=probe(()=>fs.writeFileSync(path.join(workspace,'agent-work.txt'),'WORKER_CAN_WORK'));
result.status=await readStatus(root);
result.publicToggle=(await request(path.join(root,'public','status.sock'),'toggle',{state:'OFF'})).decision;
result.publicPolicyChange=(await request(path.join(root,'public','status.sock'),'change_policy')).decision;
try {result.controlPipe=(await request(path.join(root,'protected','control.sock'),'toggle')).decision}
catch(e){result.controlPipe=e.code||'ERROR'}
result.protectedStateWrite=probe(()=>fs.writeFileSync(path.join(root,'protected','state.json'),'OFF'));
result.fakePassInfluence=(await request(path.join(root,'public','status.sock'),'status',{agentClaim:'ENFORCED',pass:true})).enforcement;
console.log(JSON.stringify(result));
const blocked=v=>v==='EACCES'||v==='EPERM';
if (result.actorUid===0 || !blocked(result.protectedRead) || !blocked(result.protectedWrite) || !blocked(result.protectedStateWrite) || !blocked(result.controlPipe) || result.workspaceWrite!=='ALLOWED' || result.status.state!=='BLOCKED' || result.publicToggle!=='DENY' || result.publicPolicyChange!=='DENY' || result.fakePassInfluence!=='NOT_ATTESTED') process.exitCode=3;
