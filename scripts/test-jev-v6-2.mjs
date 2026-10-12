import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtempSync,mkdirSync,readFileSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {statusFor,makeShadowRequest,shadowFor,liveCanary,main} from './jev-runtime-v6-2.mjs';
import {evaluateJevDecision} from './jev-decision.mjs';

const route={intent:'development',risk:'R1',project_mode:'MAINTENANCE',
  tier:'balanced',context_profile:'MAINTENANCE_DELTA'};
const configured={decision_engine:{enabled:true,mode:'shadow',engine:'jev'}};

test('Jev stays off without credentials or explicit project activation',()=>{
 assert.equal(statusFor({},{}).status,'MISSING_API_KEY');
 assert.equal(statusFor({}, {AI_GATEWAY_API_KEY:'mock'}).status,'READY_NOT_ACTIVATED');
 assert.equal(statusFor(configured,{AI_GATEWAY_API_KEY:'mock'}).status,'SHADOW_READY');
});
test('shadow state is synthetic and never forwards user request or secret',()=>{
 const request=makeShadowRequest({...route,user_text:'SECRET PROMPT WITH PRIVATE DATA'}, {production:false});
 assert.equal(request.data_classification,'non_sensitive');
 assert.equal(request.existing_route,'balanced');
 assert.equal(JSON.stringify(request).includes('SECRET PROMPT'),false);
 assert.equal(makeShadowRequest({...route,risk:'R4'},{}),null);
 assert.equal(makeShadowRequest(route,{production:true}),null);
 assert.equal(makeShadowRequest({...route,intent:'harness_update'},{}),null);
});
test('shadow observes and cannot override deterministic tier',async()=>{
 const previous=process.env.AI_GATEWAY_API_KEY;
 try{
  process.env.AI_GATEWAY_API_KEY='offline-test-key';
  let calls=0;
  const result=await shadowFor(configured,route,{},async r=>{
   calls++;assert.equal(r.existing_route,'balanced');
   return {ok:true,answers:{tier:{type:'choice',choice:'economy'}},
    agreement:false,latency_ms:15,usage:{input_tokens:30,output_tokens:0,total_tokens:30,cost:0}};
  });
  assert.equal(calls,1);assert.equal(result.status,'SHADOW_OBSERVED');
  assert.equal(result.suggested_tier,'economy');
  assert.equal(result.deterministic_tier,'balanced');assert.equal(result.route_changed,false);
  assert.equal(route.tier,'balanced');
  const failed=await shadowFor(configured,route,{},async()=>({ok:false,error_type:'TIMEOUT'}));
  assert.equal(failed.status,'FALLBACK');assert.equal(failed.route_changed,false);
 }finally{if(previous===undefined)delete process.env.AI_GATEWAY_API_KEY;else process.env.AI_GATEWAY_API_KEY=previous;}
});
test('offline activate validates canary and never stores API key',async()=>{
 const dir=mkdtempSync(join(tmpdir(),'jev-test-'));
 const before=process.env.AI_GATEWAY_API_KEY;
 try{
  mkdirSync(join(dir,'.ai'));
  writeFileSync(join(dir,'.ai','harness-project.json'),JSON.stringify({
   harness:{root:dir,version:'6.0.0'},keep_this:'custom'
  }));
  process.env.AI_GATEWAY_API_KEY='do-not-write-this-test-secret';
  const blocked=await main(['activate','--project',dir,'--live','true'],
    async()=>({ok:false,error_type:'AUTHENTICATION_FAILED'}));
  assert.equal(blocked.activation,'BLOCKED');
  assert.equal(JSON.parse(readFileSync(join(dir,'.ai','harness-project.json'),'utf8')).decision_engine,undefined);
  const activated=await main(['activate','--project',dir,'--live','true'],
    async()=>({ok:true,agreement:true,latency_ms:12,usage:{input_tokens:5,output_tokens:0,total_tokens:5}}));
  assert.equal(activated.status,'ACTIVATED_SHADOW');
  const text=readFileSync(join(dir,'.ai','harness-project.json'),'utf8');
  assert.equal(text.includes('do-not-write-this-test-secret'),false);
  const conf=JSON.parse(text);
  assert.equal(conf.keep_this,'custom');
  assert.equal(conf.decision_engine.enabled,true);
  assert.equal(conf.decision_engine.mode,'shadow');
  const off=await main(['disable','--project',dir]);
  assert.equal(off.status,'DISABLED');
  assert.equal(JSON.parse(readFileSync(join(dir,'.ai','harness-project.json'),'utf8')).decision_engine.enabled,false);
 }finally{
  if(before===undefined)delete process.env.AI_GATEWAY_API_KEY;else process.env.AI_GATEWAY_API_KEY=before;
  rmSync(dir,{recursive:true,force:true});
 }
});
test('official v1 evaluate endpoint and request model are used, no raw payload logged',async()=>{
 const oldFetch=globalThis.fetch, oldKey=process.env.AI_GATEWAY_API_KEY;
 try{
  process.env.AI_GATEWAY_API_KEY='offline-test-key';
  let observed=false;
  globalThis.fetch=async(url,init)=>{
   observed=true;
   assert.equal(url,'https://ai-gateway.vercel.sh/v1/evaluate');
   assert.equal(init.method,'POST');
   assert.equal(init.headers.Authorization,'Bearer offline-test-key');
   assert.equal(init.headers['Content-Type'],'application/json');
   const request=JSON.parse(init.body);
   assert.equal(request.model,'typesafe-ai/jev');
   assert.equal(request.state,'synthetic state');
   assert.equal(request.questions.tier.type,'choice');
   return new Response(JSON.stringify({answers:{tier:{type:'choice',choice:'economy'}}}),
    {status:200,headers:{'Content-Type':'application/json'}});
  };
  const output=await evaluateJevDecision({
   decision_type:'task_route',data_classification:'non_sensitive',
   state:'synthetic state',existing_route:'economy',
   questions:{tier:{type:'choice',instructions:'Select lowest tier',
    criteria:{economy:'Simple',balanced:'Moderate',frontier:'Complex'}}}
  });
  assert.equal(observed,true);assert.equal(output.ok,true);
  assert.equal(output.agreement,true);
 }finally{
  globalThis.fetch=oldFetch;
  if(oldKey===undefined)delete process.env.AI_GATEWAY_API_KEY;else process.env.AI_GATEWAY_API_KEY=oldKey;
 }
});
