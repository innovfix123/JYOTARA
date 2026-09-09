import type { ChartFacts } from './astrology-evidence';

export const profileOverviewQuestion = 'Show the selected profile rasi, nakshatra and current Saturn status.';
export function saturnQuestion(question:string) {
  return /sade[ -]?sati|ezharai|elra shani|elarai|ஏழரை|ஏழர[ைெ]|7[ .-]*1\/2|seven.and.a.half/i.test(question);
}
const signs=['Mesha','Vrishabha','Mithuna','Karka','Simha','Kanya','Tula','Vrischika','Dhanu','Makara','Kumbha','Meena'];
const tamil=['மேஷம்','ரிஷபம்','மிதுனம்','கடகம்','சிம்மம்','கன்னி','துலாம்','விருச்சிகம்','தனுசு','மகரம்','கும்பம்','மீனம்'];
export function saturnStatus(chart:ChartFacts,known:boolean,now=Date.now()) {
  const moon=chart.planets.find(p=>p.name.toLowerCase()==='moon')?.position ?? signs.indexOf(chart.rashi ?? '')+1;
  const saturn=chart.transits?.find(p=>p.name.toLowerCase()==='saturn')?.position;
  const stamp=Date.parse(chart.contextCalculatedAt??'');
  if(!known || !Number.isInteger(moon) || moon<1 || moon>12 || !saturn || saturn<1 || saturn>12 || !Number.isFinite(stamp) || now-stamp>2*3600000 || stamp>now+60000) return {state:'unknown' as const};
  const house=(saturn-moon+12)%12+1;
  return {state:house===12?'rising' as const:house===1?'middle' as const:house===2?'setting' as const:'inactive' as const,house,saturnSign:signs[saturn-1],calculatedAt:chart.contextCalculatedAt};
}
export function profileOverview(chart:ChartFacts,known:boolean,style:string,now=Date.now()) {
  const ta=style==='tamil',tg=style==='tanglish';
  const sign=ta?(tamil[signs.indexOf(chart.rashi??'')]??chart.rashi):chart.rashi;
  const identity=ta?`உங்கள் ராசி ${sign??'இன்னும் கிடைக்கவில்லை'}; நட்சத்திரம் ${chart.nakshatra??'இன்னும் கிடைக்கவில்லை'}.`:tg?`Unga rasi ${sign??'innum kidaikkala'}, natchathiram ${chart.nakshatra??'innum kidaikkala'}.`:`Your rasi is ${sign??'unavailable'} and your nakshatra is ${chart.nakshatra??'unavailable'}.`;
  if(!known) return identity+' '+(ta?'பிறந்த நேரம் தெரியாததால் இவை நண்பகல் கணக்கின் தோராயமான விவரங்கள். ஏழரை சனி நிலையை உறுதியாகக் கூற முடியாது. இப்போது எதைப் பற்றிப் பார்க்க விரும்புகிறீர்கள்?':tg?'Birth time theriyadhadhaal idhu noon kanakku; rasi, natchathiram maaralaam. Ezharai Sani nilaiyai urudhiya solla mudiyadhu. Ippo edha pathi paarkalaam?':'These are provisional noon-chart details because birth time is unknown. Sade Sati status is unconfirmed. What would you like to discuss?');
  const status=saturnStatus(chart,known,now);
  const phase={rising:['தொடக்க நிலை','aaramba nilai','opening phase'],middle:['நடு நிலை','nadu nilai','middle phase'],setting:['இறுதி நிலை','irudhi nilai','closing phase']} as const;
  const line=status.state==='unknown'?(ta?'நடப்பு சனி நிலை இப்போது கிடைக்கவில்லை.':tg?'Nadappu Sani nilai ippo kidaikkala.':'Current Saturn status is unavailable right now.'):
    status.state==='inactive'?(ta?'தற்போதைய சனி பெயர்ச்சிப்படி ஏழரை சனி நடப்பில் இல்லை.':tg?'Ippodhaya Sani peyarchipadi Ezharai Sani nadappil illai.':'The current Saturn transit is outside Sade Sati.'):
    ta?`தற்போதைய சனி பெயர்ச்சிப்படி ஏழரை சனியின் ${phase[status.state][0]} நடக்கிறது. இது கஷ்டம் கட்டாயம் வரும் என்று பொருளல்ல.`:tg?`Ippodhaya Sani peyarchipadi Ezharai Sani ${phase[status.state][1]} nadakkudhu. Idhanaala kashtam kandippa varumnu artham illa.`:`The current Saturn transit places you in the ${phase[status.state][2]} of Sade Sati. This does not mean hardship is inevitable.`;
  return identity+' '+line+' '+(ta?'இப்போது எதைப் பற்றிப் பார்க்க விரும்புகிறீர்கள்?':tg?'Ippo edha pathi paarkalaam?':'What would you like to discuss?');
}
