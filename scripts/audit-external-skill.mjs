#!/usr/bin/env node
/**
 * Read-only, heuristic external Skill preflight. Never imports or runs Skill code.
 * It blocks obvious runtime download/auto-update instructions, but a clean report
 * is NOT a security attestation: manual inspection and policy approval remain required.
 */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const scannedExtensions = new Set(['.md','.mdx','.js','.cjs','.mjs','.ts','.py','.ps1','.sh','.bash','.zsh','.bat','.cmd','.json','.yaml','.yml','.toml']);
const maxFiles = 500;
const maxBytesPerFile = 1024 * 1024;

export const rules = [
  {id:'DYNAMIC_NPX_EXEC',severity:'BLOCK',regex:/\bnpx\s+(?:-y|--yes)\b/i},
  {id:'DYNAMIC_NPX_PACKAGE',severity:'BLOCK',regex:/\bnpx\b[^\n]*@(?:latest|0)(?:\b|$)/i},
  {id:'FETCH_AND_EXECUTE',severity:'BLOCK',regex:/(?:\bcurl\b|\bwget\b)[^\n]*\|\s*(?:ba)?sh\b/i},
  {id:'POWERSHELL_REMOTE_EVAL',severity:'BLOCK',regex:/(?:invoke-webrequest|\biwr\b|\birm\b)[^\n]*\|\s*(?:invoke-expression|\biex\b)/i},
  {id:'GLOBAL_PACKAGE_INSTALL',severity:'BLOCK',regex:/\b(?:npm\s+install\s+(?:-g|--global)|pip\s+install\s+(?:-U|--upgrade))\b/i},
  {id:'AUTO_UPDATE_INSTRUCTIONS',severity:'BLOCK',regex:/\bnpx\b[^\n]*\bupdate\b|\bnpm\s+update\b/i},
  {id:'REMOTE_PROVIDER_REVIEW',severity:'REVIEW',regex:/cross_model_review_mode|cross.model.{0,20}(?:peer|review)|(?:second|different)\s+(?:model\s+)?provider/i},
  {id:'EXTERNAL_PROXY_REFERENCE',severity:'REVIEW',regex:/k-skill-proxy|proxy_base_url|hosted\s+proxy/i},
  {id:'POTENTIAL_NETWORK_ACTION',severity:'REVIEW',regex:/\b(?:curl|wget|git\s+clone)\b|invoke-restmethod|invoke-webrequest/i}
];

function relative(root,full){return path.relative(root,full).split(path.sep).join('/');}
export function auditExternalSkill(source) {
  const root = path.resolve(source);
  const stat = fs.lstatSync(root);
  if(!stat.isDirectory() || stat.isSymbolicLink())throw Error('INVALID_SKILL_DIRECTORY');
  if(!fs.existsSync(path.join(root,'SKILL.md')))throw Error('SKILL_MD_REQUIRED');
  const findings=[], stack=[root];
  let files=0;
  while(stack.length){
    const directory=stack.pop();
    for(const entry of fs.readdirSync(directory,{withFileTypes:true})){
      const full=path.join(directory,entry.name);
      const info=fs.lstatSync(full);
      if(info.isSymbolicLink())throw Error('SYMLINK_IN_SKILL: '+relative(root,full));
      if(info.isDirectory()){stack.push(full);continue;}
      if(!info.isFile())throw Error('UNSUPPORTED_SKILL_ENTRY: '+relative(root,full));
      files++;
      if(files>maxFiles)throw Error('SKILL_FILE_COUNT_LIMIT');
      if(info.size>maxBytesPerFile)throw Error('SKILL_FILE_SIZE_LIMIT: '+relative(root,full));
      if(!scannedExtensions.has(path.extname(entry.name).toLowerCase()))continue;
      const lines=fs.readFileSync(full,'utf8').split(/\r?\n/);
      for(let i=0;i<lines.length;i++){
        for(const rule of rules){
          if(rule.regex.test(lines[i])){
            // Never emit raw lines because they may contain sensitive content.
            findings.push({file:relative(root,full),line:i+1,id:rule.id,severity:rule.severity});
          }
        }
      }
    }
  }
  findings.sort((a,b)=>a.file.localeCompare(b.file)||a.line-b.line||a.id.localeCompare(b.id));
  return {
    schema_version:'1.0',status:findings.some(f=>f.severity==='BLOCK')?'BLOCKED':'MANUAL_REVIEW_REQUIRED',
    files_checked:files,findings,
    note:'Heuristic only: even no findings cannot approve a Skill. Verify source commit, dependencies, egress, credentials, transitive code and licenses before installation.'
  };
}

const invoked = process.argv[1] && path.resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(invoked){
  const args=process.argv.slice(2);
  if(args.length!==2||args[0]!=='--source'){process.stderr.write('Usage: node scripts/audit-external-skill.mjs --source PATH\n');process.exitCode=3;}
  else try{
    const report=auditExternalSkill(args[1]);
    process.stdout.write(JSON.stringify(report,null,2)+'\n');
    if(report.status==='BLOCKED')process.exitCode=2;
  }catch(err){process.stderr.write('EXTERNAL_SKILL_AUDIT_ERROR: '+err.message+'\n');process.exitCode=3;}
}
