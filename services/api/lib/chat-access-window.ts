const day = 24 * 60 * 60 * 1000;
const clockTolerance = 5 * 60 * 1000;

/** Compatibility metadata for installed clients requiring an exact 24h span.
 * This never changes the signed ticket, ownership, or server-side expiry.
 * End early to accommodate modest phone clock skew; clip at the true expiry.
 */
export function chatAccessWindow(now: number, expiresAt: number) {
  if (!Number.isFinite(now) || !Number.isFinite(expiresAt) || expiresAt <= now) {
    throw new Error('Chat access has expired');
  }
  const end = Math.min(expiresAt, now + day - clockTolerance);
  return {chatAuthorizedAt: new Date(end - day).toISOString(),
    chatExpiresAt: new Date(end).toISOString()};
}
