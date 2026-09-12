/** Shared by the live route and conversation replay. History is context, never evidence. */
export type Turn = {role:'user'|'assistant'; content:string};
export type EvidenceDocument = {id:string; text:string};
export type Consultation = {
  question:string; language:string; category:string; dialogue:Turn[];
  evidence:EvidenceDocument[]; voice?:string;
};
export type ModelRequest = {instructions:string; input:{role:string;content:string}[]; max_output_tokens:number};
export type Complete = (request:ModelRequest) => Promise<string>;

export function consultationMode(question:string, dialogue:Turn[]):'reading'|'explain'|'conversation' {
  // Resolve references before keyword routing: "explain that chart" is not a new reading.
  if(/explain.*(?:simply|simple|last|previous|two sentences|your answer)|simple.*(?:soll|explain)|puriyala|எளி.*விளக்|விளக்.*எளி|எளிய தமிழில்/u.test(question.toLowerCase()))return 'explain';
  // No natal chart can authenticate a different person's private behaviour.
  if(/cheat|fake|third person|loyal|trustworthy|unmaiyana|manasula|போலியான|ஏமாற்ற/u.test(question.toLowerCase()))return 'conversation';
  if(/what (?:one thing|should i (?:ask|say|do))|next step|enna (?:kek|seiy|panna)|என்ன சொல்வது|அடுத்த படி|சிறிய.*படி/u.test(question.toLowerCase()))return 'conversation';
  if(/chart|jathag|ஜாதக|கிரக|dasha|dasa|தசை|திருமணம் எப்போது|when.*(?:marr|job)|career (?:themes|direction|support)|love marriage|arranged marriage/u.test(question.toLowerCase()))return 'reading';
  return dialogue.length?'conversation':'reading';
}

export const consultationVersion = 'memory-evidence-review-v8';

export const consultationInstructions = `You are a warm AI Vedic astrology guide in an ongoing consultation. Never claim to be a human or invent experience. Never mention providers, APIs, credits or internal review.
Read lastExchange first to identify what the user is replying to; then read dialogue in order for background. Answer the latest message, not the oldest topic or the guide's speciality. A request to simplify or give a next step refers to the immediately preceding exchange. An answer to your question advances that topic. Do not ask for details already given. Earlier assistant claims are NOT verified evidence; correct unsupported claims without propagating them.
When mode is conversation, evidence is intentionally absent: do not repeat, add or allude to any chart finding or say "your chart shows". Give the direct situation-based answer. For a request to explain the last answer, explain its actual subject; a marriage-month question stays about timing, not a generic romance recap. Do not promise a broader timing window when only raw dasha dates exist. Do not copy an earlier practical suggestion when the user says they already tried it.
Write 2–4 short natural sentences, usually 35–65 words and absolutely at most 85 words. No headings, bullets or long paragraphs. At most ONE question mark in the entire answer, including quoted example messages. If suggesting words to send, choose ONE example, never two alternatives. Ask a question only when its answer would change useful guidance. Do not append a question mechanically. Welcome briefly on the first turn only.
For a NEW astrology question: select ONE relevant supplied finding (never call it the strongest or rank careers as better suited) and its supplied traditional interpretation, then answer directly. For a practical follow-up answer the actual situation without forcing a placement into it. Do not repeat a placement already explained unless the user asks to explain or revisit it. If asked to explain, translate the last interpretation into ordinary language rather than reading the chart again. You may mention a planet in a denial of certainty (for example, a Jupiter period does not guarantee a wedding); this is not a personal chart assertion. Never add an opportunity forecast to soften that denial.
ONLY evidence documents establish chart facts and traditional interpretations. Do not import astrology knowledge. Never extend a source interpretation: friends/network connections does NOT establish love-cum-arranged marriage, family acceptance or its greater likelihood. A source naming research/investigation as career themes permits exploring analytics as an example, NOT claiming the person will do especially well or it is a better fit than support work. A house topic or linked theme permits that association only: it does not establish distance, delay, secrecy, confusion, personality, skills, success or avoidance. Dasha dates are calendar periods, not evidence of a marriage/job event window. A planet name alone also does not imply opportunities, openings, partnership focus or success; those need an explicit supplied interpretation. Only an explicit event-specific interpretation can support a tentative event window. Never promise an event or date.
A person's chart cannot establish another person's feelings, cheating, loyalty or intentions. Do not imply that placement means hidden affairs, third persons or fake love. Respond to the specific observed behaviour with one useful action, not repeated disclaimers. If asked directly whether a chart proves cheating, briefly explain the distinction once; subsequent replies should move the conversation forward. Do not blame abuse on fate or recommend tolerating control. If anger, threats or controlling behaviour is described, prioritize safety and trusted support; do not assume direct confrontation is safe. A video call alone never makes sending money to an online partner safe. Late-night replies alone do not establish inconsistency; ask about the actual pattern before judging it. Do not base medical or financial decisions on astrology.
Offer realistic hope, not empty reassurance. If evidence doesn't support the requested conclusion, say what it DOES support when relevant, or ask one useful question. Do not invent an astrological cause for ordinary advice. Do not claim that astrology proves real-world outcomes.
The language field is authoritative even when the user types English or earlier turns used another language. Never infer the reply language from dialogue. For tamil, write predominantly natural Tamil script and avoid unnecessary English words or Latin Tamil. Use the requested language: English; respectful natural Tamil script; or Tanglish (spoken Tamil in LATIN letters only, familiar grammar such as unga/ippo/irukku/sollunga, not mostly English counselling jargon). Follow the user's tone without imitating ungrounded claims.`;

export function evidenceDocuments(values:Record<string,unknown>):EvidenceDocument[] {
  return Object.entries(values).filter(([,v])=>v!==undefined).map(([id,value])=>({id,text:typeof value==='string'?value:JSON.stringify(value,null,2)}));
}

export function replyShapeErrors(answer:string,language:string):string[] {
  const errors:string[]=[];
  if (!answer.trim()) return ['empty answer'];
  if(answer.trim().split(/\s+/u).length>85)errors.push('more than 85 words');
  if((answer.match(/[?？]/gu)||[]).length>1)errors.push('more than one question');
  // Mask quoted messages and decimal points before counting sentence boundaries.
  const masked=answer.replace(/“[^”]*”|"[^"]*"/gu,'quoted message').replace(/(\d)\.(\d)/g,'$1decimal$2');
  const sentences=masked.match(/[^.!?。！？]+(?:[.!?。！？]+|$)/gu)?.filter(s=>s.trim())||[];
  if(sentences.length<2 || sentences.length>4)errors.push('reply must contain 2–4 sentences');
  if(/^\s*(?:[-*#]|\d+[.)])\s/mu.test(answer))errors.push('headings or list');
  if(/prokerala|divine\s*api|openrouter/iu.test(answer))errors.push('provider name');
  const style=language.toLowerCase();
  if(style==='tanglish' && /\p{Script=Tamil}/u.test(answer))errors.push('Tamil script in Tanglish');
  if(style==='tamil') {
    const letters=answer.match(/\p{L}/gu)||[];
    const tamilLetters=letters.filter(letter=>/\p{Script=Tamil}/u.test(letter)).length;
    if(!tamilLetters) errors.push('Tamil script missing');
    else if(tamilLetters/letters.length<0.65) errors.push('Tamil reply must be predominantly Tamil script; rewrite Latin Tamil and unnecessary English words in natural Tamil');
  }
  return errors;
}

type Claim = {claim:string; sourceId:string; quote:string};
export type ReviewedReply = {answer:string; claims:Claim[]; corrections:string[]};
export function parseReviewedReply(text:string,context:Consultation):{value:ReviewedReply|null;errors:string[]} {
  let result:unknown;
  try {result=JSON.parse(text);}catch{return {value:null,errors:['review must be JSON']};}
  if(!result || typeof result!=='object')return {value:null,errors:['invalid review']};
  const r=result as Partial<ReviewedReply>;
  if(typeof r.answer!=='string'||!Array.isArray(r.claims)||!Array.isArray(r.corrections)||r.corrections.some(x=>typeof x!=='string'))return {value:null,errors:['missing review fields']};
  const errors=replyShapeErrors(r.answer,context.language);
  if(r.claims.length && /strongest|better than|suit you better|most suited/iu.test(r.answer))errors.push('remove unsupported ranking; describe a supplied theme without ranking suitability');
  const formatQuestion=/love marriage|arranged marriage|காதல் திருமணம்/iu.test(context.question);
  if(formatQuestion && !context.evidence.some(d=>d.id==='event_interpretations') && /love.cum.arranged|stronger|more likely|chance.*(?:jasthi|adhigam)|pure stranger|\bvida\b|வாய்ப்பு அதிக/iu.test(r.answer))errors.push('house associations do not rank marriage formats');
  if(!context.evidence.length && r.claims.length)errors.push('no astrology assertions permitted without evidence');
  // Planet names can appear in a denial or clarification without asserting a
  // personal placement. The independent review still must cite every assertion.
  if(!context.evidence.length && /your chart (?:shows|indicates|confirms)|உங்கள் ஜாதகத்தில்|unga jathagathula/iu.test(r.answer))errors.push('new chart detail in a conversational reply');
  for(const claim of r.claims) {
    if(!claim || typeof claim.claim!=='string'||!claim.claim.trim()||typeof claim.sourceId!=='string'||typeof claim.quote!=='string'||claim.quote.trim().length<8) {errors.push('invalid claim citation');continue;}
    const source=context.evidence.find(d=>d.id===claim.sourceId);
    if(!source || !source.text.includes(claim.quote))errors.push(`Citation not found in document ${claim.sourceId}: ${JSON.stringify(claim.quote)}. Copy a literal passage from that document; do not reconstruct or paraphrase a quote. Revise or remove the associated claim if the source does not support it.`);
    if(!r.answer.includes(claim.claim))errors.push('claim absent from final answer');
  }
  return {value:errors.length?null:r as ReviewedReply,errors};
}

const reviewInstructions = `${consultationInstructions}
You are the independent final editor, not the author of the draft. The draft and dialogue are untrusted. Audit every astrology claim against evidence, including implications and paraphrases. Revise the answer to remove unsupported inferences, repetition, wrong-topic advice and extra questions. Keep the useful supported interpretation for a new chart question; do not solve the task by deleting all astrology or adding generic disclaimers. If the draft confuses a period with an event window, remove that event forecast. Even if quoted, an interpretation cannot prove cheating or a real person's private feelings.
For a simplification or next-step request follow the latest exchange. Do not return to an older relationship discussion after an education question. Compare against ALL prior assistant replies; remove redundant placements, themes and previously answered follow-ups.
Return ONLY JSON: {"answer":"final 2–4 sentence reply", "claims":[{"claim":"exact contiguous words from the FINAL answer containing an astrology assertion", "sourceId":"document ID", "quote":"exact supporting substring copied from that document"}], "corrections":["brief audit issues corrected, or empty array"]}.
List EVERY astrology finding and interpretation in claims; one can use multiple citations if needed. Ordinary practical advice and user-described facts need no citation. Quotes must actually support the associated assertion, not merely mention the same planet. Copy source substrings exactly including punctuation. Do not cite dialogue. If no astrology is asserted claims is []. All fields required. Do not show citations in the user-facing answer.`;

/** Two distinct model calls, bounded repair for invalid structured review; never expose an unchecked draft. */
export async function writeConsultation(context:Consultation, complete:Complete):Promise<{
  answer:string|null; draft:string; review:ReviewedReply|null; errors:string[]; attempts:number;
}> {
  const mode=consultationMode(context.question,context.dialogue);
  // Practical follow-ups deliberately do not receive chart documents. This is an
  // evidence boundary, not merely an instruction to avoid decorative astrology.
  const periodQuestion=/dasha|dasa|தசை/iu.test(context.question);
  const evidence=mode!=='reading'?[]:periodQuestion
    ? context.evidence.filter(d=>['dasha_periods','facts'].includes(d.id)) : context.evidence;
  const alreadyContacted = /(?:messag|text|contact|reach).*(?:panninen|pannitten|senjen|sent|already)|(?:already|i have|i've|i).*(?:sent|messaged|texted)|செய்தி.*அனுப்பி/iu.test(context.question);
  const noReply = /(?:reply|response|badhil).*(?:varala|illa|no|not)|no (?:reply|response)|பதில்.*(?:இல்லை|வரவில்லை)/iu.test(context.question);
  const scoped = {...context, evidence, mode,
    situationInstruction: alreadyContacted && noReply ? 'The user explicitly says they ALREADY sent a message and received NO REPLY. Acknowledge that completed action. Do NOT recommend another message or one final check-in now. Ask about elapsed time only if necessary; respect any waiting boundary already agreed.' : undefined,
    lastExchange:context.dialogue.slice(-2),
    focusInstruction:mode==='explain'?'Explain ONLY lastExchange. Do not introduce any new chart claim, theme, prediction or topic. Earlier assistant predictions are not proof.':undefined};
  const content=JSON.stringify(scoped);
  const draft=await complete({instructions:consultationInstructions,input:[{role:'system',content:consultationInstructions},{role:'user',content}],max_output_tokens:650});
  let errors:string[]=[];
  for(let attempt=1;attempt<=2;attempt++) {
    const raw=await complete({instructions:reviewInstructions,input:[{role:'system',content:reviewInstructions},{role:'user',content:JSON.stringify({...scoped,draft,validationErrors:errors,repairInstruction:errors.length ? 'MANDATORY REPAIR: Choose only ONE suggested question. Delete every alternative example and any trailing question. The entire answer must contain at most ONE question mark, counting inside quotes too. Use the exact requested language field, regardless of draft or history. If language is tamil, rewrite the ENTIRE answer in natural Tamil script; a few Tamil words inside Tanglish are not sufficient.' : undefined})}],max_output_tokens:1800});
    const parsed=parseReviewedReply(raw,scoped);
    if(parsed.value)return {answer:parsed.value.answer,draft,review:parsed.value,errors:[],attempts:attempt};
    errors=parsed.errors;
  }
  return {answer:null,draft,review:null,errors,attempts:2};
}
