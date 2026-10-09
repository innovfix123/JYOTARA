export const legacyResearchVersion='anonymous-questions-v1';
export const conversationResearchVersion='research-conversation-v2';
export function researchVersion(value:unknown){return value===conversationResearchVersion?conversationResearchVersion:legacyResearchVersion;}
function redact(text:string){return text.replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi,'[email removed]').replace(/(?<!\d)(?:\+?91[-\s]?)?[6-9]\d{9}(?!\d)/g,'[phone removed]');}
/** Legacy clients consent only to questions. Replies need explicit v2 consent. */
export function researchContent(input:{researchConsent?:boolean;researchConsentVersion?:unknown;question?:string},answer:unknown){
 if(input.researchConsent!==true||typeof input.question!=='string')return null;
 const consentVersion=researchVersion(input.researchConsentVersion);
 return {question:redact(input.question),...(consentVersion===conversationResearchVersion&&typeof answer==='string'?{answer:redact(answer)}:{}),consentVersion};
}
