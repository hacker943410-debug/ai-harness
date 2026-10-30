import fs from 'node:fs';import path from 'node:path';import {spawnSync} from 'node:child_process';
export function resolveCodex(env=process.env){
 for(const directory of (env.PATH??env.Path??'').split(path.delimiter).filter(Boolean)){
  const native=path.join(directory,process.platform==='win32'?'codex.exe':'codex');if(fs.existsSync(native)&&fs.statSync(native).isFile())return{file:native,prefix:[]};
  const js=path.join(directory,'node_modules/@openai/codex/bin/codex.js');if(fs.existsSync(js))return{file:process.execPath,prefix:[js]};
 }
 return null;
}
export function codexVersion({codexHome}={}){const c=resolveCodex();if(!c)return{installed:false,version:null};const env=codexHome?{...process.env,CODEX_HOME:codexHome}:process.env;const result=spawnSync(c.file,[...c.prefix,'--version'],{env,encoding:'utf8',windowsHide:true,timeout:10000});return{installed:result.status===0,version:result.status===0?result.stdout.trim():null,execution:c};}
export function selectedGlobal(h){for(const name of ['AGENTS.override.md','AGENTS.md']){const file=path.join(h,name);if(fs.existsSync(file)&&fs.readFileSync(file,'utf8').trim().length>0)return file;}return path.join(h,'AGENTS.md');}
