#!/usr/bin/env node
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {hash,treeFiles,json} from './lib/io.mjs';

const core=path.dirname(fileURLToPath(import.meta.url));
const repo=path.resolve(core,'..');
const args=process.argv.slice(2);
function arg(key){const i=args.indexOf('--'+key);return i<0?null:args[i+1]}
const out=path.resolve(arg('out')||path.join(repo,'artifacts','jh-bootstrap-phase2'));
const nodeFile=arg('node-binary')&&path.resolve(arg('node-binary'));
const expected='ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3';
if(!nodeFile||!fs.existsSync(nodeFile))throw Error('PINNED_WINDOWS_NODE_BINARY_REQUIRED');
if(fs.lstatSync(nodeFile).isSymbolicLink())throw Error('NODE_BINARY_SYMLINK_REFUSED');
if(hash(fs.readFileSync(nodeFile))!==expected)throw Error('UNTRUSTED_WINDOWS_NODE_BINARY_SHA256');
if(fs.existsSync(out))throw Error('EXISTING_DIST_PRESERVED');
const built=spawnSync(process.execPath,[path.join(core,'build-package.mjs'),out],{cwd:repo,encoding:'utf8',timeout:120000});
if(built.status!==0)throw Error('CORE_PACKAGE_BUILD_FAILED:'+built.stderr);
fs.mkdirSync(path.join(out,'vendor'),{recursive:true});
fs.copyFileSync(nodeFile,path.join(out,'vendor/node.exe'),fs.constants.COPYFILE_EXCL);
for(const file of ['Bootstrap-JHarness.ps1','Uninstall-JHarness.ps1','bootstrap-manifest.json']){
 const source=path.join(core,'environment',file);
 const dest=path.join(out,'bootstrap',file);
 fs.mkdirSync(path.dirname(dest),{recursive:true});
 fs.copyFileSync(source,dest,fs.constants.COPYFILE_EXCL);
}
for(const file of ['J_Harness_Setup.cmd','J_Harness_Uninstall.cmd']){
 fs.copyFileSync(path.join(core,'environment',file),path.join(out,file),fs.constants.COPYFILE_EXCL);
}
// Distribution checksums are NOT publisher signatures.
const outputManifest=path.join(out,'SHA256_MANIFEST.json');
fs.writeFileSync(outputManifest,json({product:'J Harness Phase2 Portable Bootstrap',
 trust:'UNSIGNED_DRAFT_INTEGRATION_ARTIFACT',coreSource:'v8.0.0-core-beta.1 + Phase2 candidate',
 nodeVersion:'v22.22.2',nodeSha256:expected,
 files:treeFiles(out,new Set(['SHA256_MANIFEST.json']))}));
process.stdout.write(json({status:'PACKAGED_UNSIGNED_CANDIDATE',out,nodeVerified:true,
 files:treeFiles(out).length,fullyStandaloneExe:false,requiresCodex:true}));
