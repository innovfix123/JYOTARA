import places from '@/data/india-places.json';
const fold=(v:string)=>v.normalize('NFKD').replace(/[\u0300-\u036f]/g,'').toLowerCase().trim();
const index=places.map(row=>({row,name:fold(String(row[1])),search:fold(`${row[1]},${row[2]},${row[3]},${row[7]}`),aliases:String(row[7]).split(',').map(fold)}));
/** Local GeoNames index: no third-party requests or astrology credits. */
export async function POST(request:Request) {
  const body=await request.json().catch(()=>null) as {query?:unknown}|null;
  const query=typeof body?.query==='string'?body.query.trim():'';
  if(query.length<3||query.length>80||/[\u0000-\u001f]/.test(query))return Response.json({error:'Enter a birthplace of 3 to 80 characters.'},{status:400});
  const q=fold(query),tokens=q.split(/[,\s]+/).filter(Boolean);
  const matches=index.filter(x=>tokens.every(t=>x.search.includes(t))).sort((a,b)=>{
    const rank=(x:typeof a)=>x.name===q||x.aliases.includes(q)?0:x.name.startsWith(q)?1:2;
    return rank(a)-rank(b)||Number(b.row[6])-Number(a.row[6]);
  });
  const data=matches.slice(0,20).map(({row:r})=>[r[0],r[1],r[2],'India','IN','Asia/Kolkata',r[4],r[5]]);
  return Response.json({data,attribution:'GeoNames · CC BY 4.0',attributionUrl:'https://www.geonames.org/'},{headers:{'Cache-Control':'no-store'}});
}
