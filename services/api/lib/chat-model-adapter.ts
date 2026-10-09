/** Only chat editors use this setting. Other feature models remain independent. */
export const DEFAULT_CHAT_EDITOR_MODEL = 'google/gemini-3.8-flash';

export function chatEditorModel(config:{OPENROUTER_CHAT_MODEL?:string;OPENROUTER_MODEL?:string}):string {
  return config.OPENROUTER_CHAT_MODEL || config.OPENROUTER_MODEL || DEFAULT_CHAT_EDITOR_MODEL;
}

/** Model capabilities were checked against the public OpenRouter catalog.
 * New reasoning models cannot inherit Gemini 2.5's disabled-thinking settings. */
export function chatModelParameters(model:string,maxTokens:number,sourceQuotes=true) {
  const openaiReasoning=/^openai\/gpt-(?:5|6)(?:[.-]|$)/i.test(model);
  const newGemini=/^google\/gemini-3(?:[.-]|$)/i.test(model);
  const schema={type:'object',properties:{answer:{type:'string'},...(sourceQuotes?{source_quotes:{type:'array',items:{type:'string'}}}:{})},required:['answer',...(sourceQuotes?['source_quotes']:[])],additionalProperties:false};
  return {
    model,
    max_tokens:maxTokens,
    ...(openaiReasoning ? {
      reasoning:{effort:'low'},
      response_format:{type:'json_schema',json_schema:{name:sourceQuotes?'grounded_chat_edit':'general_chat_guidance',strict:true,schema}},
    } : {
      temperature:newGemini?1:0.2,
      reasoning:newGemini?{effort:'low'}:{enabled:false},
      response_format:{type:'json_object'},
    }),
  };
}

export type ProviderResponseMetadata = {
  id?:string; model?:string;
  usage?:{cost?:number;prompt_tokens?:number;completion_tokens?:number;completion_tokens_details?:{reasoning_tokens?:number};prompt_tokens_details?:{cached_tokens?:number}};
};

/** Missing provider usage stays missing; it must never be counted as zero. */
export function chatUsageMetadata(response:ProviderResponseMetadata) {
  const number=(value:unknown)=>typeof value==='number'&&Number.isFinite(value)&&value>=0?value:undefined;
  const costUsd=number(response.usage?.cost),promptTokens=number(response.usage?.prompt_tokens),completionTokens=number(response.usage?.completion_tokens),reasoningTokens=number(response.usage?.completion_tokens_details?.reasoning_tokens),cachedTokens=number(response.usage?.prompt_tokens_details?.cached_tokens);
  return {
    ...(costUsd!==undefined?{costUsd}:{}),
    ...(promptTokens!==undefined?{promptTokens}:{}),
    ...(completionTokens!==undefined?{completionTokens}:{}),
    ...(reasoningTokens!==undefined?{reasoningTokens}:{}),
    ...(cachedTokens!==undefined?{cachedTokens}:{}),
    ...(typeof response.id==='string'&&response.id.length<=200?{generationId:response.id}:{}),
    ...(typeof response.model==='string'&&response.model.length<=160?{returnedModel:response.model}:{}),
  };
}
