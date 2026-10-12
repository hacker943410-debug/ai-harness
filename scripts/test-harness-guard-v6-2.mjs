import test from 'node:test';
import assert from 'node:assert/strict';
import {extractUsage,budgetDecision,summarizeJsonl,main} from './harness-guard-v6-2.mjs';

test('provider completed-turn event is required for actual usage',()=>{
 assert.equal(extractUsage({type:'item.completed',usage:{input_tokens:42,output_tokens:8}}),null);
 assert.equal(extractUsage({type:'turn.completed',usage:{input_tokens:42}}),null);
 assert.deepEqual(extractUsage({type:'turn.completed',usage:{input_tokens:42,output_tokens:8,cached_input_tokens:11}}),
  {input_tokens:42,output_tokens:8,cached_input_tokens:11,total_tokens:50});
});
test('budget thresholds are real and never invent usage',()=>{
 assert.equal(budgetDecision(null,80,100).action,'UNKNOWN');
 assert.equal(budgetDecision(70,undefined,undefined).action,'UNCONFIGURED');
 assert.equal(budgetDecision(70,80,100).action,'CONTINUE');
 assert.equal(budgetDecision(80,80,100).action,'COMPACT_NEXT_TURN');
 assert.equal(budgetDecision(100,80,100).action,'CHECKPOINT_REQUIRED');
});
test('JSONL combines completed turns without counting cached tokens twice',()=>{
 const r=summarizeJsonl([
  JSON.stringify({type:'thread.started',thread_id:'abc'}),
  JSON.stringify({type:'turn.completed',usage:{input_tokens:40,output_tokens:9,cached_input_tokens:20}}),
  JSON.stringify({type:'turn.completed',usage:{input_tokens:6,output_tokens:3}}),
  'not-json'].join('\n'));
 assert.equal(r.turns,2);assert.equal(r.usage_events,2);assert.equal(r.parse_errors,1);
 assert.equal(r.actual_usage.total_tokens,58);assert.equal(r.actual_usage.cached_input_tokens,20);
});
test('invalid project fails before running Codex',async()=>{
 await assert.rejects(main(['preflight','--project','/not-real-harness-project','--request','fix']),/ENOENT/);
});
