import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import {fileURLToPath} from 'node:url';

const clientGuides={
 codex:'https://learn.chatgpt.com/docs/codex/cli',
 claude:'https://code.claude.com/docs/en/quickstart',
 agy:'https://antigravity.google/docs/getting-started?tab=cli',
};
const clients=Object.keys(clientGuides);
const optionalProfiles={general:[],roblox:['rojo','stylua','selene']};
export const sha256=b=>crypto.createHash('sha256').update(b).digest('hex');

export function findExecutable(name,{envPath=process.env.PATH||'',platform=process.platform,separator=path.delimiter}={}){
  if(!/^[a-z][a-z0-9-]*$/.test(name))throw Error('INVALID_TOOL_NAME');
  const extensions=platform==='win32'?['.exe','.cmd','.bat','']:[''];
  for(const dir of envPath.split(separator).filter(Boolean)){
    const root=path.resolve(dir);
    try{
      if(!fs.statSync(root).isDirectory())continue;
    }catch{continue;/* inaccessible PATH entry */}
    for(const ext of extensions){
      const candidate=path.join(root,name+ext);
      // Discovery follows package-manager links without executing or trusting them.
      try{if(fs.statSync(candidate).isFile())return candidate;}
      catch{/* missing, broken or inaccessible candidate: try the next extension */}
    }
  }
  return null;
}

export function inspectEnvironment({client='codex',profile='general',platform=process.platform,
 nodeVersion=process.versions.node,envPath=process.env.PATH||'',separator=path.delimiter}={}){
 if(!clients.includes(client))throw Error('UNKNOWN_CLIENT: use codex, claude or agy');
 if(!Object.hasOwn(optionalProfiles,profile))throw Error('UNKNOWN_PROFILE: use general or roblox');
 const nodeOk=Number(String(nodeVersion).replace(/^v/,'').split('.')[0])>=22;
 const paths={};
 for(const name of ['git',client,...optionalProfiles[profile]])
  paths[name]=findExecutable(name,{envPath,platform,separator});
 const steps=[
  {id:'node',required:true,observed:nodeOk?'RUNNING_COMPATIBLE_NODE':'RUNTIME_MISSING_OR_OLD',action:nodeOk?'REUSE':'USE_PORTABLE_PACKAGE'},
  {id:client,required:true,observed:paths[client]?'FOUND_NOT_EXECUTED':'MISSING',action:paths[client]?'VERIFY_IN_SELECTED_CLI':'FOLLOW_OFFICIAL_INSTALL_GUIDE',path:paths[client]},
  {id:'git',required:false,observed:paths.git?'FOUND_NOT_EXECUTED':'MISSING_OPTIONAL',action:paths.git?'REUSE':'DEFER_UNTIL_SOURCE_WORK',path:paths.git},
  ...optionalProfiles[profile].map(id=>({id,required:false,observed:paths[id]?'FOUND_NOT_EXECUTED':'MISSING_OPTIONAL',action:paths[id]?'VERIFY_ON_USE':'INSTALL_PLAN_WHEN_PROJECT_NEEDS_IT',path:paths[id]}))
 ];
 if(profile==='roblox')steps.push({id:'roblox-studio',required:false,observed:'NOT_CHECKED',action:'GUI_SETUP_REQUIRES_USER_APPROVAL'});
 const blocked=steps.filter(x=>x.required&&/MISSING|OLD/.test(x.observed)).map(x=>x.id);
 return {product:'J Harness Environment Bootstrap',schema:1,stage:'READ_ONLY_SETUP_CHECK',
  state:blocked.length?'SETUP_REQUIRED':'DISCOVERED_UNVERIFIED',
  selectedClient:client,profile,nodeVersion:String(nodeVersion),platform,
  steps,blocked,unusedClients:clients.filter(x=>x!==client),
  evidence:{readonly:true,hostChanged:false,packageDownloaded:false,packageInstalled:false,
   authChanged:false,modelSessionVerified:false,supervisorEnforced:false},
  next:'Run JHarness.cmd environment plan for the selected CLI setup steps.'};
}
export function planEnvironment(inspect){
 if(inspect?.schema!==1||!Array.isArray(inspect.steps))throw Error('INVALID_INSPECTION');
 const {selectedClient:client,profile,blocked}=inspect;
 const installGuide=blocked.includes(client)?clientGuides[client]:null;
 const beginnerSteps=[];
 if(blocked.includes('node'))beginnerSteps.push('Windows에서는 Node가 포함된 J Harness 패키지의 .\\JHarness.cmd를 사용하세요.');
 if(installGuide){
  beginnerSteps.push(client+' 설치 안내 '+installGuide,
   '설치 후 프로젝트에서 새 터미널을 열고 .\\JHarness.cmd environment inspect --client '+client+' --profile '+profile+' 명령을 실행하세요.');
 }
 beginnerSteps.push(client+' --version으로 실행을 확인한 뒤, 프로젝트 폴더에서 '+client+'를 시작하세요.');
 return {schema:1,kind:'J_HARNESS_BOOTSTRAP_PLAN',state:blocked.length?'SETUP_REQUIRED':'PREREQUISITES_DISCOVERED',
  selectedClient:client,profile,
  actions:inspect.steps.map(x=>({component:x.id,decision:x.action,actualInstall:'NOT_RUN',approved:false})),
  beginnerSteps,installGuide,installation:'GUIDED_MANUAL',hostChanged:false,
  requiredNext:beginnerSteps[0]};
}

export function quickStart({projectBinding,client,guidance}){
 const selected=client??clients.find(name=>findExecutable(name))??'codex';
 const plan=planEnvironment(inspectEnvironment({client:selected}));
 if(projectBinding==='DIFFERENT_HARNESS')return '이 프로젝트에 다른 하네스 설정이 있습니다. 기존 설정을 확인한 뒤 이동형 설치기의 전환 안내를 따르세요.';
 if(projectBinding!=='BOUND_VERIFIED')return '이 폴더를 프로젝트로 쓰려면 .\\JHarness.cmd setup을 실행하세요. 다른 폴더에 설치하려면 패키지의 README.md를 여세요.';
 if(plan.state==='SETUP_REQUIRED')return [...plan.beginnerSteps,
  '설치 후 .\\JHarness.cmd quickstart --client '+selected+'를 다시 실행하세요.'].join('\n');
 if(guidance && guidance.agents!=='MANAGED_BLOCK_PRESENT')return '프로젝트의 AGENTS.md 지침을 확인하세요. .\\JHarness.cmd doctor에서 누락 여부를 확인할 수 있습니다.';
 if(selected==='codex' && guidance && guidance.codex.override!=='NONE')return 'Codex는 AGENTS.override.md를 먼저 확인합니다. 프로젝트의 기존 지침에 J Harness 연결이 포함되어 있는지 확인하세요. .\\JHarness.cmd doctor';
 if(selected==='claude' && guidance?.claude.state==='CONNECT_AVAILABLE')return [
  selected+' --version으로 실행을 확인하세요.',
  '이 프로젝트에서 Claude Code가 AGENTS.md를 읽도록 .\\JHarness.cmd connect claude를 실행하세요.',
  '이후 .\\JHarness.cmd quickstart --client claude를 다시 실행하세요.',
 ].join('\n');
 if(selected==='claude' && guidance?.claude.state==='REVIEW_REQUIRED')return '기존 CLAUDE.md를 확인하세요. .\\JHarness.cmd doctor로 지침 파일 상태를 확인할 수 있습니다.';
 return [plan.requiredNext,
  ...(selected==='codex' && guidance?.codex.exceedsDefaultGuidanceBudget?['AGENTS.md가 Codex 기본 지침 길이 한도(32 KiB)를 넘습니다. 세션에서 J Harness 안내가 로드됐는지 확인하세요.']:[]),
  ...(selected==='agy' && guidance?.agy.additionalGeminiGuidance==='PRESENT'?['이 프로젝트에 GEMINI.md도 있습니다. AGY 세션에서 AGENTS.md의 J Harness 안내가 로드됐는지 확인하세요.']:[]),
  '로그인이 필요하면 '+selected+'가 보여주는 안내를 따르세요.',
  '첫 요청 예시',
  '“이 폴더의 AGENTS.md와 J Harness 지침을 읽어줘. 간단한 할 일 목록 앱을 만들고 싶어. 필요한 환경부터 확인하고, 첫 기능을 만든 다음 테스트하고 실행법을 알려줘.”',
 ].join('\n');
}
function noLinks(target){
 for(let p=path.resolve(target);;p=path.dirname(p)){
  if(fs.existsSync(p)&&fs.lstatSync(p).isSymbolicLink())throw Error('SYMLINK_PATH_REFUSED');
  if(path.dirname(p)===p)break;
 }
}
// Offline preparation primitive only. Not a package installer, does not execute or configure.
export function stagePinnedLocalFile({source,expectedSha256,component,fileName,managedRoot,approved}={}){
 if(approved!==true)throw Error('EXPLICIT_APPROVAL_REQUIRED');
 if(!/^[a-z][a-z0-9-]*$/.test(component||'')||!/^[a-z0-9][a-z0-9._-]*$/i.test(fileName||''))
  throw Error('INVALID_COMPONENT_OR_FILENAME');
 if(!/^[a-f0-9]{64}$/.test(expectedSha256||''))throw Error('TRUSTED_SHA256_REQUIRED');
 if(!source||!managedRoot)throw Error('PATH_REQUIRED');
 const src=path.resolve(source),root=path.resolve(managedRoot),dst=path.join(root,component);
 noLinks(src);noLinks(root);noLinks(dst);
 if(!fs.statSync(src).isFile())throw Error('REGULAR_SOURCE_REQUIRED');
 if(fs.existsSync(dst))throw Error('EXISTING_COMPONENT_PRESERVED');
 if(sha256(fs.readFileSync(src))!==expectedSha256)throw Error('SOURCE_SHA256_MISMATCH');
 fs.mkdirSync(root,{recursive:true});
 const temporary=fs.mkdtempSync(path.join(root,'.jh-stage-'));
 try{
  const target=path.join(temporary,fileName);
  fs.copyFileSync(src,target,fs.constants.COPYFILE_EXCL);
  if(sha256(fs.readFileSync(target))!==expectedSha256)throw Error('STAGED_SHA256_MISMATCH');
  if(fs.existsSync(dst))throw Error('EXISTING_COMPONENT_PRESERVED');
  fs.renameSync(temporary,dst);
  return {status:'VERIFIED_STAGED_NOT_INSTALLED',path:path.join(dst,fileName),
   sha256:expectedSha256,executed:false,hostChanged:false};
 }catch(e){fs.rmSync(temporary,{recursive:true,force:true});throw e}
}
const own=process.argv[1]&&path.resolve(process.argv[1])===fileURLToPath(import.meta.url);
if(own){
 const [cmd='inspect',...args]=process.argv.slice(2);
 try{
  const get=(name,fallback)=>{const pos=args.indexOf('--'+name);return pos<0?fallback:args[pos+1]};
  if(!['inspect','plan'].includes(cmd)||args.some((a,i)=>i%2===0?!['--client','--profile'].includes(a):false))throw Error('ONLY_READONLY_INSPECT_OR_PLAN');
  const result=inspectEnvironment({client:get('client','codex'),profile:get('profile','general')});
  process.stdout.write(JSON.stringify(cmd==='plan'?planEnvironment(result):result,null,2)+'\n');
  if(cmd==='inspect'&&result.blocked.length)process.exitCode=3;
 }catch(e){process.stderr.write(JSON.stringify({state:'BLOCKED',reason:e.message})+'\n');process.exitCode=2}
}
