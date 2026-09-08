import { loadChartSnapshot, type ChartDatabase } from '../db/chart-snapshots';
import { buildEvidencePacket, type GuidanceCategory } from './astrology-evidence';

/** Identity must be obtained by verifying a credential at the HTTP boundary.
 * This service never accepts an owner, chart, date or birth-time override from
 * the question body. Auth integration remains an explicit caller obligation. */
export async function buildOwnedGuidance(input: {
  db: ChartDatabase;
  verifiedOwnerId: string | null;
  profileId: string;
  snapshotId: string;
  category: GuidanceCategory;
  question: string;
  language: string;
  now?: Date;
}) {
  if (!input.verifiedOwnerId) return { ok: false as const, status: 401 as const };
  const snapshot = await loadChartSnapshot(input.db, {
    ownerId: input.verifiedOwnerId, profileId: input.profileId,
  }, input.snapshotId);
  // Same response for an absent snapshot and someone else's snapshot.
  if (!snapshot) return { ok: false as const, status: 404 as const };
  const now = input.now ?? new Date();
  if (!Number.isFinite(now.getTime()) || snapshot.createdAt > now.getTime() ||
      now.getTime() - snapshot.createdAt >= 86_400_000) return { ok: false as const, status: 409 as const };
  return { ok: true as const, snapshotId: snapshot.id, packet: buildEvidencePacket({
    category: input.category, question: input.question, language: input.language,
    chart: snapshot.chart, birthTimeKnown: snapshot.birthTimeKnown, now,
  }) };
}
