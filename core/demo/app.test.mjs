import test from 'node:test';import assert from 'node:assert/strict';import fs from 'node:fs';import path from 'node:path';import os from 'node:os';import {once} from 'node:events';import {createApp,validateCustomer} from './server.mjs';
test('customer validation preserves input intent and normalizes email',()=>{assert.deepEqual(validateCustomer({name:' 민지 ',email:'A@Example.com',note:' 메모 '}),{name:'민지',email:'a@example.com',note:'메모'});assert.throws(()=>validateCustomer({name:'',email:'x'}));assert.throws(()=>validateCustomer({name:'x',email:'not-an-email'}));assert.throws(()=>validateCustomer({name:'x',email:'x@y.co',admin:true}));});
test('real HTTP CRUD, errors, persistence and local headers',async()=>{const dir=fs.mkdtempSync(path.join(os.tmpdir(),'jh-crm-test-'));let app=createApp(dir);await new Promise(resolve=>app.listen(0,'127.0.0.1',resolve));let base='http://127.0.0.1:'+app.address().port;const request=(url,method='GET',body,headers={})=>fetch(base+url,{method,headers:{'Content-Type':'application/json',...headers},...(body===undefined?{}:{body:typeof body==='string'?body:JSON.stringify(body)})});try{
 assert.deepEqual(await(await request('/api/customers')).json(),[]);
 let response=await request('/api/customers','POST',{name:'<script>alert(1)</script>',email:'One@Example.com',note:'합성 고객'});assert.equal(response.status,201);const customer=await response.json();
 assert.equal((await request('/api/customers','POST',{name:'중복',email:'one@example.com'})).status,409);
 assert.equal((await request('/api/customers','POST','{bad')).status,400);
 assert.equal((await request('/api/customers','POST',{name:'잘못됨',email:'x'})).status,400);
 assert.equal((await request('/api/customers','POST',{name:'외부',email:'a@b.co'},{Origin:'https://untrusted.invalid'})).status,403);
 response=await request('/api/customers/'+customer.id,'PUT',{name:'민지',email:'two@example.com',note:'수정'});assert.equal(response.status,200);
 assert.equal((await(await request('/api/customers?q='+encodeURIComponent('민지'))).json()).length,1);
 const page=await request('/');assert.equal(page.status,200);assert.match(page.headers.get('content-security-policy'),/script-src 'self'/);assert.match(await page.text(),/고객 노트/);
 assert.equal((await request('/customers.json')).status,404);
 await new Promise(resolve=>app.close(resolve));app=createApp(dir);await new Promise(resolve=>app.listen(0,'127.0.0.1',resolve));base='http://127.0.0.1:'+app.address().port;
 assert.equal((await(await request('/api/customers')).json())[0].name,'민지');assert.equal((await request('/api/customers/'+customer.id,'DELETE')).status,200);assert.deepEqual(await(await request('/api/customers')).json(),[]);assert.equal((await request('/api/customers/missing','DELETE')).status,404);
 }finally{await new Promise(resolve=>app.close(resolve));}});
