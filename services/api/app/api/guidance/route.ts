import { divineContext } from '@/lib/divine-calculations';
import { divineConsultation } from '@/lib/divine-consultation';
import { profileOverviewQuestion, profileOverview } from '@/lib/profile-overview';
import { env } from 'cloudflare:workers';
import { chartSessionDeleted } from '@/db/profile-deletion';
import { chartTicketConfigured, openChartTicket, openBirthGuidanceTicket } from '@/lib/chart-ticket';
import { requestIdentity, reserveQuestion, sealReply, openReply, eraseGuidanceContent, completeQuestion } from '@/db/guidance-requests';
import { currentContext } from '@/db/current-context';
import { normalizeProviderContext } from '@/lib/provider-chart';
import { reportPerson, verifiedReportPerson } from '@/lib/marriage-report';
import { conversationTopic, providerReadingSources, previousUserMessages, conversationHistory, relationshipFollowup, relationshipResponse, responseStyle, acceptableAnswer, periodClaimsAgree, tanglishUnavailable, type ResponseStyle } from '@/lib/guidance-language';
import {
  buildTopicContext,
  buildEvidencePacket,
  buildFallbackAnswer,
  type ChartFacts,
  type GuidanceCategory,
} from '@/lib/astrology-evidence';

const allowedCategories = new Set<GuidanceCategory>([
  'Daily', 'Education', 'Career', 'Love', 'Breakup', 'Relationships',
  'Marriage', 'Family', 'Business', 'Property', 'Spiritual', 'Panchang',
]);
const guideVoices:Record<string,string>={
 Aadhirai:'Love: warm, gentle and attentive; understand feelings before offering a next step.',
 Arivan:'Career: thoughtful and clear; explore direction, responsibility and the user’s real work context.',
 Medha:'Education: patient and encouraging; understand learning needs before suggesting one manageable step.',
 Tharagai:'Marriage: calm and respectful; centre consent, readiness and shared expectations.',
 Kaalam:'Daily guidance: light and focused; ask what matters today and keep advice immediately useful.',
 Iniya:'Relationships: empathetic and plain-spoken; support communication without assuming anyone’s feelings.',
 Nila:'Family: steady and understanding; balance connection with personal boundaries.',
 Vetri:'Job search: reassuring and practical; ask about applications and the specific role, without promising selection.',
 Valan:'Business: deliberate and concrete; explore the idea and shared responsibilities, without forecasting profit.',
 Oli:'Higher education: curious and supportive; help compare study paths with the user’s priorities.',
 Agam:'Home and property: composed and practical; explore home needs without giving financial or legal verdicts.',
 Arul:'Spiritual reflection: gentle and unhurried; offer optional simple practices, never fear or costly remedies.',
};
const allowedLanguages = new Set(['ta', 'en']);
const allowedAgeBands = new Set(['13-17', '18-20', '21-27', '28-35', '36-45', '46-59', '60+']);
const sessionCookie = 'nirayana_pilot_session';
const researchConsentVersion = 'anonymous-questions-v1';

function redactContactDetails(value: string) {
  return value
    .replace(/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/gi, '[email removed]')
    .replace(/(?<!\d)(?:\+?91[-\s]?)?[6-9]\d{9}(?!\d)/g, '[phone removed]');
}

function getSession(request: Request) {
  const cookie = request.headers.get('cookie') ?? '';
  const existing = cookie
    .split(';')
    .map((part) => part.trim())
    .find((part) => part.startsWith(`${sessionCookie}=`))
    ?.slice(sessionCookie.length + 1);
  return { id: existing || crypto.randomUUID(), existing: Boolean(existing) };
}

function outputText(payload: unknown) {
  if (!payload || typeof payload !== 'object') return '';
  const value = payload as { output_text?: unknown; output?: unknown };
  if (typeof value.output_text === 'string') return value.output_text.trim();
  if (!Array.isArray(value.output)) return '';
  return value.output
    .flatMap((item) => {
      if (!item || typeof item !== 'object') return [];
      const content = (item as { content?: unknown }).content;
      return Array.isArray(content) ? content : [];
    })
    .map((item) => item && typeof item === 'object' ? (item as { text?: unknown }).text : '')
    .filter((item): item is string => typeof item === 'string')
    .join('\n')
    .trim();
}

async function ensureRequestTable() {
  // Migrations own schema. Request-triggered cleanup is not a scheduler.
  await env.DB.prepare(`UPDATE guide_requests SET response_ciphertext = NULL
    WHERE response_ciphertext IS NOT NULL AND response_expires_at <= ?`).bind(Date.now()).run();
  // Raw consented question text is research data, not permanent profile data.
  // Keep the aggregated request row while removing the text after 90 days.
  await env.DB.prepare(`
    UPDATE guide_requests
    SET question_text = NULL, research_consent_version = NULL
    WHERE question_text IS NOT NULL AND created_at < ?
  `).bind(Date.now() - 90 * 24 * 60 * 60 * 1000).run();
}

export async function DELETE(request: Request) {
  const session = getSession(request);
  if (session.existing) {
    await ensureRequestTable();
    await eraseGuidanceContent(env.DB, session.id).run();
  }
  return new Response(null, { status: 204 });
}

export async function POST(request: Request) {
  // Chat has no fixed question allowance; receipts still prevent duplicate work.
  const questionLimit = null;
  const body = (await request.json().catch(() => null)) as null | {
    category?: GuidanceCategory;
    question?: string;
    language?: string;
    responseStyle?: string;
    birthTimeKnown?: boolean;
    chart?: ChartFacts;
    researchConsent?: boolean;
    ageBand?: string;
    profileId?: string;
    chartTicket?: string;
    requestId?: string;
    previousUserMessages?: unknown;
    conversationHistory?: unknown;
    guide?: string;
    reportPerson?: unknown;
  };
  const question = typeof body?.question === 'string' ? body.question.trim().replace(/\s+/g, ' ') : '';
  if (!body?.category || !allowedCategories.has(body.category) || !question || [...question].length > 240) {
    return Response.json({ error: 'A valid category, question and calculated chart are required.' }, { status: 400 });
  }
  if (body.guide !== undefined && (typeof body.guide !== 'string' || !Object.hasOwn(guideVoices,body.guide))) return Response.json({error:'Unknown guide.'},{status:400});
  if (body.requestId !== undefined && (typeof body.requestId !== 'string' || !/^[A-Za-z0-9_-]{16,128}$/.test(body.requestId))) {
    return Response.json({ error: 'Invalid request identifier.' }, { status: 400 });
  }
  const dialogue = conversationHistory(body.conversationHistory);
  if (dialogue === null) return Response.json({error:'Invalid conversation history.'},{status:400});
  const history = previousUserMessages(body.previousUserMessages);
  if (history === null) return Response.json({error: 'Invalid conversation context.'}, {status: 400});
  const language = allowedLanguages.has(body.language ?? '') ? body.language! : 'ta';
  const style = responseStyle(body.responseStyle, language);
  const ageBand = allowedAgeBands.has(body.ageBand ?? '') ? body.ageBand! : null;
  const session = getSession(request);
  const chartSecret = (env.JYOTARA_CHART_TICKET_KEY ?? env.NIRAYANA_CHART_TICKET_KEY);
  if (!chartTicketConfigured(chartSecret)) {
    return Response.json({ error: 'Chart protection is not configured.' }, { status: 503 });
  }
  const trusted = await openChartTicket(chartSecret, body.chartTicket, session.id, body.profileId) ?? await openBirthGuidanceTicket(chartSecret,body.chartTicket,session.id,body.profileId);
  if (!trusted) return Response.json({ error: 'Your chart session is missing or expired. Please reopen your profile.' }, { status: 401 });
  if (await chartSessionDeleted(env.DB, session.id)) return Response.json({ error: 'This chart session was deleted.', code: 'profile_deleted' }, { status: 410 });
  // Client chart/birthTimeKnown fields are never used as evidence, even if present.

  await ensureRequestTable();
  // Older clients without an ID still receive atomic quota protection, but
  // cannot recover a response after transport failure. New clients reuse IDs.
  const identityPayload: unknown[] = [trusted.profileId, body.category, question, language, style, body.researchConsent === true, ageBand];
  // Preserve legacy hashes for requests without context. Context changes conflict.
  if (history.length) identityPayload.push(history);
  if (dialogue.length) identityPayload.push({conversationHistory:dialogue});
  if (body.guide) identityPayload.push({guide:body.guide});
  if (body.reportPerson !== undefined) identityPayload.push({reportPerson:body.reportPerson});
  const identity = await requestIdentity(chartSecret, session.id,
    body.requestId ?? crypto.randomUUID(), identityPayload);
  const reservation = await reserveQuestion(env.DB, {
    ...identity, session: session.id, category: body.category, language, now: Date.now(), limit: questionLimit,
  });
  if (reservation.kind === 'limit') {
    return Response.json({ error: 'This chart session is no longer available. Please reopen your profile.', code: 'profile_unavailable' }, { status: 410 });
  }
  if (reservation.kind === 'existing') {
    const receipt = reservation.receipt;
    if (receipt.answer_mode === 'deleted') {
      return Response.json({ error: 'This question was deleted and has not been submitted again.', code: 'request_deleted' }, { status: 410, headers: { 'Cache-Control': 'no-store' } });
    }
    if (receipt.request_hash !== identity.hash) {
      return Response.json({ error: 'This request identifier belongs to a different question.', code: 'request_conflict' }, { status: 409 });
    }
    if (receipt.response_ciphertext && (receipt.response_expires_at ?? 0) > Date.now()) {
      try {
        const saved = await openReply(chartSecret, identity.id, receipt.response_ciphertext);
        if (!saved || typeof saved !== 'object' || Array.isArray(saved)) throw new Error('Invalid saved reply');
        return Response.json({ ...saved, replayed: true, providerUsage:{calls:[],newProviderCalls:0,receiptReused:true} }, { headers: { 'Cache-Control': 'no-store' } });
      } catch { /* Fail closed: never rerun a possibly billed attempt. */ }
    }
    return Response.json({ error: 'This question was already received. Its answer is not available yet; it has not been submitted again.', code: 'request_already_received' }, { status: 409, headers: { 'Cache-Control': 'no-store' } });
  }

  // Old tickets lack the location needed to safely refresh timed context.
  // Keep natal facts, but do not reuse their one-time Panchang selection.
  let chart: ChartFacts = { ...trusted.chart, transits: undefined, todayPanchang: undefined, contextCalculatedAt: undefined };
  body.category = conversationTopic(question, body.category, dialogue.length ? dialogue.filter(turn=>turn.role==='user').map(turn=>turn.content) : history) as GuidanceCategory;
  const safetyQuestion = relationshipFollowup(question) ? [...history, question].join('\n') : question;
  const safetyPacket = buildEvidencePacket({category: body.category, question: safetyQuestion, language, birthTimeKnown: trusted.birthTimeKnown, chart});
  const scripted = safetyPacket.intent === 'high_stakes' ? null : relationshipResponse(body.category, question, history, style);
  // Context-aware wording for ordinary conversation; dedicated sensitive boundaries remain.
  let practical = scripted && ['privacy', 'no_contact'].includes(scripted.kind) ? scripted : null;
  if (safetyPacket.intent !== 'high_stakes' && !practical && question !== profileOverviewQuestion) {
    const person = reportPerson(body.reportPerson);
    const verified = trusted.birthTimeKnown && person && (
      (trusted.birthDatetime === person.datetime && trusted.contextLocation?.latitude === person.latitude && trusted.contextLocation?.longitude === person.longitude) ||
      await verifiedReportPerson(env.DB,person,session.id,trusted.profileId,trusted.contextLocation,{
        hash:async values=>(await requestIdentity(chartSecret,session.id,'profile-v1',values)).hash,
        open:(id,cipher)=>openReply(chartSecret,id,cipher,2_000_000),
      }));
    const result = verified && person ? await divineConsultation(env,{id:identity.id,person,question,style,category:body.category,guide:body.guide,dialogue},env.DB) : {answer:null,calls:[]};
    const unavailable = !verified
      ? (style==='tamil'?'பிறந்த நேரத்துடன் சேமித்த விவரங்களைத் திறந்து உறுதிப்படுத்துங்கள்; அதன் பிறகு உங்கள் கேள்விக்கான ஜாதகப் பலனைப் பார்க்கலாம்.':style==='tanglish'?'Pirandha nerathoda saved details-a thirandhu urudhippaduthunga; appuram unga kelvikkaana jathaga palanai paarkalaam.':'Please confirm your saved birth details and birth time so I can prepare this chart reading.')
      : (style==='tamil'?'பதிலைத் தயாரிப்பதில் தாமதம் ஏற்பட்டுள்ளது. சிறிது நேரத்தில் புதிய கேள்வியை அனுப்புங்கள்.':style==='tanglish'?'Badhil thayaarikka thaamadham aagudhu. Konjam nerathil pudhu kelviyai anuppunga.':'The reading could not be completed just now. Please send a new question in a moment.');
    const reply={replayed:false,answer:result.answer||unavailable,answerMode:result.answer?'provider_reading':'reading_unavailable',
      providerUsage:{calls:result.calls,newProviderCalls:result.calls.length},answeredAt:new Date().toISOString(),
      evidence:[],support:'partially_supported',profileId:trusted.profileId};
    const completed=await completeQuestion(env.DB,{id:identity.id,session:session.id,support:reply.support,mode:reply.answerMode,
      question:body.researchConsent===true?redactContactDetails(question):null,intent:safetyPacket.intent,
      consent:body.researchConsent===true?researchConsentVersion:null,ageBand,
      ciphertext:await sealReply(chartSecret,identity.id,reply),expiresAt:trusted.expiresAt});
    if(!completed)return Response.json({error:'This question is no longer active.',code:'request_inactive'},{status:410});
    return Response.json(reply,{headers:{'Cache-Control':'no-store'}});
  }
  // Only the profile introduction and explicit safety/privacy responses reach
  // this path. Ordinary astrology questions use Divine above, without fallback
  // to a retired provider or a generic model-generated chart reading.
  const charges:import('@/lib/divine-calculations').CalculationCharge[]=[];
  const overview=question===profileOverviewQuestion;
  if(overview && trusted.contextLocation) {
    const now=Date.now();
    const context=await currentContext(env.DB,trusted.contextLocation,
      (module,datetime,location)=>divineContext(env,module,{...location,datetime},charges),now);
    chart={...chart,...normalizeProviderContext(context,new Date(now))};
  }
  const answer=overview?profileOverview(chart,trusted.birthTimeKnown,style):practical?.answer??buildFallbackAnswer(safetyPacket,style);
  const mode=overview?'chart_guidance':practical?'practical_guidance':'grounded_fallback';
  const reply={replayed:false,answer,answerMode:mode,profileId:trusted.profileId,
    providerUsage:{calls:charges,newProviderCalls:charges.length},answeredAt:new Date().toISOString(),evidence:[],support:safetyPacket.support};
  const completed=await completeQuestion(env.DB,{id:identity.id,session:session.id,support:safetyPacket.support,mode,
    question:body.researchConsent===true?redactContactDetails(question):null,intent:safetyPacket.intent,
    consent:body.researchConsent===true?researchConsentVersion:null,ageBand,
    ciphertext:await sealReply(chartSecret,identity.id,reply),expiresAt:trusted.expiresAt});
  if(!completed)return Response.json({error:'This question is no longer active.',code:'request_inactive'},{status:410});
  return Response.json(reply,{headers:{'Cache-Control':'no-store'}});
}
