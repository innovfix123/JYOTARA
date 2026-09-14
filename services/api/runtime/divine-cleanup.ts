import {database,env} from './env';
import {deleteDivineSession} from '../lib/divine-consultation';
// Disposable conversations: only opaque IDs are queued; failures remain pending.
export async function cleanDivineSessions() {
  if(!env.DIVINE_API_KEY)return;
  const rows=await database.pool.query('SELECT id FROM divine_cleanup WHERE next_attempt_at <= $1 ORDER BY created_at LIMIT 10',[Date.now()]);
  for(const row of rows.rows) {
    await database.pool.query('UPDATE divine_cleanup SET next_attempt_at=$1 WHERE id=$2',[Date.now()+86400000,row.id]);
    if(await deleteDivineSession(env,row.id))await database.pool.query('DELETE FROM divine_cleanup WHERE id=$1',[row.id]);
    else console.warn('Astrology conversation cleanup pending');
  }
}
