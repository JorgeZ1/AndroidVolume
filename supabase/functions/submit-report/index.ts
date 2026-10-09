// Anonymous submission endpoint: gateway verifies the project's legacy anon JWT.
// Public keys are not user identities. They never authorize reading reports.
// Database and Storage are service-role only; a global daily quota bounds uploads.
const url = Deno.env.get('SUPABASE_URL')!;
const secret = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const headers = { apikey: secret, Authorization: `Bearer ${secret}` };
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;
const categories = ['volume', 'positioning', 'appearance', 'ads', 'crash', 'other'];
function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } });
}
async function database(path: string, body: unknown, method = 'POST') {
  const response = await fetch(`${url}/rest/v1/${path}`, {
    method, headers: { ...headers, 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify(body),
  });
  if (!response.ok) throw new Error('database');
  return response;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') return reply(405, { error: 'method' });
  if (!req.headers.get('content-type')?.startsWith('application/json')) return reply(415, { error: 'content_type' });
  // Bound the stream as well as Content-Length (chunked requests can omit it).
  const maxBody = 6 * 1024 * 1024;
  if (Number(req.headers.get('content-length')) > maxBody) return reply(413, { error: 'size' });
  const reader = req.body?.getReader();
  if (!reader) return reply(400, { error: 'body' });
  let size = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > maxBody) { await reader.cancel(); return reply(413, { error: 'size' }); }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const c of chunks) { bytes.set(c, offset); offset += c.length; }
    let data;
    try { data = JSON.parse(new TextDecoder().decode(bytes)); }
    catch { return reply(400, { error: 'json' }); }
    if (!data || typeof data !== 'object' || !uuid.test(data.id) ||
        !categories.includes(data.category) || typeof data.description !== 'string' ||
        data.description.trim().length < 10 || data.description.length > 2000 ||
        !Array.isArray(data.images) || data.images.length > 2) {
      return reply(400, { error: 'validation' });
    }
    const images: { bytes: Uint8Array; mime: string; path: string }[] = [];
    for (let i = 0; i < data.images.length; i++) {
      const image = data.images[i];
      if (!image || !['image/jpeg', 'image/png'].includes(image.mime) ||
          typeof image.data !== 'string' || image.data.length > 2796204) {
        return reply(400, { error: 'images' });
      }
      let decoded;
      try { decoded = Uint8Array.from(atob(image.data), c => c.charCodeAt(0)); }
      catch { return reply(400, { error: 'images' }); }
      const png = decoded.length > 24 && [137,80,78,71,13,10,26,10].every((v,i) => decoded[i] === v);
      const jpg = decoded.length > 4 && decoded[0] === 255 && decoded[1] === 216 && decoded[2] === 255;
      if (decoded.length > 2097152 || !(image.mime === 'image/png' ? png : jpg)) return reply(400, { error: 'images' });
      images.push({ bytes: decoded, mime: image.mime, path: `${data.id}/${i + 1}.${png ? 'png' : 'jpg'}` });
    }
    // Explicit allowlist: no arbitrary logs, account IDs, IPs or device identifiers.
    const diagnostics: Record<string, string | number> = {};
    for (const key of ['manufacturer','model','app_version','android_sdk','version_code']) {
      const v = data.diagnostics?.[key];
      if (typeof v === 'string') diagnostics[key] = v.slice(0,120);
      if (typeof v === 'number' && Number.isFinite(v)) diagnostics[key] = v;
    }
    const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)))
      .map(b => b.toString(16).padStart(2,'0')).join('');
    const reservation = await database('rpc/reserve_support_report', {
      p_id: data.id, p_hash: hash, p_category: data.category,
      p_description: data.description.trim(), p_diagnostics: diagnostics,
    });
    const state = await reservation.json();
    if (state === 'limit') return reply(429, { error: 'limit' });
    if (state === 'conflict') return reply(409, { error: 'conflict' });
    if (state !== 'pending') return reply(200, { id: data.id });
    for (const image of images) {
      const response = await fetch(`${url}/storage/v1/object/report-images/${image.path}`, {
        method: 'POST', headers: { ...headers, 'Content-Type': image.mime, 'x-upsert': 'true' },
        body: image.bytes,
      });
      if (!response.ok) throw new Error('storage');
    }
    await database(`support_reports?id=eq.${data.id}`, {
      attachment_paths: images.map(i => i.path), status: 'new',
    }, 'PATCH');
    return reply(201, { id: data.id });
  } catch {
    // Never echo server errors or user data into the response/logs.
    return reply(503, { error: 'unavailable' });
  }
});
