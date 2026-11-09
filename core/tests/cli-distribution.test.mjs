import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>fs.readFileSync(path.join(repo,p),'utf8');
test('CLI installer downloads immutable repository source and validates Node before building',()=>{
 const s=read('scripts/Install-JHarnessFromGitHub.ps1');
 assert.match(s,/325fd92475cf8586e09f32514f0cf3f212efdba5/);
 assert.match(s,/ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3/);
 assert.match(s,/Expand-Archive/);
 assert.match(s,/Get-FileHash/);
 assert.match(s,/build-integrated-product.mjs/);
 assert.match(s,/Install-JHarnessProduct.ps1/);
 assert.doesNotMatch(s,/Invoke-Expression|\biex\b|Set-ExecutionPolicy|New-LocalUser|Register-ScheduledTask/i);
});
test('CLI plan and explicit typed consent precede network and install',()=>{
 const s=read('scripts/Install-JHarnessFromGitHub.ps1');
 assert.ok(s.indexOf("if($Action -eq 'Plan')")>=0);
 assert.ok(s.indexOf("if($Action -eq 'Install' -and -not $ApproveInstall)")<s.indexOf('Invoke-WebRequest -Uri $archiveUrl'));
 assert.match(s,/Type INSTALL/);
 assert.match(s,/CANCELLED_NO_DOWNLOAD/);
 assert.match(s,/DESTINATION_ALREADY_EXISTS_PRESERVED/);
});
test('CLI alpha refuses to misrepresent OS security',()=>{
 const s=read('scripts/Install-JHarnessFromGitHub.ps1');
 assert.match(s,/supervisorEnforced=\$false/);
 assert.match(s,/credentialsChanged=\$false/);
 assert.match(s,/modelCalls=0/);
});
