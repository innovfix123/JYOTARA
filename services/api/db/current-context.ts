import type { D1Database } from '@cloudflare/workers-types';

export type ContextLocation = { latitude: number; longitude: number };
export function validContextLocation(value: unknown): value is ContextLocation {
  if (!value || typeof value !== 'object') return false;
  const v = value as ContextLocation;
  return typeof v.latitude === 'number' && Number.isFinite(v.latitude) && Math.abs(v.latitude) <= 90 &&
    typeof v.longitude === 'number' && Number.isFinite(v.longitude) && Math.abs(v.longitude) <= 180;
}
export function indiaDay(now: number) { return new Date(now + 19_800_000).toISOString().slice(0, 10); }
export function indiaTimestamp(now: number) { return new Date(now + 19_800_000).toISOString().replace('Z', '+05:30'); }
type Module = 'transit' | 'panchang';
type Row = { status: string; payload_json: string | null; calculated_at: number; expires_at: number };
export type CurrentContext = { transitPosition: unknown; panchang: unknown; contextCalculatedAt: string; status: 'complete' | 'partial' | 'unavailable' };

export async function currentContext(db: D1Database, location: ContextLocation,
  fetchModule: (module: Module, at: string, location: ContextLocation) => Promise<unknown>, now = Date.now(), questionId?: string): Promise<CurrentContext> {
  if (!validContextLocation(location) || !Number.isSafeInteger(now) || now < 0) throw new Error('Invalid current context request');
  if (questionId && !/^[a-zA-Z0-9_-]{1,128}$/.test(questionId)) throw new Error('Invalid question context identifier');
  const day = indiaDay(now);
  const midnight = Date.parse(`${day}T00:00:00+05:30`) + 86_400_000;
  // Coordinates remain exact and server-bound. No global planet cache until
  // location invariance has been independently established for this provider.
  const place = `${location.latitude},${location.longitude}`;
  const hour = Math.floor(now / 3_600_000);
  await db.prepare('DELETE FROM current_context_cache WHERE expires_at < ?').bind(now - 30 * 86_400_000).run();
  const get = async (module: Module): Promise<{ payload: unknown; at: number } | null> => {
    const key = `drik-lahiri-en-v1:${module}:${place}:${day}:${questionId ?? (module === 'transit' ? hour : 'day')}`;
    const expiry = module === 'transit' ? Math.min((hour + 1) * 3_600_000, midnight) : midnight;
    const select = () => db.prepare('SELECT status, payload_json, calculated_at, expires_at FROM current_context_cache WHERE id = ?').bind(key).first<Row>();
    const decode = (row: Row | null) => {
      if (!row || row.status !== 'ready' || !row.payload_json || row.calculated_at > now || row.expires_at <= now) return null;
      try { return { payload: JSON.parse(row.payload_json), at: row.calculated_at }; } catch { return null; }
    };
    const existing = await select();
    if (existing) return decode(existing);
    // Durable single-use claim prevents simultaneous questions from spending
    // twice. Failures remain reserved for their window, not silently retried.
    const claim = await db.prepare(`INSERT OR IGNORE INTO current_context_cache
      (id, day_key, status, calculated_at, expires_at)
      SELECT ?, ?, 'pending', ?, ? WHERE (SELECT COUNT(*) FROM current_context_cache WHERE day_key = ?) < 120`)
      .bind(key, day, now, expiry, day).run();
    if (claim.meta.changes !== 1) return decode(await select());
    try {
      const payload = await fetchModule(module, indiaTimestamp(now), location);
      const json = JSON.stringify(payload);
      if (!json || json.length > 200_000 || !payload || typeof payload !== 'object' || !('data' in payload)) throw new Error('Invalid current context');
      await db.prepare("UPDATE current_context_cache SET status = 'ready', payload_json = ? WHERE id = ? AND status = 'pending'").bind(json, key).run();
      return { payload, at: now };
    } catch {
      await db.prepare("UPDATE current_context_cache SET status = 'unavailable' WHERE id = ? AND status = 'pending'").bind(key).run();
      return null;
    }
  };
  const [transit, panchang] = await Promise.all([get('transit'), get('panchang')]);
  return { transitPosition: transit?.payload ?? null, panchang: panchang?.payload ?? null,
    // This is the transit acquisition time, not a fabricated refresh timestamp.
    // Panchang's raw timed intervals are selected at question time downstream.
    contextCalculatedAt: new Date(transit?.at ?? now).toISOString(),
    status: transit && panchang ? 'complete' : transit || panchang ? 'partial' : 'unavailable' };
}
