// ID de tu base de datos D1
const DB_ID = 'da06318f-e197-4d46-9c6e-1062d6652004';

// Tu API key (debe coincidir con la de tu app Flutter)
const API_KEY = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

// Función para limpiar el path (quita slash final, espacios, lowercase)
function normalizePath(path) {
  return path.replace(/\/+$/, '').trim().toLowerCase();
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    // LOG DE DEBUG para saber qué path llega
    console.log("PATH RECIBIDO:", url.pathname);

    const cleanPath = normalizePath(url.pathname);

    // Manejar CORS (preflight)
    if (request.method === 'OPTIONS') {
      return handleOptions(request);
    }

    // Obtener la instancia de la base de datos
    const db = env[DB_ID];
    if (!db) {
      return new Response(
        JSON.stringify({ error: 'Base de datos no configurada' }),
        { status: 500, headers: corsHeaders }
      );
    }

    // -------------------- RUTAS PÚBLICAS --------------------
    if (
      (cleanPath === '/api/usuarios' || cleanPath === '/api/auth/register')
      && request.method === 'POST'
    ) {
      return handleRegister(request, db);
    }
    if (
      (cleanPath === '/api/usuarios/login' || cleanPath === '/api/auth/login')
      && request.method === 'POST'
    ) {
      return handleLogin(request, db);
    }

    // -------------------- AUTENTICACIÓN PARA RUTAS PROTEGIDAS --------------------
    const authHeader = request.headers.get('Authorization');
    const apiKey = authHeader?.split(' ')[1];
    if (apiKey !== API_KEY) {
      return new Response(
        JSON.stringify({
          error: 'No autorizado',
          details: 'Falta el header de autorización o es inválido'
        }),
        { status: 401, headers: corsHeaders }
      );
    }

    // -------------------- RUTAS PROTEGIDAS --------------------
    if (cleanPath === '/api/suscripciones' && request.method === 'POST') {
      return handleCreateSubscription(request, db);
    }
    if (cleanPath === '/api/suscripciones' && request.method === 'GET') {
      return handleGetSubscription(request, db, url);
    }
    
    // Nuevo endpoint para actualizar el plan
    if (cleanPath === '/api/actualizar_plan' && request.method === 'POST') {
      return handleActualizarPlan(request, db);
    }

    return new Response('Ruta no encontrada', { status: 404, headers: corsHeaders });
  }
};

// -------------------- HANDLERS --------------------

async function handleRegister(request, db) {
  try {
    const data = await request.json();

    const requiredFields = ['nombre', 'email', 'password'];
    const missingFields = requiredFields.filter(field => !data[field]);
    if (missingFields.length > 0) {
      return new Response(
        JSON.stringify({ error: `Faltan campos requeridos: ${missingFields.join(', ')}` }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { results: existingUsers } = await db.prepare(`
      SELECT * FROM usuarios WHERE email = ?
    `).bind(data.email).all();

    if (existingUsers && existingUsers.length > 0) {
      return new Response(
        JSON.stringify({ error: 'Ya existe un usuario con este correo' }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { success, meta } = await db.prepare(`
      INSERT INTO usuarios (nombre, email, password, dispositivo, plan)
      VALUES (?, ?, ?, ?, 'free')
    `).bind(
      data.nombre,
      data.email.toLowerCase(),
      data.password,
      data.dispositivo || 'unknown'
    ).run();

    if (!success) {
      throw new Error('Error al crear el usuario');
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Usuario registrado exitosamente',
        id: meta.last_row_id
      }),
      {
        status: 201,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      }
    );
  } catch (error) {
    console.error('Error al registrar usuario:', error);
    return new Response(
      JSON.stringify({
        error: 'Error al registrar el usuario',
        details: error.message
      }),
      { status: 500, headers: corsHeaders }
    );
  }
}

async function handleLogin(request, db) {
  try {
    const { email, password } = await request.json();

    if (!email || !password) {
      return new Response(
        JSON.stringify({ error: 'Email y contraseña son requeridos' }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { results } = await db.prepare(`
      SELECT id, nombre, email, plan FROM usuarios 
      WHERE email = ? AND password = ?
      LIMIT 1
    `).bind(email.toLowerCase(), password).all();

    if (!results || results.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Credenciales inválidas' }),
        { status: 401, headers: corsHeaders }
      );
    }

    const user = results[0];
    return new Response(
      JSON.stringify({
        success: true,
        id: user.id,
        nombre: user.nombre,
        email: user.email,
        plan: user.plan
      }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (error) {
    console.error('Error en login:', error);
    return new Response(
      JSON.stringify({ error: 'Error en el inicio de sesión' }),
      { status: 500, headers: corsHeaders }
    );
  }
}

async function handleCreateSubscription(request, db) {
  try {
    const data = await request.json();

    const requiredFields = ['plan', 'fechaInicio', 'fechaVencimiento', 'estado'];
    const missingFields = requiredFields.filter(field => !data[field]);
    if (missingFields.length > 0) {
      return new Response(
        JSON.stringify({ error: `Faltan campos requeridos: ${missingFields.join(', ')}` }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { success } = await db.prepare(`
      INSERT INTO suscripciones (
        plan, fechaInicio, fechaVencimiento, estado,
        tokenPago, idUsuario, email, dispositivo
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `).bind(
      data.plan,
      data.fechaInicio,
      data.fechaVencimiento,
      data.estado,
      data.tokenPago || null,
      data.idUsuario || null,
      data.email || null,
      data.dispositivo || 'unknown'
    ).run();

    return new Response(
      JSON.stringify({
        success,
        message: success ? 'Suscripción guardada' : 'Error al guardar'
      }),
      {
        status: success ? 201 : 500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders }
      }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        error: 'Error interno del servidor',
        details: error.message
      }),
      { status: 500, headers: corsHeaders }
    );
  }
}

async function handleGetSubscription(request, db, url) {
  try {
    const userId = url.searchParams.get('userId');
    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Se requiere el parámetro userId' }),
        { status: 400, headers: corsHeaders }
      );
    }

    const { results } = await db.prepare(`
      SELECT * FROM suscripciones 
      WHERE idUsuario = ? 
      ORDER BY fechaVencimiento DESC
      LIMIT 1
    `).bind(userId).all();

    return new Response(
      JSON.stringify(results),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: 'Error al consultar suscripciones' }),
      { status: 500, headers: corsHeaders }
    );
  }
}

async function handleActualizarPlan(request, db) {
  try {
    const { userId, plan } = await request.json();
    
    if (!userId || !plan) {
      return new Response(
        JSON.stringify({ error: 'Se requieren userId y plan' }),
        { status: 400, headers: corsHeaders }
      );
    }
    
    // Actualizar el plan en la tabla de usuarios
    const { success } = await db.prepare(`
      UPDATE usuarios 
      SET plan = ? 
      WHERE id = ?
    `).bind(plan, userId).run();
    
    if (!success) {
      throw new Error('Error al actualizar el plan');
    }
    
    return new Response(
      JSON.stringify({ success: true, message: 'Plan actualizado correctamente' }),
      { status: 200, headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
    
  } catch (error) {
    console.error('Error al actualizar plan:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Error al actualizar el plan',
        details: error.message 
      }),
      { status: 500, headers: corsHeaders }
    );
  }
}

function handleOptions(request) {
  return new Response(null, {
    headers: corsHeaders
  });
}
