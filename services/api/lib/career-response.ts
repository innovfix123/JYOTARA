import { careerRules, eligibleCareerRules, type CareerRule } from './career-rules';
import { renderCareerSelection, type ReviewedCopy } from './career-answer-contract';
import type { EvidencePacket } from './astrology-evidence';
import type { ResponseStyle } from './guidance-language';

import { careerQuestionKind, type CareerQuestionKind } from './astrology-evidence';
export { careerQuestionKind } from './astrology-evidence';

export type CareerCopyBundle = {
  id: string;
  version: number;
  status: 'candidate' | 'approved' | 'withdrawn';
  questionKind: CareerQuestionKind;
  responseStyle: ResponseStyle;
  ruleIds: readonly string[];
  direct: ReviewedCopy;
  step: ReviewedCopy;
  limitation: ReviewedCopy;
};

const directionDrafts = {
  english: ['Writing, accounting and craft-based work are themes you could explore; this chart indicator does not decide which job is best for you.', 'Try one small task from two of these areas and compare your interest, existing skills and the work each role requires.', 'This covers one traditional configuration, not a complete career assessment. It does not establish a job date, salary or guaranteed outcome.'],
  tamil: ['எழுத்து, கணக்கு மற்றும் கைவினை சார்ந்த பணிகளை நீங்கள் ஆராய்ந்து பார்க்கலாம்; உங்களுக்கு எந்த வேலை சிறந்தது என்பதை இந்த ஜாதகக் குறிப்பு மட்டும் தீர்மானிக்காது.', 'இந்தத் துறைகளில் இரண்டைத் தேர்ந்தெடுத்து, ஒவ்வொன்றிலும் ஒரு சிறிய செயலைச் செய்து பாருங்கள். உங்கள் ஆர்வம், தற்போதைய திறன்கள், பணியின் தேவைகள் ஆகியவற்றை ஒப்பிடுங்கள்.', 'இது ஒரு பாரம்பரிய அமைப்பின் விளக்கம் மட்டுமே; முழுமையான தொழில் மதிப்பீடு அல்ல. வேலை கிடைக்கும் தேதி, சம்பளம் அல்லது உறுதியான முடிவை இது கூறவில்லை.'],
  tanglish: ['Writing, accounting, kaivinai saarndha velaigalai neenga explore pannalaam; ungalukku endha velai best-nu indha jathaga kurippu mattum mudivu seyyaadhu.', 'Indha areas-la rendai choose panni, ovvonnulayum oru chinna task senju paarunga. Unga interest, ippo irukkura skills, andha role-oda requirements-ai compare pannunga.', 'Idhu oru traditional amaippoda vilakkam mattum; complete career assessment illai. Job date, salary allathu guaranteed result-ai idhu sollala.'],
};
// English has a recorded, bounded assistant review. Tamil/Tanglish remain
// drafts. Neither the runtime language model nor client can set approvals.
const mercuryBundles: readonly CareerCopyBundle[] = (['english', 'tamil', 'tanglish'] as const).map(responseStyle => {
  const id = `CAREER-DIRECTION-MERCURY-CONVERGENCE-${responseStyle}`;
  const [direct, step, limitation] = directionDrafts[responseStyle];
  const reviewId = responseStyle === 'english' ? 'AST-REVIEW-EN-MERCURY-V2-20260907' : '';
  return { id, version: 2, status: reviewId ? 'approved' : 'candidate', questionKind: 'career_direction', responseStyle,
    ruleIds: [`CAREER-BJ10-D9-MERCURY-CONVERGENCE-${responseStyle}`],
    direct: {id: `${id}-direct`, text: direct, reviewId},
    step: {id: `${id}-step`, text: step, reviewId},
    limitation: {id: `${id}-limitation`, text: limitation, reviewId},
  };
});

const moonReview = 'AST-REVIEW-EN-MOON-V1-20260907';
const supportLanguageCopy = {
  tamil: {
    Moon: 'வேலை தொடர்பான ஆதரவுக்கு, இந்தப் பாரம்பரிய ஜாதக வாசிப்பில் அம்மாவின் பங்கு குறிப்பிடப்படுகிறது. உங்களுக்குள் ஆதரவான உறவு இருந்தால், உங்கள் திட்டங்களைப் பற்றி அவரிடம் பேசிப் பார்க்கலாம். இது உதவி கிடைக்கும் என்ற உறுதி அல்ல.',
    Jupiter: 'வேலை தொடர்பான ஆதரவுக்கு, இந்தப் பாரம்பரிய வாசிப்பில் அண்ணன் அல்லது தம்பியின் பங்கு குறிப்பிடப்படுகிறது. உங்களுக்குச் சகோதரர் இருந்து, ஆதரவான உறவும் இருந்தால், உங்கள் திட்டங்களைப் பற்றி அவரிடம் பேசிப் பார்க்கலாம். அவர் உதவியே ஆக வேண்டும் என்று எதிர்பார்க்க வேண்டாம்.',
    step: 'உங்கள் உண்மையான சூழலுக்குப் பொருந்தினால், பண உதவிக்கு பதிலாக உங்கள் திட்டத்தைப் பற்றிய கருத்தையோ ஒரு அறிமுகத்தையோ கேட்கலாம். பொருந்தாவிட்டால், இந்த வாசிப்பை வேறு யாருடனும் வலிந்து தொடர்புபடுத்த வேண்டாம்.',
    limitation: 'இது ஒரு குறிப்பிட்ட பாரம்பரிய ஆதரவுக் குறிப்பு மட்டுமே. மற்றவரின் மனநிலைக்கான ஆதாரமோ வேலை மற்றும் வருமானம் பற்றிய உறுதியான கணிப்போ அல்ல.',
  },
  tanglish: {
    Moon: 'Velai thodarbaana support-ku, indha traditional jathaga vaasippil amma-vin pangu kurippidappadugiradhu. Ungalukkul aadharavaana uravu irundhaal, unga plans pathi avangakitta pesip paarkkalaam. Idhu udhavi kidaikkum endra urudhi illai.',
    Jupiter: 'Velai thodarbaana support-ku, indha traditional vaasippil annan allathu thambi-yin pangu kurippidappadugiradhu. Ungalukku sagodharar irundhu, aadharavaana uravum irundhaal, unga plans pathi avarkitta pesip paarkkalaam. Avar udhaviye aaganum-nu edhirpaarkka vendaam.',
    step: 'Unga unmaiyaana soozhalukku porundhinaal, pana udhavikku badhila unga plan pathi feedback allathu oru introduction ketkalaam. Porundhaavittaal, indha vaasippai vera yaarodum valindhu thodarbudutha vendaam.',
    limitation: 'Idhu oru kurippitta traditional support kurippu mattum. Matravarin mananilaikkaana aadharam allathu velai, varumaanam patriya urudhiyaana kanippu illai.',
  },
};
export const careerCopyBundles: readonly CareerCopyBundle[] = [...mercuryBundles, {
  id: 'CAREER-DIRECTION-MOON-CONVERGENCE-english', version: 1,
  status: 'approved', questionKind: 'career_direction', responseStyle: 'english',
  ruleIds: ['CAREER-BJ10-D9-MOON-CONVERGENCE-english'],
  direct: {id: 'moon-direction-direct', reviewId: moonReview, text: 'Cultivation and trade in water-derived products are two traditional career themes to explore in this chart pattern. Treat them as starting points for exploration, not a verdict on which job you should take.'},
  step: {id: 'moon-direction-step', reviewId: moonReview, text: 'Choose one real role in either area and speak with someone doing that work about its daily tasks, training and working conditions. Compare those with your interests before committing.'},
  limitation: {id: 'moon-direction-limit', reviewId: moonReview, text: 'This is one conditional reading, not a complete career assessment or a recommendation to invest in a business. It does not establish job timing or future earnings.'},
}, ...careerRules.filter(rule => rule.id.startsWith('CAREER-BJ10-D9-MIXED-MERCURY-MOON-')).map(rule => {
  const id = `${rule.id}-copy`;
  const reviewId = 'AST-REVIEW-EN-MIXED-MERCURY-MOON-V1-20260907';
  return {id, version: 1, status: 'approved' as const, questionKind: 'career_direction' as const, responseStyle: 'english' as const,
    ruleIds: [rule.id],
    direct: {id: `${id}-direct`, reviewId, text: 'Your chart presents more than one traditional career theme: writing, accounting or craft work, alongside cultivation or trade in water-derived products. Explore these as alternatives; the pattern does not identify one guaranteed best career.'},
    step: {id: `${id}-step`, reviewId, text: 'Pick one real role from each group. Compare its daily tasks and training with your interests, then try a small introductory task or speak with someone doing that work.'},
    limitation: {id: `${id}-limit`, reviewId, text: 'This compares two traditional themes without judging which is stronger. It is not a complete career assessment, investment recommendation or forecast of job timing and income.'},
  };
}), ...(['Moon', 'Jupiter'] as const).map(planet => {
  const id = `CAREER-SUPPORT-${planet}-english`;
  const reviewId = 'AST-REVIEW-EN-SUPPORT-V1-20260907';
  return {id, version: 1, status: 'approved' as const, questionKind: 'career_support' as const, responseStyle: 'english' as const,
    ruleIds: [`CAREER-BJ10-SUPPORT-${planet}-english`],
    direct: {id: `${id}-direct`, reviewId, text: planet === 'Moon'
      ? 'For career support, your traditional chart reading highlights your mother. If that relationship is present and supportive, it is one place to start a conversation—not a promise of help.'
      : 'For career support, this traditional reading highlights a brother as a possible family connection. If you have a brother and a supportive relationship, you could explore that connection without assuming help is owed.'},
    step: {id: `${id}-step`, reviewId, text: 'If this fits your real circumstances, ask for one concrete non-financial form of help, such as feedback on your plans or an introduction. If it does not fit, do not force the reading onto someone else.'},
    limitation: {id: `${id}-limit`, reviewId, text: 'This is a limited traditional support theme, not evidence of another person’s intentions or a forecast of employment and income.'},
  };
}), ...(['tamil', 'tanglish'] as const).flatMap(responseStyle => (['Moon', 'Jupiter'] as const).map(planet => {
  const id = `CAREER-SUPPORT-${planet}-${responseStyle}`;
  // User rejected this explanatory tone on 2026-09-07. Preserve as a draft,
  // not a deployable or user-approved interpretation bundle.
  const reviewId = '';
  const copy = supportLanguageCopy[responseStyle];
  return {id, version: 1, status: 'candidate' as const, questionKind: 'career_support' as const, responseStyle,
    ruleIds: [`CAREER-BJ10-SUPPORT-${planet}-${responseStyle}`],
    direct: {id: `${id}-direct`, reviewId, text: copy[planet]},
    step: {id: `${id}-step`, reviewId, text: copy.step},
    limitation: {id: `${id}-limit`, reviewId, text: copy.limitation},
  };
}))];

export function reviewedCareerResponse(input: {
  snapshotId: string; questionId: string; packet: EvidencePacket; style: ResponseStyle;
}, registry: { rules: readonly CareerRule[]; bundles: readonly CareerCopyBundle[] } = {
  rules: careerRules, bundles: careerCopyBundles,
}) {
  const unavailable = (reason: string) => ({ ok: false as const, reason });
  if (input.packet.category !== 'Career' || input.packet.support === 'unsupported') return unavailable('unsupported_context');
  const kind = careerQuestionKind(input.packet.question);
  const idsUnique = (items: readonly { id: string }[]) => new Set(items.map(item => item.id)).size === items.length;
  if (!idsUnique(registry.rules) || !idsUnique(registry.bundles)) return unavailable('ambiguous_catalogue');
  const facts = Object.fromEntries(input.packet.facts.map(f => [f.field, f.value]));
  const eligible = eligibleCareerRules(facts, registry.rules).filter(rule => rule.language === input.style);
  if (!eligible.length) return unavailable('no_reviewed_applicable_rule');
  const eligibleIds = new Set(eligible.map(rule => rule.id));
  const bundles = registry.bundles.filter(bundle => bundle.status === 'approved' &&
    bundle.questionKind === kind && bundle.responseStyle === input.style &&
    bundle.ruleIds.length > 0 && new Set(bundle.ruleIds).size === bundle.ruleIds.length &&
    bundle.ruleIds.every(id => eligibleIds.has(id)));
  // Competing direct readings need an explicit reviewed synthesis, not a
  // first-match winner chosen by array order or language-model confidence.
  if (bundles.length !== 1) return unavailable(bundles.length ? 'ambiguous_synthesis' : 'no_reviewed_question_copy');
  const bundle = bundles[0];
  const selectedRules = eligible.filter(rule => bundle.ruleIds.includes(rule.id));
  const evidenceIds = [...new Set(selectedRules.flatMap(rule => [...rule.prerequisites, rule.condition.field, ...(rule.additionalConditions ?? []).map(condition => condition.field)]))];
  const result = renderCareerSelection({ snapshotId: input.snapshotId, questionId: input.questionId,
    directAnswerId: bundle.direct.id, evidenceIds, ruleIds: bundle.ruleIds,
    nextStepId: bundle.step.id, limitationId: bundle.limitation.id,
  }, { snapshotId: input.snapshotId, questionId: input.questionId, packet: input.packet,
    rules: registry.rules, directAnswers: [bundle.direct], nextSteps: [bundle.step],
    limitations: [bundle.limitation], responseStyle: input.style });
  return result.ok ? { ...result, bundleVersion: `${bundle.id}@${bundle.version}`, questionKind: kind } : result;
}
