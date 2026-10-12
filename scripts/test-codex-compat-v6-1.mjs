import test from 'node:test';
import assert from 'node:assert/strict';
import {parseVersion, probe} from './check-codex-cli-v6-1.mjs';

test('detect stable and pre-release without inventing versions',()=>{
 assert.deepEqual(parseVersion('codex-cli 0.160.1'),{value:'0.160.1',prerelease:false});
 assert.deepEqual(parseVersion('codex-cli 0.162.0-alpha.3'),{value:'0.162.0-alpha.3',prerelease:true});
 assert.equal(parseVersion('invalid'),null);
});
test('no shell fallback or silent success for absent CLI',()=>{
 const result=probe('__missing_codex_test_binary__',['--version']);
 assert.equal(result.ok,false);
 assert.notEqual(result.error,null);
});
