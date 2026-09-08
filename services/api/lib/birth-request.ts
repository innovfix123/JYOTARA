/** Strict input checks before any provider request or metering write. */
export function validBirthDatetime(value: unknown, now = Date.now()): value is string {
  if (typeof value !== 'string') return false;
  const match = /^(\d{4}-\d{2}-\d{2})T([01]\d|2[0-3]):([0-5]\d):([0-5]\d)(?:\.\d{1,3})?(Z|[+-](?:0\d|1[0-4]):[0-5]\d)$/.exec(value);
  if (!match || !Number.isFinite(now)) return false;
  const zone = match[5];
  if (zone !== 'Z' && zone.slice(1, 3) === '14' && zone.slice(4) !== '00') return false;
  const midnight = Date.parse(`${match[1]}T00:00:00Z`);
  if (!Number.isFinite(midnight) || new Date(midnight).toISOString().slice(0, 10) !== match[1]) return false;
  const timestamp = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp <= now;
}

export function validChartSession(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

export function isAdultBirthDate(value: string, now = Date.now()): boolean {
  const birth = new Date(Date.parse(value) + 330 * 60_000);
  const today = new Date(now + 330 * 60_000);
  if (!Number.isFinite(birth.getTime()) || !Number.isFinite(today.getTime())) return false;
  let age = today.getUTCFullYear() - birth.getUTCFullYear();
  if (today.getUTCMonth() < birth.getUTCMonth() ||
      (today.getUTCMonth() === birth.getUTCMonth() && today.getUTCDate() < birth.getUTCDate())) age--;
  return age >= 18;
}

/** India-first unknown-time convention. The timestamp is converted to its
 * India calendar date before noon is chosen; UTC dates can differ by a day.
 * This is an explicit estimate, not a recovered exact birth time. */
export function calculationBirthDatetime(value: string, known: boolean): string {
  if (known) return value;
  const date = new Date(Date.parse(value) + 330 * 60_000).toISOString().slice(0, 10);
  return `${date}T12:00:00+05:30`;
}
