import { isValidChartFacts, type ChartFacts } from '../lib/astrology-evidence';

// The caller supplies a verified identity, not body fields. Kept independent
// of runtime globals so the actual SQL can be exercised against local SQLite.
type Statement = {
  bind(...values: unknown[]): Statement;
  run(): Promise<unknown>;
  first<T>(): Promise<T | null>;
};
export type ChartDatabase = { prepare(sql: string): Statement };
export type ChartIdentity = { ownerId: string; profileId: string };
const validId = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
const validIdentity = (identity: ChartIdentity) => validId(identity.ownerId) && validId(identity.profileId);

export async function saveChartSnapshot(db: ChartDatabase, identity: ChartIdentity,
  chart: ChartFacts, birthTimeKnown: boolean, now = Date.now()): Promise<string> {
  if (!validIdentity(identity) || !isValidChartFacts(chart) || typeof birthTimeKnown !== 'boolean' || !Number.isSafeInteger(now) || now < 0) throw new Error('Invalid chart snapshot');
  const factsJson = JSON.stringify(chart);
  if (factsJson.length > 100_000) throw new Error('Chart snapshot too large');
  const id = crypto.randomUUID();
  await db.prepare('INSERT INTO birth_chart_snapshots (id, owner_id, profile_id, facts_json, birth_time_known, created_at) VALUES (?, ?, ?, ?, ?, ?)')
    .bind(id, identity.ownerId, identity.profileId, factsJson, birthTimeKnown ? 1 : 0, now).run();
  return id;
}

export async function loadChartSnapshot(db: ChartDatabase, identity: ChartIdentity, id: string) {
  if (!validIdentity(identity) || !validId(id)) return null;
  const row = await db.prepare('SELECT facts_json AS factsJson, birth_time_known AS birthTimeKnown, created_at AS createdAt FROM birth_chart_snapshots WHERE id = ? AND owner_id = ? AND profile_id = ?')
    .bind(id, identity.ownerId, identity.profileId).first<{ factsJson: string; birthTimeKnown: number; createdAt: number }>();
  if (!row) return null;
  try {
    const chart: unknown = JSON.parse(row.factsJson);
    if (!isValidChartFacts(chart) || ![0, 1].includes(row.birthTimeKnown) || !Number.isSafeInteger(row.createdAt)) return null;
    return { id, chart, birthTimeKnown: row.birthTimeKnown === 1, createdAt: row.createdAt };
  } catch { return null; }
}

export async function deleteProfileSnapshots(db: ChartDatabase, identity: ChartIdentity) {
  if (!validIdentity(identity)) throw new Error('Invalid profile identity');
  await db.prepare('DELETE FROM birth_chart_snapshots WHERE owner_id = ? AND profile_id = ?')
    .bind(identity.ownerId, identity.profileId).run();
}
