export type ResponseStyle = 'english' | 'tamil' | 'tanglish';

export function responseStyle(value: unknown, language: string): ResponseStyle {
  return value === 'english' || value === 'tamil' || value === 'tanglish'
    ? value : language === 'en' ? 'english' : 'tamil';
}

export function languageInstruction(style: ResponseStyle): string {
  if (style === 'tanglish') return 'Reply in conversational Tamil written ONLY in Latin letters (Tanglish), with familiar English words where natural. Do not use Tamil script. Use simple, respectful spoken Tamil, not literal English translations. Example style: Oru nerathil oru thevaiyai mattum theliva sollunga.';
  if (style === 'tamil') return 'Reply in clear, natural conversational Tamil using Tamil script. Use respectful நீங்கள் forms, short sentences and idiomatic wording. Avoid literal English translations and unrelated foreign scripts. Preserve familiar Jyotish terminology only when relevant.';
  return 'Reply in clear conversational English. Preserve familiar Jyotish terminology.';
}

// This rejects obvious bad output; it is not a complete semantic verifier.
export function acceptableAnswer(answer: string, style: ResponseStyle): boolean {
  if (!answer.trim() || answer.length > 6000) return false;
  // Reject unrelated scripts even when the reply also contains valid Tamil.
  const letters = answer.match(/\p{L}/gu) ?? [];
  if (letters.some(letter => !/\p{Script=Latin}/u.test(letter) && !(style === 'tamil' && /\p{Script=Tamil}/u.test(letter)))) return false;
  // No activity-specific date/window is currently part of the answer contract.
  // Do not make arbitrary model dates acceptable merely because a date also
  // occurs in the question or a Dasa interval. A future timing feature needs
  // separately validated evidence and deterministic rendering.
  const timingText = answer.normalize('NFKC').replace(/[௦-௯]/g, digit => String(digit.charCodeAt(0) - 0x0BE6));
  const numberWord = '(?:one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)';
  if (/[0-9]{1,2}\s*:\s*[0-9]{2}/i.test(timingText)
    || /[0-9]{1,2}\s*\.\s*[0-9]{2}\s*(?:a\.?m\.?|p\.?m\.?)/i.test(timingText)
    || /\b[0-9]{1,2}\s*(?:a\.?m\.?|p\.?m\.?|o.clock|hours?\b|mani\b)/i.test(timingText)
    || new RegExp(`\\b${numberWord}\\s*(?:a\\.?m\\.?|p\\.?m\\.?|o.clock|in the (?:morning|afternoon|evening))`, 'i').test(timingText)
    || /(?:காலை|மாலை|இரவு|மதியம்)\s*(?:[0-9]+|ஒன்று|இரண்டு|மூன்று|நான்கு|ஐந்து|ஆறு|ஏழு|எட்டு|ஒன்பது|பத்து)/.test(timingText)
    || /[0-9]+\s*மணி/.test(timingText)
    || /\b[0-9]{4}-[0-9]{2}-[0-9]{2}\b|\b[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{2,4}\b/.test(timingText)
    || /\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+[0-9]{1,2}\b/i.test(timingText)
    || /\b[0-9]{1,2}(?:st|nd|rd|th)?\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\b/i.test(timingText)) return false;
  const claimsText = answer.replace(/\bwithout expecting fixed dates or guaranteed results\b/gi, '').replace(/\b(?:not guaranteed|cannot be guaranteed|can't be guaranteed|isn't guaranteed|no guaranteed outcome)\b/gi, '');
  if (/100\s*%|guaranteed|definitely (?:marry|break|die)|hidden enemy|secret enemy|கண்டிப்பாக.*(?:திருமணம்|பிரிவு|மரணம்)/i.test(claimsText)) return false;
  if (style === 'tanglish' && /[\u0B80-\u0BFF]/.test(answer)) return false;
  if (style === 'tamil' && !/[\u0B80-\u0BFF]/.test(answer)) return false;
  return true;
}

export function tanglishUnavailable(): string {
  return 'Indha kelvikku nambagamaana personal vilakkam ippo thayaaraga illai. Keezhe ulla chart facts-ai paarkalam; idhai vechu urudhiyaana date allathu innoruvarin mudivai solla mudiyaadhu.';
}

const periodPlanetAliases: Record<string, string> = {
  sun: 'Sun', surya: 'Sun', suriyan: 'Sun', 'சூரியன்': 'Sun', 'சூரிய': 'Sun',
  moon: 'Moon', chandra: 'Moon', chandran: 'Moon', 'சந்திரன்': 'Moon', 'சந்திர': 'Moon',
  mars: 'Mars', mangal: 'Mars', sevvai: 'Mars', 'செவ்வாய்': 'Mars',
  mercury: 'Mercury', budha: 'Mercury', budhan: 'Mercury', 'புதன்': 'Mercury', 'புத': 'Mercury',
  jupiter: 'Jupiter', guru: 'Jupiter', 'குரு': 'Jupiter',
  venus: 'Venus', shukra: 'Venus', sukiran: 'Venus', sukkiran: 'Venus', 'சுக்கிரன்': 'Venus', 'சுக்கிர': 'Venus',
  saturn: 'Saturn', shani: 'Saturn', sani: 'Saturn', 'சனி': 'Saturn',
  rahu: 'Rahu', 'ராகு': 'Rahu', ketu: 'Ketu', kethu: 'Ketu', 'கேது': 'Ketu',
};

/** Targeted contradiction guard, not a complete natural-language verifier.
 * Date claims are checked separately. Rendered evidence remains authoritative. */
export function periodClaimsAgree(answer: string, facts: readonly { field: string; value: string }[]): boolean {
  const planet = `(${Object.keys(periodPlanetAliases).sort((a, b) => b.length - a.length).join('|')})`;
  const period = '(mahadasha|mahadashai|mahadasa|maha dasha|mahadasai|antardasha|antar dasha|antardasa|bhukti|bukthi|bhukthi|புக்தி|புத்தி|அந்தர்தசா|அந்தர்தசை|மகாதசா|மகாதசை|தசா|தசை)';
  const boundary = '(?<![\\p{L}\\p{N}])';
  const ending = '(?![\\p{L}\\p{N}])';
  const patterns = [
    { re: new RegExp(`${boundary}${planet}\\s*(?:[-–:]\\s*)?${period}${ending}`, 'giu'), reverse: false },
    { re: new RegExp(`${boundary}${period}\\s*(?:(?:is|of)\\s+|[:=–-]\\s*)${planet}${ending}`, 'giu'), reverse: true },
  ];
  const canonical = (value: string) => periodPlanetAliases[value.normalize('NFKC').trim().toLocaleLowerCase()];
  for (const { re, reverse } of patterns) {
    for (const match of answer.normalize('NFKC').matchAll(re)) {
      const named = canonical(match[reverse ? 2 : 1]);
      const label = match[reverse ? 1 : 2].toLocaleLowerCase();
      const field = /antar|bhukti|bukthi|bhukthi|புக்தி|புத்தி|அந்தர/.test(label) ? 'antardasha' : 'mahadasha';
      const expected = facts.find(f => f.field === field);
      if (!expected || canonical(expected.value) !== named) return false;
    }
  }
  return true;
}

/** Conversation statements are untrusted user context, never chart evidence.
 * No assistant prose is accepted, so old generated claims cannot become facts. */
export function previousUserMessages(value: unknown): string[] | null {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > 6) return null;
  const result: string[] = [];
  for (const item of value) {
    if (typeof item !== 'string' || !item.trim() || [...item].length > 240 || /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/u.test(item)) return null;
    result.push(item.trim().replace(/\s+/g, ' '));
  }
  return result;
}

export function relationshipFollowup(question: string): boolean {
  return /another chance|forgive (?:him|her|them)|should i (?:do it|stay|leave)|\b(?:innoru|inoru) chance\b|மீண்டும் வாய்ப்பு|மன்னிக்கலாமா/iu.test(question);
}

/** Narrow, practical responses. These are NOT approved chart interpretations.
 * Tamil/Tanglish copy is a candidate for founder review, not language sign-off. */
export function relationshipResponse(category: string, question: string, history: string[], style: ResponseStyle): {answer: string; kind: string} | null {
  if (!['Love', 'Relationships', 'Breakup', 'Marriage', 'Daily', 'Panchang'].includes(category)) return null;
  const q = question.normalize('NFKC').toLocaleLowerCase();
  const context = relationshipFollowup(q) ? [...history, q].join('\n').toLocaleLowerCase() : q;
  const copy = (kind: string, en: string, ta: string, tanglish: string) => ({kind, answer: style === 'tamil' ? ta : style === 'tanglish' ? tanglish : en});
  if (category === 'Daily' || category === 'Panchang') {
    if ((category === 'Panchang' || /panchang|பஞ்சாங்க/u.test(q)) && /guarantee|ensure|certain|urudhi|uruthi|உறுதி/u.test(q)) return copy('panchang_limits',
      'No. Panchang describes traditional calendar factors; it cannot guarantee that your work will succeed. An auspicious label does not establish the result of a task or another person’s response.\n\nFor the work itself, check the deadline, what needs to be ready and whose help you need. Choose one concrete next step you can complete, and use actual progress to decide what to do next.',
      'இல்லை. பஞ்சாங்கம் பாரம்பரிய நாள்காட்டித் தகவல்களைக் காட்டுகிறது; உங்கள் வேலை வெற்றி பெறும் என்று உறுதிசெய்யாது. நல்ல நாள் என்ற குறிப்பை மட்டும் வைத்து வேலையின் முடிவையோ மற்றொருவரின் பதிலையோ அறிய முடியாது.\n\nவேலைக்கான காலக்கெடு, தேவையான தயாரிப்பு, யாருடைய உதவி தேவை என்பவற்றைச் சரிபாருங்கள். இப்போது செய்யக்கூடிய ஒரு சிறிய செயலைத் தேர்ந்தெடுத்து முடிக்க முயற்சி செய்யுங்கள். நடந்த முன்னேற்றத்தை வைத்து அடுத்த படியை முடிவுசெய்யலாம்.',
      'Illai. Panchangam paarambariya naalkaatti thagavalgalai kaattum; unga velai vetri perum-nu urudhi seyyaadhu. Nalla naal-ngra kurippai mattum vechu velai mudivaiyo innoruvarin badhilaiyo therinjukka mudiyaadhu.\n\nVelai deadline, thevaiyaana preparation, yaarudaiya udhavi venum-ngradha check pannunga. Ippo seiya mudiyura oru chinna step-ai choose panni mudikka muyarchi pannunga. Nadandha progress-ai vechu adutha step-ai decide pannalaam.');
    return null;
  }
  // Explicit practical requests take precedence over a generic other-person gate.
  if (/secretly|ரகசியமாக|\b(?:secret-a|secret ah|hack|spy)\b/u.test(q) && /phone|போன|password|account/u.test(q)) return copy('privacy',
    'Do not check their phone secretly. That would cross a privacy boundary, and a chart cannot establish whether they are cheating.\n\nDescribe the behaviour that worries you and ask for an honest conversation. If trust cannot be rebuilt, you can set a boundary or step away without investigating their private accounts.',
    'அவருடைய போனை ரகசியமாகப் பார்க்க வேண்டாம். அது அவருடைய தனியுரிமையை மீறும். அவர் ஏமாற்றுகிறாரா என்பதையும் ஜாதகத்தால் உறுதிசெய்ய முடியாது.\n\nஎந்தச் செயல் உங்களுக்குச் சந்தேகத்தை ஏற்படுத்தியது என்பதைச் சொல்லி நேராகப் பேசுங்கள். நம்பிக்கையை மீண்டும் உருவாக்க முடியாவிட்டால், உங்கள் வரம்புகளைத் தெளிவுபடுத்தலாம் அல்லது உறவிலிருந்து விலகலாம்.',
    'Avar phone-a ragasiyama paarka vendaam. Adhu avar privacy-ai meerum. Avar cheat panraara nu jathagathaal urudhiya solla mudiyaadhu.\n\nEndha nadathai unga sandhegathukku kaaranam nu solli neraaga pesunga. Nambikkai thirumba vara mudiyalaina, unga varambugalai sollalaam; uravilirundhu vilaguradhaiyum yosikkalaam.');
  if (/not to contact|no.contact|stop messaging|contact panna vendaam|தொடர்பு கொள்ள வேண்டாம்|பேச வேண்டாம்/u.test(context)) return copy('no_contact',
    'Respect the request for no contact; do not keep messaging or try another account. I cannot tell you that your ex will return.\n\nReconnection would need both people to want it. For now, give them space and focus on support and routines that help you recover.',
    'தொடர்பு கொள்ள வேண்டாம் என்று கேட்டிருந்தால், அதை மதியுங்கள். தொடர்ந்து செய்தி அனுப்பவோ வேறு கணக்கில் தொடர்புகொள்ளவோ வேண்டாம். அவர் திரும்ப வருவார் என்று உறுதியாகச் சொல்ல முடியாது.\n\nமீண்டும் சேர இருவருக்கும் விருப்பம் இருக்க வேண்டும். இப்போது அவருக்கு இடம் கொடுத்து, உங்களுக்கு ஆதரவாக இருக்கும் மனிதர்களுடனும் வழக்கமான வேலைகளுடனும் நேரம் செலவிடுங்கள்.',
    'Contact panna vendaam nu kettirundhaa, adhai madhiyunga. Thodarndhu message anuppavo vera account-la contact pannavo vendaam. Avar thirumba varuvaar nu urudhiya solla mudiyaadhu.\n\nThirumba sera rendu perukkum viruppam irukkanum. Ippo avarukku space kuduthu, ungalukku aarudhal tharum nanbargalum vazhakkamaana velaigalum mela gavanam seluthunga.');
  const latestClaim = relationshipFollowup(q) ? [...history, q].reverse().find(text => /cheat|admit/iu.test(text)) ?? q : q;
  const deniedOrHypothetical = /never|not admitted|did not|didn't|has not|hasn't|what if|imagine|hypothetical|did (?:he|she|they).*admit/iu.test(latestClaim);
  const admitted = !deniedOrHypothetical && /admitted (?:to )?cheating|caught .*cheating|cheat pannadhai othuk|ஏமாற்றியதை ஒப்புக்|ஏமாற்றியதாக ஒப்புக்/u.test(latestClaim);
  const referringBack = relationshipFollowup(q) && history.length > 0 && !/admitted|cheating twice|caught/iu.test(q);
  if (admitted) return copy('reported_cheating',
    `${referringBack ? 'You do not owe them another chance. You previously described admitted cheating; that context matters.' : 'You do not have to forgive because you feel pressured. Based on what you described, the admitted cheating deserves to be taken seriously.'}\n\nAny decision to continue should depend on accountability, respect for your boundaries and consistent changed behaviour—not a promise or a chart prediction. Take time and talk with someone you trust; the choice remains yours.`,
    `${referringBack ? 'மீண்டும் வாய்ப்பு கொடுக்க வேண்டிய கட்டாயம் இல்லை. முன்பு நீங்கள் சொன்ன ஏமாற்றம் இந்த முடிவில் முக்கியம்.' : 'அழுத்தத்திற்காக மன்னிக்க வேண்டிய கட்டாயம் இல்லை. நீங்கள் சொன்ன ஏமாற்றத்தை சாதாரணமாக எடுத்துக்கொள்ள வேண்டாம்.'}\n\nஉறவைத் தொடர நினைத்தால், தவறுக்குப் பொறுப்பேற்பது, உங்கள் வரம்புகளை மதிப்பது, தொடர்ந்து நடத்தை மாறுவது ஆகியவற்றைப் பாருங்கள். வாக்குறுதியையோ ஜாதகத்தையோ மட்டும் நம்பி முடிவெடுக்க வேண்டாம். நிதானமாக யோசித்து நம்பகமான ஒருவரிடம் பேசுங்கள்; முடிவு உங்களுடையது.`,
    `${referringBack ? 'Innoru chance kudukkanum nu kattaayam illai. Neenga munnaadi sonna cheating indha mudivukku mukkiyam.' : 'Pressure-kaaga mannikkavendiya kattaayam illai. Neenga sonna cheating-ai saadharanama eduthukka vendaam.'}\n\nUravai thodara ninaichaa, thappukku poruppu edukkaraaraa, unga varambugalai madhikkaraaraa, nadathai thodarndhu maarudha nu paarunga. Promise-aiyo jathagathaiyo mattum nambi mudivu edukka vendaam. Nithaanama yosichu nambagamaana oruthar kooda pesunga; mudivu ungaludaiyadhu.`);
  if (/money|panam|பணம்/u.test(q) && /love|relationship|kaadhal|காதல்|உறவு/u.test(q)) return copy('money_pressure',
    'Repeated urgent money requests are a reason to slow down, but they do not by themselves prove the relationship is fake. Do not send money under pressure or to prove your love.\n\nSay clearly that you are not willing to lend or send money. Notice whether they respect that boundary and show care when money is not involved. Their intentions cannot be established from your chart.',
    'அடிக்கடி அவசரமாகப் பணம் கேட்பதை கவனமாக எடுத்துக்கொள்ளுங்கள். அதனால் மட்டும் காதல் பொய் என்று முடிவுசெய்ய முடியாது. அழுத்தத்திற்காகவோ காதலை நிரூபிக்கவோ பணம் அனுப்ப வேண்டாம்.\n\nபணம் கொடுக்க விருப்பமில்லை என்பதைத் தெளிவாகச் சொல்லுங்கள். அந்த வரம்பை மதிக்கிறாரா, பணம் இல்லாத நேரங்களிலும் அக்கறை காட்டுகிறாரா என்பதைப் பாருங்கள். அவருடைய நோக்கத்தை உங்கள் ஜாதகத்தால் உறுதிசெய்ய முடியாது.',
    'Adikkadi urgent-a money kekkaradhu gavanikka vendiya vishayam. Adhanaala mattum love fake nu mudivu panna mudiyaadhu. Pressure-kaagavo love-ai prove pannavo panam anuppa vendaam.\n\nPanam kudukka viruppam illai nu theliva sollunga. Adhai madhikkaraaraa, panam thevai illaadha nerathilum akkarai kaattaraaraa nu paarunga. Avar nokkathai unga jathagathaal urudhi panna mudiyaadhu.');
  if (/cheat|ஏமாற்ற|phone.*hide|late night online/u.test(q)) return copy('suspected_cheating',
    'Hiding a phone or being online late does not establish cheating, and a chart cannot settle that suspicion. Your concern still deserves a clear conversation.\n\nMention the specific behaviour without making an accusation: “I have noticed this change, and it is affecting my trust. Can we talk about it?” Look for consistent actions and respect for agreed boundaries.',
    'போனை மறைப்பதோ இரவில் இணையத்தில் இருப்பதோ மட்டும் ஏமாற்றுவதை நிரூபிக்காது. ஜாதகமும் அதை உறுதிசெய்யாது. ஆனால் உங்கள் கவலையைப் பற்றி நேராகப் பேசலாம்.\n\nகுற்றம் சாட்டாமல், “இந்த மாற்றத்தை கவனித்தேன்; இது என் நம்பிக்கையை பாதிக்கிறது. இதைப் பற்றிப் பேசலாமா?” என்று கேளுங்கள். பேசுவதோடு செயலிலும் நேர்மையும் ஒப்புக்கொண்ட வரம்புகளுக்கு மதிப்பும் இருக்கிறதா என்பதைப் பாருங்கள்.',
    'Phone-a maraikkaradhum late night online-la irukkaradhum mattum cheating-ku proof illai. Jathagamum adhai urudhi pannaadhu. Aana unga kavalaiyai paththi neraaga pesalaam.\n\nKutram saattaama, “Indha maatrathai gavanichen; idhu en nambikkaiyai baadhikkudhu. Idhai paththi pesalaama?” nu kelunga. Vaarthai mattum illaama nadathaiyilum nermaiyum neenga othukkitta varambugalukku madhippum irukka nu paarunga.');
  if (/exact date|definitely marry|meet my true love|eppo.*(?:love|kaadhal)|காதல்.*எப்போது/u.test(q)) return copy('timing',
    'I cannot give you an exact date for meeting a partner or promise that you will marry. Another person’s choices cannot be guaranteed by a chart.\n\nIf you want to meet someone, focus on regular opportunities to connect and on whether your values and expectations fit. A more detailed calculation would not turn this into a certain outcome.',
    'காதல் எப்போது வரும் என்று துல்லியமான தேதியையோ திருமணம் நிச்சயம் என்ற வாக்குறுதியையோ தர முடியாது. மற்றவரின் முடிவுகளை ஜாதகம் உறுதிசெய்யாது.\n\nபுதியவர்களைச் சந்திக்க வாய்ப்புகளை உருவாக்குங்கள். உங்கள் மதிப்புகளும் எதிர்பார்ப்புகளும் ஒத்துப்போகிறதா என்பதைப் பாருங்கள். கூடுதல் கணக்கீடுகள் இருந்தாலும் முடிவு நிச்சயமாகிவிடாது.',
    'Love eppo varum nu exact date-um marriage nichayam nu promise-um kudukka mudiyaadhu. Innoruvaroda mudivai jathagam urudhi pannaadhu.\n\nPudhusa aalunga sandhikka vaaippugalai uruvaakkunga. Unga madhippugalum edhirpaarppugalum oththu pogudha nu paarunga. Kooduthal calculation irundhaalum mudivu nichayam aagidaadhu.');
  if (/long.distance/u.test(q)) return copy('communication',
    'Start with one small agreement: choose a regular time to talk, and discuss one issue at a time. Long distance can make misunderstandings harder to clear up, so agree when each of you can realistically reply.\n\nUse “I felt…” rather than accusations. If an argument gets heated, agree to pause and name a time to return to it. This is a practical communication step, not a conclusion about your compatibility from the chart.',
    'முதலில் ஒரு சிறிய ஒப்பந்தம் செய்துகொள்ளுங்கள்: பேசுவதற்கு ஒரு நேரத்தை முடிவுசெய்து, ஒரு நேரத்தில் ஒரு பிரச்சினையை மட்டும் பேசுங்கள். தொலைவில் இருக்கும்போது எப்போது பதில் தர முடியும் என்பதையும் தெளிவுபடுத்துங்கள்.\n\nகுற்றம் சாட்டுவதற்குப் பதிலாக “எனக்கு இப்படித் தோன்றியது” என்று சொல்லுங்கள். வாக்குவாதம் அதிகமானால் சிறிது இடைவெளி எடுத்துவிட்டு மீண்டும் எப்போது பேசுவது என்று முடிவுசெய்யுங்கள். இது நடைமுறை ஆலோசனை; ஜாதகப் பொருத்தத்தின் முடிவு அல்ல.',
    'Mudhalil oru chinna agreement pannunga: pesa oru neram fix panni, oru nerathil oru prachinaiyai mattum pesunga. Long distance-la eppo reply panna mudiyum nu rendu perum theliva sollikkonga.\n\nKutram saattaama “Enakku ippadi thonichu” nu sollunga. Sandai adhigamaanaal konjam break eduthu, thirumba eppo pesalaam nu mudivu pannunga. Idhu practical advice; jathaga porutham paththina mudivu illai.');
  if (/only contacts|only.*needs|genuine|பதில் தருவதில்லை|காதல் இல்லையா|mixed signals|stopped replying/u.test(q)) return copy('feelings',
    'I cannot know their feelings from your chart. What you describe is worth addressing: look for consistent, mutual care rather than words alone.\n\nAsk once, clearly, what they want from the relationship and explain what you need. Give them room to answer; if the one-sided pattern continues, you can decide what level of contact is healthy for you.',
    'அவருடைய உணர்வுகளை உங்கள் ஜாதகத்தால் தெரிந்துகொள்ள முடியாது. நீங்கள் சொன்ன மாற்றத்தைப் பற்றி பேசலாம்; வார்த்தைகளைவிட தொடர்ந்து இருவரும் காட்டும் அக்கறையைப் பாருங்கள்.\n\nஇந்த உறவில் அவருக்கு என்ன விருப்பம் என்று ஒருமுறை தெளிவாகக் கேட்டு, உங்களுக்கு என்ன தேவை என்பதையும் சொல்லுங்கள். பதில் சொல்ல இடம் கொடுங்கள். தொடர்ந்து ஒருதலைப்பட்சமாக இருந்தால், எவ்வளவு தொடர்பு உங்களுக்கு ஏற்றது என்று முடிவுசெய்யலாம்.',
    'Avar unarvugalai unga jathagathaal therinjukka mudiyaadhu. Neenga sonna maatrathai paththi pesalaam; vaarthaiyai vida rendu perum thodarndhu kaattura akkaraiyai paarunga.\n\nIndha uravil avarukku enna viruppam nu oru murai theliva kettu, ungalukku enna thevai nu sollunga. Badhil solla idam kudunga. Thodarndhu oruthar mattum muyarchi panra maadhiri irundhaa, evvalavu contact ungalukku sari nu mudivu pannalaam.');
  if (relationshipFollowup(q)) return copy('clarify',
    'What happened that makes you consider another chance? I do not have enough relationship context to weigh that decision with you.',
    'மீண்டும் வாய்ப்பு கொடுப்பதைப் பற்றி யோசிக்க என்ன நடந்தது? அந்தச் சூழல் தெரியாமல் இந்த முடிவைப் பற்றி தெளிவாகப் பேச முடியாது.',
    'Innoru chance kudukkaradhai yosikka enna nadandhuchu? Andha soozhal theriyaama indha mudivai paththi theliva pesa mudiyaadhu.');
  return null;
}
