import { env } from './env';
import { deleteChartSession } from '../db/profile-deletion';

// Runtime-only route. server.ts authenticates the invitation and atomically
// binds/verifies ownership of this unguessable session before calling us.
// A pending request may have succeeded without delivering its chart ticket.
export async function discardPending(request: Request) {
  const session = (request.headers.get('cookie') ?? '').split(';').map(x => x.trim())
    .find(x => x.startsWith('nirayana_pilot_session='))?.slice('nirayana_pilot_session='.length);
  if (!session || !/^[A-Za-z0-9_-]{1,128}$/.test(session)) return Response.json({error:'Invalid pending session.'},{status:400});
  await deleteChartSession(env.DB, session);
  return Response.json({deleted:true,scope:'owned_pending_session'});
}
