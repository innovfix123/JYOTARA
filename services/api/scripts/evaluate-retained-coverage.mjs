// Offline coverage audit only. Never calls providers or treats old answers as
// training targets. No question text, birth details, answers or secrets in output.
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import ts from 'typescript';

export async function evaluateRetainedCoverage() {
  const read = path => readFileSync(new URL(path, import.meta.url), 'utf8');
  const digest = value => createHash('sha256').update(value).digest('hex');
  const moduleSources = Object.fromEntries(['astrology-evidence', 'career-rules', 'career-answer-contract', 'career-response']
    .map(name => [name, read(`../lib/${name}.ts`)]));
  const compile = name => ts.transpileModule(moduleSources[name], {
    compilerOptions: {target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022},
  }).outputText;
  const url = value => `data:text/javascript;base64,${Buffer.from(value).toString('base64')}`;
  const evidenceUrl = url(compile('astrology-evidence'));
  const rulesUrl = url(compile('career-rules'));
  const contractUrl = url(compile('career-answer-contract').replaceAll('./career-rules', rulesUrl));
  const responseUrl = url(compile('career-response').replaceAll('./astrology-evidence', evidenceUrl)
    .replaceAll('./career-rules', rulesUrl).replaceAll('./career-answer-contract', contractUrl));
  const {buildEvidencePacket, careerQuestionKind} = await import(evidenceUrl);
  const {reviewedCareerResponse} = await import(responseUrl);
  if (!process.env.JYOTARA_PRIVATE_QA_DIR) throw new Error('Set JYOTARA_PRIVATE_QA_DIR to the private historical QA directory');
  const privateRead = name => readFileSync(process.env.JYOTARA_PRIVATE_QA_DIR + '/' + name, 'utf8');
  const corpusText = privateRead('all-100-questions-three-profiles.json');
  const retainedText = privateRead('results.json');
  const reviewText = privateRead('manual-review-local.json');
  const corpus = JSON.parse(corpusText);
  const profiles = JSON.parse(retainedText).profiles;
  const prior = JSON.parse(reviewText).reviews;
  if (!Array.isArray(corpus) || corpus.length !== 300 || profiles.length !== 3 || prior.length !== 300) {
    throw new Error('Retained evaluation set is incomplete');
  }
  const byProfile = new Map(profiles.map(profile => [profile.id, profile.facts]));
  const priorByKey = new Map(prior.map(row => [`${row.profile}:${row.id}`, row.verdict]));
  const seen = new Set();
  const evaluationClock = '2026-09-07T12:00:00Z';
  const cases = corpus.map(row => {
    const key = `${row.profile}:${row.questionId}`;
    if (seen.has(key) || !byProfile.has(row.profile) || !priorByKey.has(key)) {
      throw new Error('Duplicate case or missing profile/review link');
    }
    seen.add(key);
    const style = ({Tamil: 'tamil', Tanglish: 'tanglish', English: 'english'})[row.style];
    if (!style) throw new Error('Unrecognized corpus language');
    const packet = buildEvidencePacket({category: row.category, question: row.question,
      language: style === 'tamil' ? 'ta' : 'en', birthTimeKnown: true,
      chart: byProfile.get(row.profile), now: new Date(evaluationClock)});
    const result = row.category === 'Career' ? reviewedCareerResponse({
      snapshotId: row.profile, questionId: String(row.questionId), packet, style,
    }) : null;
    const status = packet.support === 'unsupported' ? 'withheld_unsupported'
      : result ? result.ok ? 'reviewed_reading_available' : 'needs_reviewed_career_coverage'
      : 'model_path_not_evaluated';
    return {profile: row.profile, questionId: String(row.questionId), category: row.category, style,
      intent: packet.intent, questionKind: row.category === 'Career' ? careerQuestionKind(row.question) : null,
      status, reason: result && !result.ok ? result.reason : null,
      priorVerdict: priorByKey.get(key),
      sourceFactCount: packet.facts.length,
      appliedRuleVersions: result?.ok ? result.provenance.ruleVersions : []};
  });
  const countBy = (rows, field) => Object.fromEntries([...new Set(rows.map(row => row[field]))]
    .map(value => [value, rows.filter(row => row[field] === value).length]));
  return {schemaVersion: 1, evaluationClock, method: 'Offline current rule coverage against retained charts; no model generation or live provider calls',
    limitations: ['Availability is not answer-quality approval.', 'Other-category model paths were not executed.',
      'Retained charts lack D9/current dated context; missing data was not invented.',
      'Exact birth time is assumed for these three fixtures only.', 'No historical failure is reclassified as passing by this audit.'],
    fingerprints: {corpus: digest(corpusText), profiles: digest(retainedText), priorReview: digest(reviewText),
      modules: Object.fromEntries(Object.entries(moduleSources).map(([name, value]) => [name, digest(value)]))},
    summary: {total: cases.length, priorVerdicts: countBy(cases, 'priorVerdict'),
      statuses: countBy(cases, 'status'), categories: countBy(cases, 'category'),
      careerQuestionKinds: countBy(cases.filter(row => row.category === 'Career'), 'questionKind')}, cases};
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const audit = await evaluateRetainedCoverage();
    console.log(JSON.stringify(process.argv.includes('--summary') ? audit.summary : audit, null, 2));
  }
  catch { console.error('Retained coverage audit failed; inspect fixtures and module compatibility. No provider calls were made.'); process.exitCode = 1; }
}
