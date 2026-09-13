"""Offline candidate validation, not enabled in Jyotara's live request path.

Divine can exhaust its output allowance while still reporting grounding=ok.
Checks below catch structural/language defects, NOT semantic or chart accuracy.
Only explicit rejected responses can be retried once. Transport errors are not
retried because the provider may have charged and has no documented idempotency.
"""
import json,re,urllib.request,urllib.error

def issues(reply,language):
    answer=reply.get('answer','')
    if not isinstance(answer,str) or not answer.strip():return ['empty answer']
    answer=answer.strip(); errors=[]
    if not re.search(r'[.!?。][\"”\')]*$',answer):errors.append('unfinished ending')
    if answer.count('“')!=answer.count('”'):errors.append('unclosed quotation')
    if language=='Tamil' and (not re.search(r'[\u0b80-\u0bff]',answer) or re.search(r'[A-Za-z]',answer)):errors.append('Tamil script mismatch')
    if language=='Tanglish' and re.search(r'[\u0b80-\u0bff]',answer):errors.append('Tanglish script mismatch')
    if len(answer.split())>100:errors.append('too long for chat')
    # Hitting the allowance does not itself prove truncation; flag for review.
    return errors

class Client:
    def __init__(self,key,send=None):self.key=key;self.send=send or self._send
    def _send(self,payload):
        req=urllib.request.Request('https://ask.divineapi.com/chat',data=json.dumps(payload).encode(),headers={'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(req,timeout=50) as r:return json.load(r)
        except urllib.error.HTTPError as e:raise RuntimeError('Divine HTTP '+str(e.code)) from None
        except (OSError,ValueError):raise RuntimeError('Divine transport or JSON failure; do not retry automatically') from None
    def ask(self,session,user,question,language,profile=None):
        notes=('Complete the answer in 2 short sentences, at most '+('35' if language=='Tamil' else '65')+' words. Answer the latest question first, explain one relevant chart reason when needed. Remember earlier corrections. Avoid repeating placements. Ask only a useful missing detail. '+{'Tamil':'Tamil script only; use familiar Tamil astrology terms.','Tanglish':'Spoken Tamil in Latin letters only; use Guru dasai, Budhan bhukthi where applicable.','English':'Natural clear English.'}[language])
        payload={'api_key':self.key,'user_id':user,'session_id':session,'message':question,'depth':'standard','length_cap':'full','school':'vedic','lens':'love','language':language,'stream':False,'tone':'Warm, knowledgeable AI Vedic astrologer; conversational and hopeful','style_notes':notes}
        if profile:payload.update(profile)
        attempts=[]
        for attempt in range(2):
            reply=self.send(payload); errors=issues(reply,language)
            attempts.append({'reply':reply,'issues':errors})
            if not errors:return {'answer':reply['answer'],'attempts':attempts,'status':'structurally_valid_needs_review'}
            # Correction is explicit, remains in provider's QA conversation.
            # Do not silently expose a partial answer or make unlimited charges.
            payload={**payload,'message':'Please replace your previous incomplete or wrong-script answer. Answer this original question completely in two short sentences in '+language+': '+question}
            for key in (profile or {}):payload.pop(key,None)
        return {'answer':None,'attempts':attempts,'status':'rejected'}
