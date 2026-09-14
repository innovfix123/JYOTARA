/** Retired provider: this endpoint never makes an external request. */
export async function POST() { return Response.json({error:'This audit endpoint has been retired.'},{status:410}); }
