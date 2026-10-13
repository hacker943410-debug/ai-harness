#!/usr/bin/env node
/** Explicit, no-overwrite Roblox scaffold. No auto-install, no Studio mutation. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const source=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../templates/roblox-game');
export function scaffoldProject(destination,{create=false}={}){
 if(typeof destination!=='string'||!destination.trim())throw Error('DESTINATION_REQUIRED');
 const target=path.resolve(destination);
 if(!create)return {status:'DRY_RUN',target,template:source,files:fs.readdirSync(source).length};
 if(fs.existsSync(target)){
  if(fs.lstatSync(target).isSymbolicLink())throw Error('DESTINATION_SYMLINK_REFUSED');
  if(!fs.statSync(target).isDirectory()||fs.readdirSync(target).length)throw Error('DESTINATION_NOT_EMPTY');
 } else {
  const parent=path.dirname(target);
  if(!fs.existsSync(parent)||!fs.statSync(parent).isDirectory())throw Error('PARENT_DIRECTORY_MISSING');
 }
 for(const rel of fs.readdirSync(source,{recursive:true})){
  const f=path.join(source,rel);
  if(fs.lstatSync(f).isSymbolicLink())throw Error('TEMPLATE_SYMLINK_REFUSED');
 }
 fs.cpSync(source,target,{recursive:true,errorOnExist:true,force:false});
 return {status:'SCAFFOLDED',target,source:'bundled-template',package_install:'NOT_RUN',
  studio_mutation:'NOT_RUN'};
}
if(process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url)){
 if(![4,5].includes(process.argv.length)||process.argv[2]!=='--out'||(process.argv.length===5&&process.argv[4]!=='--create'))
  throw Error('Usage: node scaffold.mjs --out DESTINATION [--create]');
 const result=scaffoldProject(process.argv[3],{create:process.argv[4]==='--create'});process.stdout.write(JSON.stringify(result,null,2)+'\n');
}
