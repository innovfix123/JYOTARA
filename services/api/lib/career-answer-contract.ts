import { eligibleCareerRules, type CareerRule } from './career-rules';
import type { EvidencePacket } from './astrology-evidence';

export type ReviewedCopy = { id: string; text: string; reviewId: string };
export type CareerAnswerContext = {
  snapshotId: string;
  questionId: string;
  packet: EvidencePacket;
  rules: readonly CareerRule[];
  // Server-curated, language-specific choices appropriate to this question.
  // Never populate these lists from the model or from the HTTP request body.
  directAnswers: readonly ReviewedCopy[];
  nextSteps: readonly ReviewedCopy[];
  limitations: readonly ReviewedCopy[];
  responseStyle?: 'english' | 'tamil' | 'tanglish';
};

/** An ID-only selection. No model-written factual sentence is accepted. */
export function renderCareerSelection(raw: unknown, context: CareerAnswerContext):
  { ok: true; answer: string; evidence: string[]; provenance: { snapshotId: string; questionId: string; ruleVersions: string[]; copyReviews: string[] } }
  | { ok: false; reason: string } {
  const reject = (reason: string) => ({ ok: false as const, reason });
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return reject('invalid_selection');
  const selection = raw as Record<string, unknown>;
  const keys = ['snapshotId', 'questionId', 'directAnswerId', 'evidenceIds', 'ruleIds', 'nextStepId', 'limitationId'];
  if (Object.keys(selection).length !== keys.length || keys.some(key => !(key in selection))) return reject('invalid_selection');
  if (selection.snapshotId !== context.snapshotId || selection.questionId !== context.questionId) return reject('subject_or_question_mismatch');
  if (context.packet.category !== 'Career' || context.packet.support === 'unsupported') return reject('unsupported_context');
  // IDs must resolve uniquely in the server catalogue, including withdrawn
  // entries. Never silently choose an older version by array order.
  const uniqueIds = (items: readonly { id: string }[]) =>
    new Set(items.map(item => item.id)).size === items.length;
  if (!uniqueIds(context.rules) || !uniqueIds(context.directAnswers) ||
      !uniqueIds(context.nextSteps) || !uniqueIds(context.limitations)) {
    return reject('ambiguous_catalogue');
  }
  const ids = (value: unknown): value is string[] => Array.isArray(value) && value.length > 0 && value.length <= 20
    && value.every(v => typeof v === 'string' && v.length > 0 && v.length <= 100) && new Set(value).size === value.length;
  if (!ids(selection.evidenceIds) || !ids(selection.ruleIds)) return reject('invalid_evidence_selection');
  const fields = context.packet.facts.map(f => f.field);
  if (new Set(fields).size !== fields.length) return reject('ambiguous_evidence');
  const facts = new Map(context.packet.facts.map(f => [f.field, f]));
  if (selection.evidenceIds.some(id => !facts.has(id))) return reject('unknown_evidence');
  const eligible = eligibleCareerRules(Object.fromEntries(context.packet.facts.map(f => [f.field, f.value])), context.rules);
  const selectedRules = selection.ruleIds.map(id => eligible.find(rule => rule.id === id));
  if (selectedRules.some(rule => !rule)) return reject('unreviewed_or_inapplicable_rule');
  if (selectedRules.some(rule => rule!.language !== (context.responseStyle ?? 'english'))) return reject('unreviewed_rule_language');
  if (selectedRules.some(rule => rule!.prerequisites.some(id => !(selection.evidenceIds as string[]).includes(id)))) return reject('missing_rule_evidence');
  if (selectedRules.some(rule => !(selection.evidenceIds as string[]).includes(rule!.condition.field))) return reject('missing_condition_evidence');
  if (selectedRules.some(rule => (rule!.additionalConditions ?? []).some(condition => !(selection.evidenceIds as string[]).includes(condition.field)))) return reject('missing_condition_evidence');
  const copy = (id: unknown, choices: readonly ReviewedCopy[]) => {
    const matches = choices.filter(c => c.id === id && c.reviewId.trim() && c.text.trim());
    return matches.length === 1 ? matches[0] : undefined;
  };
  const direct = copy(selection.directAnswerId, context.directAnswers);
  const step = copy(selection.nextStepId, context.nextSteps);
  const limitation = copy(selection.limitationId, context.limitations);
  if (!direct || !step || !limitation) return reject('unreviewed_copy');
  const evidence = selection.evidenceIds.map(id => {
    const fact = facts.get(id)!;
    return `${fact.label}: ${fact.displayValue ?? fact.value}`;
  });
  return { ok: true,
    answer: [direct.text, ...selectedRules.map(rule => rule!.interpretation), step.text, limitation.text].join('\n\n'),
    evidence,
    provenance: { snapshotId: context.snapshotId, questionId: context.questionId,
      ruleVersions: selectedRules.map(rule => `${rule!.id}@${rule!.version}`),
      copyReviews: [direct.reviewId, step.reviewId, limitation.reviewId] },
  };
}
