export default {
  async fetch(request, env, ctx) {
    const { method, url } = request;
    const { pathname, searchParams } = new URL(url);
    const auth = request.headers.get('Authorization');

    if (!auth || !auth.startsWith('Bearer ')) {
      return new Response('Missing or invalid Authorization header', { status: 401 });
    }

    const token = auth.replace('Bearer ', '').trim();
    if (!/^[a-zA-Z0-9_-]{4,32}$/.test(token)) {
      return new Response('Invalid token format', { status: 403 });
    }

    // === TESTEO: Ver si D1 está conectada ===
    if (method === 'GET' && pathname === '/d1-test') {
      try {
        const result = await env.DB.prepare("SELECT name FROM sqlite_master WHERE type='table';").all();
        return new Response(JSON.stringify(result), {
          headers: { "Content-Type": "application/json" },
        });
      } catch (e) {
        return new Response(`❌ Error ejecutando consulta: ${e}`, { status: 500 });
      }
    }

    // ========== POST /upload (a KV) ==========
    if (method === 'POST' && pathname === '/upload') {
      let body;
      try {
        body = await request.json();
      } catch {
        return new Response('Invalid JSON body', { status: 400 });
      }

      const { userId, clientes, productos, movimientos } = body;

      if (!userId || !Array.isArray(clientes) || !Array.isArray(productos) || !Array.isArray(movimientos)) {
        return new Response('Missing or invalid payload fields', { status: 400 });
      }

      const timestamp = new Date().toISOString();
      const dataToStore = JSON.stringify({
        clientes,
        productos,
        movimientos,
        sincronizado_en: timestamp,
      });

      await env.SYNC_DATA.put(`user:${userId}`, dataToStore);

      return new Response(`Datos sincronizados correctamente a las ${timestamp}`, {
        status: 200,
        headers: { 'Content-Type': 'text/plain' },
      });
    }

    // ========== GET /download ==========
    if (method === 'GET' && pathname === '/download') {
      const userId = searchParams.get('userId');
      if (!userId) {
        return new Response('Missing userId in query', { status: 400 });
      }

      const data = await env.SYNC_DATA.get(`user:${userId}`);
      if (!data) {
        return new Response('No data found for user', { status: 404 });
      }

      return new Response(data, {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // ========== POST /validar_device ==========
    if (method === 'POST' && pathname === '/validar_device') {
      let body;
      try {
        body = await request.json();
      } catch {
        return new Response('Invalid JSON', { status: 400 });
      }

      const { userId, deviceId } = body;

      if (!userId || !deviceId) {
        return new Response('Faltan userId o deviceId', { status: 400 });
      }

      const actual = await env.SYNC_DATA.get(`device:${userId}`);
      const permitido = !actual || actual === deviceId;

      return new Response(JSON.stringify({ permitido }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // ========== POST /actualizar_device ==========
    if (method === 'POST' && pathname === '/actualizar_device') {
      let body;
      try {
        body = await request.json();
      } catch {
        return new Response('Invalid JSON', { status: 400 });
      }

      const { userId, deviceId } = body;

      if (!userId || !deviceId) {
        return new Response('Faltan userId o deviceId', { status: 400 });
      }

      await env.SYNC_DATA.put(`device:${userId}`, deviceId);

      return new Response('Device actualizado', { status: 200 });
    }

    return new Response('Not Found', { status: 404 });
  }
};
