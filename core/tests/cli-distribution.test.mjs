import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const repo=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
const read=p=>fs.readFileSync(path.join(repo,p),'utf8');
test('CLI installer downloads immutable repository source and validates Node before building',()=>{
 const s=read('scripts/Install-JHarnessProfileFromGitHub.ps1');
 assert.match(s,/a882c02f46905237e8fd843a7ca66c0ea1322fe3/);
 assert.match(s,/v8\.0\.0-alpha\.2-pinned-cli-preview/);
 assert.match(s,/ae1a50511be58e987483fdbc12125407443926d2d394669ade2352776e920dd3/);
 assert.match(s,/Expand-Archive/);
 assert.match(s,/Get-FileHash/);
 assert.match(s,/build-integrated-product.mjs/);
 assert.match(s,/Install-JHarnessProduct.ps1/);
 assert.doesNotMatch(s,/Invoke-Expression|\biex\b|Set-ExecutionPolicy|New-LocalUser|Register-ScheduledTask/i);
});
test('CLI plan and explicit typed consent precede network and install',()=>{
 const s=read('scripts/Install-JHarnessProfileFromGitHub.ps1');
 assert.ok(s.indexOf("if($Action -eq 'Plan')")>=0);
 assert.ok(s.indexOf("if($Action -eq 'Install' -and -not $ApproveInstall)")<s.indexOf('Invoke-WebRequest -Uri $archiveUrl'));
 assert.match(s,/Type INSTALL/);
 assert.match(s,/CANCELLED_NO_DOWNLOAD/);
 assert.match(s,/DESTINATION_ALREADY_EXISTS_PRESERVED/);
});
test('CLI alpha refuses to misrepresent OS security',()=>{
 const s=read('scripts/Install-JHarnessProfileFromGitHub.ps1');
 assert.match(s,/supervisorEnforced=\$false/);
 assert.match(s,/credentialsChanged=\$false/);
 assert.match(s,/modelCalls=0/);
});

test('default CLI pins portable v8 release and leaves profile bootstrap opt in',()=>{
 const s=read('scripts/Install-JHarnessFromGitHub.ps1');
 assert.match(s,/\[string\]\$Mode='Portable'/);
 const version=read('J_HARNESS_VERSION').trim();
 assert.ok(s.includes(`$productVersion='${version}'`));
 assert.ok(s.includes(`$coreVersion='${version}'`));
 assert.ok(s.includes(`$releaseTag='v${version}'`));
 assert.ok(s.includes(`$assetName='J_Harness_v${version}_Windows_x64.zip'`));
 assert.match(s,/\$expectedZipSha='[a-f0-9]{64}'/);
 assert.match(s,/V8_PACKAGE_SHA256_MISMATCH_NO_FALLBACK/);
 assert.match(s,/Install-JHarnessLocal\.ps1/);
 assert.match(s,/Install-JHarnessProfileFromGitHub\.ps1/);
 assert.match(s,/globalConnectionRequired=\$false/);
 assert.match(s,/systemNodeRequired=\$false/);
 assert.match(s,/systemGitRequired=\$false/);
 assert.doesNotMatch(s.replace(/^\s*#.*$/gm,''),/releases\/latest|Invoke-Expression|\biex\b|Set-ExecutionPolicy/i);
 const download=s.indexOf('Invoke-WebRequest -Uri $assetUrl');
 const plainPlan=s.indexOf("if($Action -eq 'Plan' -and -not $Upgrade)");
 const confirmation=s.indexOf("if($Action -in @('Install','Recover') -and -not $ApproveInstall)");
 assert.ok(plainPlan>=0&&plainPlan<download);
 assert.ok(confirmation>=0&&confirmation<download);
 assert.match(s,/if\(\$Upgrade\)\{\$arguments.Upgrade=\$true\}/);
});
