import {spawn} from 'node:child_process';
/** Provider PDF only; never invoke a shell or accept a caller file path. */
export async function extractReportPdf(bytes:Uint8Array):Promise<string> {
  if(bytes.length>5_000_000||new TextDecoder().decode(bytes.slice(0,5))!=='%PDF-')throw Error('Invalid report PDF');
  return new Promise((resolve,reject)=>{
    const child=spawn('/usr/bin/pdftotext',['-layout','-','-'],{stdio:['pipe','pipe','ignore']});
    const chunks:Buffer[]=[];let size=0;
    const timer=setTimeout(()=>{child.kill();reject(Error('Report extraction timed out'));},8000);
    child.stdout.on('data',(b:Buffer)=>{size+=b.length;if(size>200000){child.kill();reject(Error('Report text too large'));}else chunks.push(b);});
    child.on('error',()=>{clearTimeout(timer);reject(Error('Report extraction unavailable'));});
    child.on('close',code=>{clearTimeout(timer);code===0?resolve(Buffer.concat(chunks).toString('utf8')):reject(Error('Report extraction failed'));});
    child.stdin.on('error',()=>{});child.stdin.end(bytes);
  });
}
