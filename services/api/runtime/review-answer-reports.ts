// Operator-only CLI; never mount this on a public HTTP route.
// Bundle with esbuild and run with the protected server environment.
import {PostgresDatabase} from './postgres';
import {openReply} from '../db/guidance-requests';

const db=new PostgresDatabase(process.env.DATABASE_URL!);
try {
  await db.pool.query('DELETE FROM answer_reports WHERE created_at<$1',[Date.now()-90*86400000]);
  const [action,id]=process.argv.slice(2);
  if(action==='show' && /^[a-f0-9]{64}$/.test(id ?? '')) {
    const row=(await db.pool.query('SELECT * FROM answer_reports WHERE id=$1',[id])).rows[0];
    if(!row)throw Error('Report not found');
    const key=process.env.JYOTARA_CHART_TICKET_KEY ?? process.env.NIRAYANA_CHART_TICKET_KEY;
    if(!key)throw Error('Report decryption key unavailable');
    console.log(JSON.stringify({id,reason:row.reason,createdAt:row.created_at,content:await openReply(key,id,row.content_ciphertext)},null,2));
  } else if(action==='reviewed' && /^[a-f0-9]{64}$/.test(id ?? '')) {
    const result=await db.pool.query('UPDATE answer_reports SET reviewed_at=$1 WHERE id=$2',[Date.now(),id]);
    console.log(JSON.stringify({updated:result.rowCount===1}));
  } else if(!action || action==='list') {
    const rows=await db.pool.query('SELECT id,reason,created_at FROM answer_reports WHERE reviewed_at IS NULL ORDER BY created_at LIMIT 100');
    console.log(JSON.stringify(rows.rows,null,2));
  } else throw Error('Use list, show <id>, or reviewed <id>');
} finally {await db.close();}
