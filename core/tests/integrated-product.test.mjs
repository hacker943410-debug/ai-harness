import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const load=p=>fs.readFileSync(path.join(root,p),'utf8');
test('Codex vendor lock is explicit, pinned and restricted to Windows x64',()=>{
 const lock=JSON.parse(load('core/product/codex-lock.json'));
 assert.equal(lock.sha256,'9d563ee4e0441ff9d59d612013e0460ddf8e5709735c2d9f6b98b7ef8ca4eb42');
 assert.equal(lock.size,371735856);
 assert.equal(lock.url,'https://github.com/openai/codex/releases/download/rust-v0.166.0/codex-x86_64-pc-windows-msvc.exe');
 assert.equal(lock.platform,'Windows x64');
});
test('installer is a single explicit consent entry, no automatic privilege elevation',()=>{
 const c=load('core/product/J_Harness_Install.cmd');
 assert.match(c,/Type INSTALL/);
 assert.match(c,/\-Action Plan/);
 assert.match(c,/\-Action Install \-ApproveInstall/);
 assert.doesNotMatch(c,/(?:runas|Start-Process\s+-Verb\s+RunAs|sc\.exe\s+create|net\s+user)/i);
});
test('installed launcher does not need globally installed Node or second CLI',()=>{
 const script=load('core/product/Installed-JHarness.ps1');
 assert.match(script,/node-v22\.22\.2/);
 assert.match(script,/\$env:Path=.*\$node/);
 assert.match(script,/\& \$cli/);
 assert.match(script,/ADVISORY_NOT_OS_ENFORCED/);
});
test('installer requires consent and verifies binary digest before executing it',()=>{
 const script=load('core/product/Install-JHarnessProduct.ps1');
 assert.match(script,/if\(-not \$ApproveInstall\)/);
 assert.match(script,/Match-Hash \$tmpFile \$expectedCodex/);
 assert.match(script,/CORE_BOOTSTRAP_FAILED_OR_ROLLED_BACK/);
 assert.match(script,/USER_LOCALAPPDATA_REQUIRED/);
});
test('builder emits one entry point and removes confusing competitors',()=>{
 const b=load('core/build-integrated-product.mjs');
 assert.match(b,/J_Harness_Install\.cmd/);
 assert.match(b,/SHA256_MANIFEST\.json/);
 assert.match(b,/J_Harness_Setup\.cmd/);
 assert.match(b,/OFFLINE_CODEX_BINARY_UNTRUSTED/);
});
test('product scripts do not alter persistent OS settings or create accounts',()=>{
 const scripts=['core/product/Install-JHarnessProduct.ps1','core/product/Installed-JHarness.ps1'].map(load);
 for(const s of scripts){
   assert.doesNotMatch(s,/SetEnvironmentVariable\([^)]*User|SetEnvironmentVariable\([^)]*Machine|Set-ItemProperty\s+.*HKCU:|Set-ItemProperty\s+.*HKLM:|New-LocalUser|New-Service|sc\.exe\s+create/i);
 }
});
