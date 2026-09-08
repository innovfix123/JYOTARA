import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { testerIdentity } from './tester-access';

test('invitation authentication rejects absent, malformed, unknown and expired codes', () => {
  const code = 'a'.repeat(48);
  const hash = createHash('sha256').update(code).digest('hex');
  const now = Date.parse('2026-09-08T00:00:00Z');
  const expiry = '2026-09-10T00:00:00Z';
  for (const invalid of [undefined, '', 'a'.repeat(47), 'b'.repeat(48), 'A'.repeat(48)]) {
    assert.equal(testerIdentity(invalid, hash, expiry, '/api/guidance', now), null);
  }
  assert.equal(testerIdentity(code, hash, expiry, '/api/guidance', now), hash);
  assert.equal(testerIdentity(code, hash, 'invalid', '/api/guidance', now), null);
  assert.equal(testerIdentity(code, hash, expiry, '/api/guidance', Date.parse(expiry)), null);
  assert.equal(testerIdentity(code, hash, expiry, '/api/profile/delete', Date.parse(expiry)), hash);
  assert.equal(testerIdentity('b'.repeat(48), hash, expiry, '/api/profile/delete', now), null);
});
