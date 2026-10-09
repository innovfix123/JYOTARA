import {normalizeUserMessageBatch} from './guidance-language';

type LocalTurn = 'brief' | 'thanks' | 'goodbye';
type Input = {question?:unknown;userMessageBatch?:unknown;responseMode?:unknown;style?:unknown};

// Exact whole-message matches only. A question, factual answer, correction or
// other substantive text must follow the ordinary validated reading path.
const phrases:Record<LocalTurn,readonly string[]>={
  brief:[
    'please keep it brief','keep it brief','pleasekeepitbrief','please keep it short','keep it short',
    'please keep the answer brief','keep the answer brief','please keep your replies brief','keep your replies brief',
    'please keep replies short','keep replies short','please keep answers short','keep answers short',
    'short answer please','short answers please','brief replies please','please answer briefly','answer briefly',
    'please be concise','be concise',"don't explain in detail",'do not explain in detail','dont explain in detail','no detailed explanation please',
    'சுருக்கமாக சொல்லுங்கள்','சுருக்கமாகச் சொல்லுங்கள்','சுருக்கமாக பதில் சொல்லுங்கள்','சுருக்கமாகப் பதில் சொல்லுங்கள்',
    'சுருக்கமா சொல்லுங்க','பதில் சுருக்கமாக இருக்கட்டும்','விரிவாக வேண்டாம்','விரிவாக விளக்க வேண்டாம்',
    'surukkama sollunga','surukkamaa sollunga','konjam surukkama sollunga','please surukkama sollunga',
    'short-a sollunga','short ah sollunga','brief-a sollunga','brief ah sollunga','detaila vendaam','detaila solla vendaam',
  ],
  thanks:[
    'thanks','thank you','thank you very much','many thanks','thanks a lot','okay thank you','ok thank you',
    'நன்றி','மிக்க நன்றி','ரொம்ப நன்றி','nandri','mikka nandri','romba nandri',
  ],
  goodbye:[
    'bye','goodbye','bye for now','see you later',"that's all for now",'that is all for now',
    'பிறகு பேசலாம்','பிறகு பார்க்கலாம்','இப்போது போகிறேன்','போய் வருகிறேன்','விடைபெறுகிறேன்',
    'appuram pesalaam','piragu pesalaam','poitu varen',
  ],
};
const exactPhrases=new Map<string,LocalTurn>(Object.entries(phrases).flatMap(([kind,values])=>values.map(value=>[value,kind as LocalTurn])));
const replies={
  english:{brief:'Sure, I’ll keep replies brief.',thanks:'You’re welcome.',goodbye:'Take care. Bye for now.'},
  tamil:{brief:'சரி, சுருக்கமாகப் பதில் சொல்கிறேன்.',thanks:'மகிழ்ச்சி.',goodbye:'நலமாக இருங்கள். பிறகு பேசலாம்.'},
  tanglish:{brief:'Sari, surukkama badhil solren.',thanks:'Magizhchi.',goodbye:'Nalama irunga. Appuram pesalaam.'},
};

/** Shared server decision for free local copy and wallet pricing. Never trust a
 * client flag. This does not replace authentication, chart or receipt checks. */
export function localConversationAcknowledgement(input:Input):string|null {
  if(input.responseMode!=='conversation')return null;
  const normalized=normalizeUserMessageBatch(input.userMessageBatch,input.responseMode,input.question);
  if(!normalized)return null;
  const messages=normalized.userMessageBatch.length?normalized.userMessageBatch:[normalized.question];
  let latest:LocalTurn|undefined;
  for(const message of messages){
    // Reject invisible content rather than deleting it into a whitelisted turn.
    // Only ordinary whitespace/case and trailing ASCII .! are tolerated.
    if(/[\p{Cf}\p{Cc}?？]/u.test(message))return null;
    const text=message.normalize('NFC').trim().toLocaleLowerCase().replace(/\s+/gu,' ').replace(/[.!]{1,3}$/u,'').trim();
    latest=exactPhrases.get(text);
    if(!latest)return null;
  }
  const style=input.style==='tamil'||input.style==='tanglish'?input.style:'english';
  return latest?replies[style][latest]:null;
}
