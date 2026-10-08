#!/usr/bin/env node
import { readFileSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const read=p=>readFileSync(resolve(root,p),'utf8');
const catalog=JSON.parse(read('catalogs/skill-catalog.json'));
const manifest=JSON.parse(read('harness/manifest.yaml'));
const errors=[];
const ids=['office-docx','office-pptx','office-xlsx','office-pdf'];
for(const id of ids){
 const path='skills/'+id+'/SKILL.md';
 if(!existsSync(resolve(root,path))){errors.push('missing '+path);continue}
 const text=read(path);
 if(!text.startsWith('---\nname: '+id+'\n')||!text.includes('description:')||!text.includes('Verify')&&!text.includes('verify')) errors.push('invalid SKILL.md '+id);
 const e=catalog.entries.filter(x=>x.id===id);
 if(e.length!==1||e[0].bundled_path!=='skills/'+id||e[0].source!=='hacker943410-debug/ai-harness') errors.push('bad catalog '+id);
 if(!manifest.payload_files.includes(path)) errors.push('missing payload '+id);
}
if(new Set(catalog.entries.map(e=>e.id)).size!==catalog.entries.length) errors.push('duplicate skill id');
console.log(JSON.stringify({pass:errors.length===0, checked:ids, errors},null,2));
if(errors.length)process.exitCode=1;
