import { isValidChartFacts, type ChartFacts } from './astrology-evidence';

const aad = new TextEncoder().encode('nirayana:anonymous-chart:v1');
const lifetime = 24 * 60 * 60 * 1000;
const renewalWindow = 30 * lifetime;
const identifier = (value: unknown): value is string => typeof value === 'string' && /^[A-Za-z0-9_-]{1,128}$/.test(value);
export function chartTicketConfigured(secret: unknown): secret is string {
  return typeof secret === 'string' && /^[a-fA-F0-9]{64}$/.test(secret);
}
async function key(secret: string) {
  if (!chartTicketConfigured(secret)) throw new Error('Chart protection is not configured');
  const bytes = new Uint8Array(secret.match(/../g)!.map(v => parseInt(v, 16)));
  return crypto.subtle.importKey('raw', bytes, 'AES-GCM', false, ['encrypt', 'decrypt']);
}
function encode(bytes: Uint8Array): string {
  let text = '';
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function decode(text: string): Uint8Array<ArrayBuffer> {
  if (!/^[A-Za-z0-9_-]+$/.test(text)) throw new Error('Invalid encoding');
  const bytes = Uint8Array.from(atob(text.replace(/-/g, '+').replace(/_/g, '/')), c => c.charCodeAt(0));
  if (encode(bytes) !== text) throw new Error('Noncanonical encoding');
  return bytes;
}
export type ChartTicket = {
  version: 1; sessionId: string; profileId: string;
  issuedAt: number; expiresAt: number; birthTimeKnown: boolean; chart: ChartFacts;
  /** Provider-data age is independent of credential age; never reset on renewal. */
  providerCalculatedAt?: number;
  /** Fixed at the original issuance; renewal must never roll this forward. */
  renewalUntil?: number;
  contextLocation?: { latitude: number; longitude: number };
};
function locationValid(value: unknown) {
  if (!value || typeof value !== 'object') return false;
  const v = value as { latitude?: unknown; longitude?: unknown };
  return typeof v.latitude === 'number' && Number.isFinite(v.latitude) && Math.abs(v.latitude) <= 90 &&
    typeof v.longitude === 'number' && Number.isFinite(v.longitude) && Math.abs(v.longitude) <= 180;
}
/** Only provider-normalized server data may be passed here. This is an anonymous
 * bearer capability, not verified personal identity, login or account recovery. */
export async function issueChartTicket(secret: string, input: {
  sessionId: string; profileId: string; birthTimeKnown: boolean; chart: ChartFacts;
  contextLocation?: { latitude: number; longitude: number };
  renewalUntil?: number;
}, now = Date.now()): Promise<string> {
  const providerCalculatedAt = input.renewalUntil === undefined ? now : input.renewalUntil - renewalWindow;
  if (!identifier(input.sessionId) || !identifier(input.profileId) ||
      typeof input.birthTimeKnown !== 'boolean' || !isValidChartFacts(input.chart) ||
      !Number.isSafeInteger(now) || now < 0 || (input.contextLocation !== undefined && !locationValid(input.contextLocation)) ||
      (input.renewalUntil !== undefined && (!Number.isSafeInteger(input.renewalUntil) || input.renewalUntil < now || input.renewalUntil > now + renewalWindow)) ||
      !Number.isSafeInteger(providerCalculatedAt) || providerCalculatedAt < 0 || providerCalculatedAt > now || now - providerCalculatedAt >= lifetime) throw new Error('Invalid or stale chart ticket input');
  const payload: ChartTicket = { ...input, providerCalculatedAt, renewalUntil: input.renewalUntil ?? now + renewalWindow, version: 1, issuedAt: now, expiresAt: now + lifetime };
  const plaintext = new TextEncoder().encode(JSON.stringify(payload));
  if (plaintext.length > 100_000) throw new Error('Chart too large');
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt({ name: 'AES-GCM', iv, additionalData: aad }, await key(secret), plaintext);
  return `v1.${encode(iv)}.${encode(new Uint8Array(encrypted))}`;
}
export async function openChartTicket(secret: string, token: unknown, sessionId: string,
  profileId: unknown, now = Date.now()): Promise<ChartTicket | null> {
  return readChartTicket(secret, token, sessionId, profileId, now, false);
}

/** Expiry must not prevent erasing data. This capability is for deletion ONLY;
 * normal guidance still uses openChartTicket and enforces the 24-hour expiry. */
export async function openChartDeletionTicket(secret: string, token: unknown, sessionId: string,
  profileId: unknown, now = Date.now()): Promise<ChartTicket | null> {
  return readChartTicket(secret, token, sessionId, profileId, now, true);
}

/** Renewal is limited to the original 30-day window, including legacy tickets.
 * Keeping this fixed prevents renewal after a deletion tombstone expires. */
export async function openChartRenewalTicket(secret: string, token: unknown, sessionId: string,
  profileId: unknown, now = Date.now()): Promise<ChartTicket | null> {
  const ticket = await readChartTicket(secret, token, sessionId, profileId, now, true);
  if (!ticket || now >= (ticket.renewalUntil ?? ticket.issuedAt + renewalWindow)) return null;
  return { ...ticket, renewalUntil: ticket.renewalUntil ?? ticket.issuedAt + renewalWindow };
}

/** Current default while no longer-cache permission is recorded. Legacy
 * renewed tickets retain their original deadline, which recovers their age. */
export function chartProviderDataFresh(ticket: ChartTicket, now: number): boolean {
  const calculatedAt = ticket.providerCalculatedAt ?? (ticket.renewalUntil === undefined
    ? ticket.issuedAt : ticket.renewalUntil - renewalWindow);
  return Number.isSafeInteger(now) && Number.isSafeInteger(calculatedAt) && calculatedAt >= 0 &&
    calculatedAt <= ticket.issuedAt && calculatedAt <= now && now - calculatedAt < lifetime;
}

async function readChartTicket(secret: string, token: unknown, sessionId: string,
  profileId: unknown, now: number, allowExpired: boolean): Promise<ChartTicket | null> {
  if (!identifier(sessionId) || !identifier(profileId) || typeof token !== 'string' || token.length > 140_000 ||
      !Number.isSafeInteger(now) || now < 0) return null;
  try {
    const pieces = token.split('.');
    if (pieces.length !== 3 || pieces[0] !== 'v1') return null;
    const iv = decode(pieces[1]);
    if (iv.length !== 12) return null;
    const plaintext = await crypto.subtle.decrypt({ name: 'AES-GCM', iv, additionalData: aad }, await key(secret), decode(pieces[2]));
    const value = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(plaintext));
    if (value.version !== 1 || value.sessionId !== sessionId || value.profileId !== profileId ||
        !Number.isSafeInteger(value.issuedAt) || !Number.isSafeInteger(value.expiresAt) ||
        value.issuedAt < 0 || value.issuedAt > now || (!allowExpired && value.expiresAt <= now) || value.expiresAt - value.issuedAt !== lifetime ||
        (value.renewalUntil !== undefined && (!Number.isSafeInteger(value.renewalUntil) || value.renewalUntil < value.issuedAt || value.renewalUntil > value.issuedAt + renewalWindow)) ||
        typeof value.birthTimeKnown !== 'boolean' || !isValidChartFacts(value.chart) ||
        (value.contextLocation !== undefined && !locationValid(value.contextLocation))) return null;
    if (value.providerCalculatedAt !== undefined && (!Number.isSafeInteger(value.providerCalculatedAt) || value.providerCalculatedAt < 0 || value.providerCalculatedAt > value.issuedAt)) return null;
    if (!allowExpired && !chartProviderDataFresh(value as ChartTicket, now)) return null;
    return value as ChartTicket;
  } catch { return null; }
}
