/** Fixed-provider birthplace lookup. No caller-supplied URL or API credential. */
export async function POST(request: Request) {
  const body = await request.json().catch(() => null) as { query?: unknown } | null;
  const query = typeof body?.query === 'string' ? body.query.trim() : '';
  if (query.length < 3 || query.length > 80 || /[\u0000-\u001f]/.test(query)) {
    return Response.json({ error: 'Enter a birthplace of 3 to 80 characters.' }, { status: 400 });
  }
  const url = new URL('https://client-api.prokerala.com/v1/location/search.json');
  url.searchParams.set('q', query);
  url.searchParams.set('limit', '20');
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(10000), redirect: 'manual' });
    if (!response.ok) throw new Error('Location provider unavailable');
    const payload = await response.json() as { data?: unknown };
    if (!Array.isArray(payload.data)) throw new Error('Invalid provider response');
    const data = payload.data.filter((row: unknown) => Array.isArray(row)
      && row.length >= 8 && typeof row[1] === 'string' && typeof row[2] === 'string'
      && row[4] === 'IN' && row[5] === 'Asia/Kolkata'
      && typeof row[6] === 'number' && Number.isFinite(row[6]) && Math.abs(row[6]) <= 90
      && typeof row[7] === 'number' && Number.isFinite(row[7]) && Math.abs(row[7]) <= 180)
      .slice(0, 20).map(row => row.slice(0, 8));
    return Response.json({ data }, { headers: { 'Cache-Control': 'no-store' } });
  } catch (error) {
    // No question, query, URL, credential or provider response in diagnostics.
    console.warn('Location lookup failed', error instanceof Error ? error.name : 'UnknownError');
    return Response.json({ error: 'Place search is unavailable. Please retry; no chart was requested.' }, { status: 502 });
  }
}
