#!/usr/bin/env node
// Reuse Phase2 verified bundle pipeline; overlay one user-facing entrypoint.
import fs from 'node:fs';
import path from 'node:path';
import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {hash,treeFiles,json} from './lib/io.mjs';
const core=path.dirname(fileURLToPath(import.meta.url));
const args=process.argv.slice(2);
function get(name){const i=args.indexOf('--'+name);return i>=0?args[i+1]:null}
const out=get('out'),node=get('node-binary'),codex=get('codex-binary');
if(!out||!node)throw Error('USAGE: --out NEW_DIRECTORY --node-binary PINNED_WINDOWS_NODE [--codex-binary PINNED_WINDOWS_CODEX]');
const target=path.resolve(out);
if(fs.existsSync(target))throw Error('OUTPUT_ALREADY_EXISTS');
const lock=JSON.parse(fs.readFileSync(path.join(core,'product/codex-lock.json'),'utf8'));
const officialCodex='9d563ee4e0441ff9d59d612013e0460ddf8e5709735c2d9f6b98b7ef8ca4eb42';
if(lock.sha256!==officialCodex||lock.release!=='rust-v0.166.0')throw Error('CODEX_LOCK_MISMATCH');
if(codex){
 const file=path.resolve(codex);
 if(fs.lstatSync(file).isSymbolicLink()||hash(fs.readFileSync(file))!==officialCodex)throw Error('OFFLINE_CODEX_BINARY_UNTRUSTED');
}
const build=spawnSync(process.execPath,[path.join(core,'build-windows-bootstrap.mjs'),'--out',target,'--node-binary',path.resolve(node)],{cwd:path.dirname(core),encoding:'utf8',timeout:120000});
if(build.status!==0)throw Error('BOOTSTRAP_BUILD_FAILED:'+build.stderr);
const source=path.join(core,'product/J_Harness_Install.cmd');
fs.copyFileSync(source,path.join(target,'J_Harness_Install.cmd'),fs.constants.COPYFILE_EXCL);
if(codex){fs.copyFileSync(codex,path.join(target,'vendor/codex.exe'),fs.constants.COPYFILE_EXCL);}
for(const name of ['J_Harness_Setup.cmd','J_Harness_Uninstall.cmd','Install-JHarness.cmd','Update-JHarness.cmd','Uninstall-JHarness.cmd','jh.cmd']){
 const f=path.join(target,name);if(fs.existsSync(f))fs.rmSync(f);
}
const notice=['J Harness v8 Integrated Installer CANDIDATE — Windows x64','',
 'Double-click J_Harness_Install.cmd. It diagnoses the PC and asks for INSTALL consent.',
 'Node v22.22.2 is pre-bundled. If Codex is absent, it downloads pinned OpenAI codex v0.166.0',
 'from the official OpenAI GitHub release (371,735,856 bytes), or uses a bundled verified offline copy.',
 'The user signs in to Codex interactively; J Harness never reads or creates login tokens.',
 'After installation, run %LOCALAPPDATA%\\JHarness-Bootstrap\\J_Harness_Start.cmd.',
 'Only the original Codex global instructions managed block is changed with approval.',
 'The product is advisory; OS-enforced user-only toggles and tamper resistance are NOT implemented.',
 'Unsigned distribution hashes detect damaged files but cannot authenticate publisher identity.',
 'Do not use in production or with sensitive projects until reviewed.',
 ''];
fs.writeFileSync(path.join(target,'START_HERE.txt'),notice.join('\r\n'));
const rows=treeFiles(target,new Set(['SHA256_MANIFEST.json']));
fs.writeFileSync(path.join(target,'SHA256_MANIFEST.json'),json({
 product:'J Harness Phase2 Portable Bootstrap',trust:'UNSIGNED_DRAFT_INTEGRATION_ARTIFACT',
 integration:'J_HARNESS_V8_FIRST_USABLE_BETA_CANDIDATE',
 nodeVersion:'v22.22.2',nodeSha256:'ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3',
 codexVersion:lock.release,codexSha256:officialCodex,offlineCodexBundled:!!codex,files:rows
}));
console.log(json({result:'INTEGRATED_WINDOWS_INSTALLER_BUILT_UNTRUSTED_UNSIGNED',output:target,files:rows.length,offlineCodexBundled:!!codex,testsPerformed:false}));
