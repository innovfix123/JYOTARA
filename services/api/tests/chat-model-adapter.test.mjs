import assert from 'node:assert/strict';
import test from 'node:test';
import {moduleFor} from './helpers/load.mjs';
const {chatEditorModel,chatModelParameters,chatUsageMetadata}=await import(moduleFor('../lib/chat-model-adapter.ts'));

test('chat override is independent of the global feature model',()=>{
 assert.equal(chatEditorModel({OPENROUTER_MODEL:'google/gemini-2.5-flash',OPENROUTER_CHAT_MODEL:'openai/gpt-6.1-sol'}),'openai/gpt-6.1-sol');
 assert.equal(chatEditorModel({OPENROUTER_MODEL:'google/gemini-2.5-flash'}),'google/gemini-2.5-flash');
 assert.equal(chatEditorModel({}),'openai/gpt-6.1-sol');
});

test('reasoning requirements and sampling controls follow the model capabilities',()=>{
 const legacy=chatModelParameters('google/gemini-2.5-flash',1600);
 assert.deepEqual(legacy.reasoning,{enabled:false});assert.equal(legacy.temperature,0.2);assert.equal(legacy.response_format.type,'json_object');
 const flash=chatModelParameters('google/gemini-3.8-flash',5000);
 assert.deepEqual(flash.reasoning,{effort:'low'});assert.equal(flash.temperature,1);
 const gpt=chatModelParameters('openai/gpt-6.1-sol',5000,false);
 assert.equal(gpt.temperature,undefined);assert.equal(gpt.top_p,undefined);assert.deepEqual(gpt.reasoning,{effort:'low'});
 assert.deepEqual(gpt.response_format.json_schema.schema.required,['answer']);
});

test('missing cost and token metadata remain unknown rather than zero',()=>{
 assert.deepEqual(chatUsageMetadata({}),{});
 assert.deepEqual(chatUsageMetadata({usage:{cost:0,prompt_tokens:0,completion_tokens:0}}),{costUsd:0,promptTokens:0,completionTokens:0});
 assert.deepEqual(chatUsageMetadata({usage:{cost:-1,prompt_tokens:NaN,completion_tokens:Infinity}}),{});
});
