import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {copyTree,noLinks,json,fileHash} from '../lib/io.mjs';
import {buildManifest} from './lib/portable-context.mjs';

const portable=path.dirname(fileURLToPath(import.meta.url));
const core=path.dirname(portable), repository=path.dirname(core);
const nodeHash='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3';
const licenseHash='c738ae413cf561f174e34f6961f8ca458aae2369a73640dda6234c629b98bcc4';

// Only create a new directory. A failed build is retained for diagnosis.
export function materializeRuntime(out,{nodeBinary,nodeLicense}={}) {
  out=path.resolve(out);noLinks(out);
  if(fs.existsSync(out)||out===core||out.startsWith(core+path.sep))throw Error('NEW_OUTPUT_OUTSIDE_CORE_REQUIRED');
  if(Boolean(nodeBinary)!==Boolean(nodeLicense))throw Error('NODE_BINARY_AND_LICENSE_REQUIRED_TOGETHER');
  if(nodeBinary){
    noLinks(nodeBinary);noLinks(nodeLicense);
    if(fileHash(nodeBinary)!==nodeHash||fileHash(nodeLicense)!==licenseHash)throw Error('UNTRUSTED_NODE_DISTRIBUTION');
  }
  fs.mkdirSync(out,{recursive:true});
  const target=path.join(out,'runtime/core');
  for(const name of ['lib','knowledge','skills'])copyTree(path.join(core,name),path.join(target,name));
  fs.mkdirSync(path.join(target,'environment'),{recursive:true});
  fs.copyFileSync(path.join(core,'environment/doctor.mjs'),path.join(target,'environment/doctor.mjs'));
  for(const name of ['cli.mjs','package.json'])fs.copyFileSync(path.join(core,name),path.join(target,name));
  copyTree(path.join(repository,'policies'),path.join(out,'runtime/policies'));
  fs.mkdirSync(path.join(out,'runtime/knowledge'),{recursive:true});
  for(const name of ['beginner-mode.md','briefing-protocol.md','project-mode-router.md','verification-profiles.md','token-policy.md'])fs.copyFileSync(path.join(repository,'harness/runtime',name),path.join(out,'runtime/knowledge',name));
  fs.copyFileSync(path.join(repository,'workflows/CAPABILITY_ACQUISITION.md'),path.join(out,'runtime/knowledge/CAPABILITY_ACQUISITION.md'));
  copyTree(path.join(repository,'skills/dashboard-builder'),path.join(out,'runtime/skills/dashboard-builder'));
  copyTree(path.join(portable,'lib'),path.join(out,'lib'));
  for(const name of ['portable.mjs','setup.mjs','upgrade.mjs','PORTABLE.md'])fs.copyFileSync(path.join(portable,name),path.join(out,name));
  fs.copyFileSync(path.join(repository,'LICENSE'),path.join(out,'LICENSE'));
  if(nodeBinary){
    fs.mkdirSync(path.join(out,'vendor/win-x64'),{recursive:true});
    fs.copyFileSync(nodeBinary,path.join(out,'vendor/win-x64/node.exe'));
    fs.copyFileSync(nodeLicense,path.join(out,'vendor/win-x64/LICENSE'));
  }
  const manifest=buildManifest(out);
  const distribution=path.join(repository,'J_HARNESS_VERSION');
  if(fs.existsSync(distribution))manifest.distributionVersion=fs.readFileSync(distribution,'utf8').trim();
  fs.writeFileSync(path.join(out,'manifest.json'),json(manifest),{flag:'wx'});
  return manifest;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
  if(!process.argv[2])throw Error('OUTPUT_REQUIRED');
  const manifest=materializeRuntime(process.argv[2],{nodeBinary:process.argv[3],nodeLicense:process.argv[4]});
  console.log(json({version:manifest.version,distributionVersion:manifest.distributionVersion,files:manifest.files.length}));
}
