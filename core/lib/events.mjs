import fs from 'node:fs';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {portableContext,projectSlot,legacyProjectSlot,atomic,json,readJson,noLinks} from './io.mjs';
export function event(h,project,kind,data={}){
 const slot=projectSlot(h,project),file=path.join(slot,'events.jsonl');
 noLinks(file);fs.mkdirSync(slot,{recursive:true});
 const runId=data.runId??projectState(h,project)?.runId??null;
 const row={...data,runId,eventId:randomUUID(),utc:new Date().toISOString(),kind};
 fs.appendFileSync(file,JSON.stringify(row)+'\n',{mode:0o600});
 return row;
}
export function events(h,project){return[...(!portableContext()?[legacyProjectSlot(h,project)]:[]),projectSlot(h,project)].flatMap(slot=>{const f=path.join(slot,'events.jsonl');noLinks(f);return fs.existsSync(f)?fs.readFileSync(f,'utf8').trim().split('\n').filter(Boolean).map(JSON.parse):[];});}
export function runEvents(h,project,runId){
 const history=events(h,project);
 const start=history.findLastIndex(row=>row.kind==='workflow_begin'&&row.runId===runId);
 // Older events can lack runId. The enclosing workflow_begin identifies their run.
 return start<0?[]:history.slice(start).filter(row=>!row.runId||row.runId===runId);
}
export function projectState(h,project){const state=readJson(path.join(projectSlot(h,project),'workflow.json'))??(!portableContext()?readJson(path.join(legacyProjectSlot(h,project),'workflow.json')):null);return state&&portableContext()?{...state,project:fs.realpathSync(project)}:state;}
export function saveProject(h,project,value){atomic(path.join(projectSlot(h,project),'workflow.json'),json(value));}
