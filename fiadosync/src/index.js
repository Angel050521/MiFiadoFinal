const DB_ID = 'da06318f-e197-4d46-9c6e-1062d6652004';
const API_KEY = '6e5d6f1e-5a1f-4c3d-9b8c-7d9e8f0a1b2c';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};

function normalizePath(path) {
  return path.replace(/\/+$/, '').trim().toLowerCase();
}

// JWT sin firma real para pruebas
function generateJWT(user) {
  const header = btoa(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = btoa(JSON.stringify({
    sub: user.id,
    email: user.email,
    plan: user.plan,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + (60 * 60 * 24 * 30)
  }));
  const signature = 'firma_segura';
  return `${header}.${payload}.${signature}`;
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    console.log("PATH RECIBIDO:", url.pathname);

    const cleanPath = normalizePath(url.pathname);

    if (request.method === 'OPTIONS') return handleOptions(request);

    const db = env.DB;
    if (!db) {
      return new Response(
        JSON.stringify({ error: 'Base de datos no configurada', details: 'Asegúrate de que el binding DB está configurado correctamente' }),
        { status: 500, headers: corsHeaders }
      );
    }

    // Inicializar la base de datos
  try {
    await initDatabase(db);
  } catch (error) {
    return new Response(
      JSON.stringify({ error: 'Error al inicializar la base de datos', details: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }

  // -------------------- RUTAS PÚBLICAS --------------------
  if ((cleanPath === '/api/usuarios' || cleanPath === '/api/auth/register') && request.method === 'POST') {
      return handleRegister(request, db);
    }
    if ((cleanPath === '/api/usuarios/login' || cleanPath === '/api/auth/login') && request.method === 'POST') {
      return handleLogin(request, db);
    }

    // -------------------- AUTENTICACIÓN PARA RUTAS PROTEGIDAS --------------------
    const authHeader = request.headers.get('Authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'No autorizado', details: 'Falta el header de autorización o es inválido' }), { status: 401, headers: corsHeaders });
    }
    const token = authHeader.split(' ')[1];
    if (token !== API_KEY) {
      try {
        const [headerB64, payloadB64, signature] = token.split(".");
        if (!headerB64 || !payloadB64 || !signature) throw new Error("Token inválido");
        const payloadJson = atob(payloadB64);
        const payload = JSON.parse(payloadJson);
      } catch (e) {
        return new Response(JSON.stringify({ error: 'No autorizado', details: 'Token JWT inválido' }), { status: 401, headers: corsHeaders });
      }
    }

    // -------------------- RUTAS PROTEGIDAS --------------------
    if (cleanPath === '/api/suscripciones' && request.method === 'POST') {
      return handleCreateSubscription(request, db);
    }
    if (cleanPath === '/api/suscripciones' && request.method === 'GET') {
      return handleGetSubscription(request, db, url);
    }
    if (cleanPath === '/api/sync') {
      if (request.method === 'POST') return handleSyncData(request, db);
      else if (request.method === 'GET') return handleGetSyncData(request, db, url);
    }
    if (cleanPath === '/api/actualizar_plan' && request.method === 'POST') {
      return handleActualizarPlan(request, db);
    }

    return new Response('Ruta no encontrada', { status: 404, headers: corsHeaders });
  }
};

// -------------------- HANDLERS --------------------

// Función para inicializar la base de datos si no existe
async function initDatabase(db) {
  try {
    // Crear tabla de pedidos si no existe
    await db.prepare(`
      CREATE TABLE IF NOT EXISTS pedidos (
        id INTEGER PRIMARY KEY,
        cliente_id INTEGER,
        titulo TEXT NOT NULL,
        descripcion TEXT,
        fecha_entrega TEXT,
        precio REAL,
        hecho INTEGER DEFAULT 0,
        fecha_hecho TEXT,
        cliente_nombre TEXT,
        cliente_telefono TEXT,
        userId INTEGER,
        createdAt TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE SET NULL
      )
    `).run();
    
    console.log('✅ Tabla de pedidos inicializada');
  } catch (error) {
    console.error('❌ Error al inicializar la base de datos:', error);
    throw error;
  }
}

async function handleRegister(request, db) {
  try {
    const data = await request.json();
    const requiredFields = ['nombre', 'email', 'password'];
    const missingFields = requiredFields.filter(field => !data[field]);
    if (missingFields.length > 0) {
      return new Response(JSON.stringify({ error: `Faltan campos requeridos: ${missingFields.join(', ')}` }), { status: 400, headers: corsHeaders });
    }
    const { results: existingUsers } = await db.prepare(`SELECT * FROM usuarios WHERE email = ?`).bind(data.email).all();
    if (existingUsers && existingUsers.length > 0) {
      return new Response(JSON.stringify({ error: 'Ya existe un usuario con este correo' }), { status: 400, headers: corsHeaders });
    }
    const { success, meta } = await db.prepare(`
      INSERT INTO usuarios (nombre, email, password, dispositivo, plan)
      VALUES (?, ?, ?, ?, 'free')
    `).bind(data.nombre, data.email.toLowerCase(), data.password, data.dispositivo || 'unknown').run();
    if (!success) throw new Error('Error al crear el usuario');
    return new Response(JSON.stringify({ success: true, message: 'Usuario registrado exitosamente', id: meta.last_row_id }), {
      status: 201,
      headers: { 'Content-Type': 'application/json', ...corsHeaders }
    });
  } catch (error) {
    console.error('Error al registrar usuario:', error);
    return new Response(JSON.stringify({ error: 'Error al registrar el usuario', details: error.message }), { status: 500, headers: corsHeaders });
  }
}

async function handleLogin(request, db) {
  try {
    const { email, password } = await request.json();
    if (!email || !password) {
      return new Response(JSON.stringify({ error: 'Email y contraseña son requeridos' }), { status: 400, headers: corsHeaders });
    }
    const { results } = await db.prepare(`SELECT id, nombre, email, plan FROM usuarios WHERE email = ? AND password = ? LIMIT 1`).bind(email.toLowerCase(), password).all();
    if (!results || results.length === 0) {
      return new Response(JSON.stringify({ error: 'Credenciales inválidas' }), { status: 401, headers: corsHeaders });
    }
    const user = results[0];
    const token = generateJWT(user);
    return new Response(JSON.stringify({
      success: true,
      id: user.id,
      nombre: user.nombre,
      email: user.email,
      plan: user.plan,
      token: token
    }), { headers: { 'Content-Type': 'application/json', ...corsHeaders } });
  } catch (error) {
    console.error('Error en login:', error.message, error.stack);
    return new Response(JSON.stringify({ error: 'Error en el inicio de sesión', details: error.message }), { status: 500, headers: corsHeaders });
  }
}

async function handleSyncData(request, db) {
  try {
    // Habilitar restricciones de clave foránea
    // Esto es necesario para que funcionen las eliminaciones en cascada
    await db.prepare('PRAGMA foreign_keys = ON').run();
    
    const data = await request.json();
    const { 
      userId, 
      clientes = [], 
      productos = [], 
      movimientos = [], 
      pedidos = [],
      deleted = { clientes: [], productos: [], movimientos: [], pedidos: [] } 
    } = data;

    if (!userId) {
      return new Response(
        JSON.stringify({ error: 'Se requiere userId' }),
        { status: 400, headers: corsHeaders }
      );
    }

    // Sincronizar CLIENTES
    for (const cliente of clientes) {
      await db.prepare(`
        INSERT INTO clientes (id, nombre, telefono, userId, correo)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          nombre = excluded.nombre,
          telefono = excluded.telefono,
          userId = excluded.userId,
          correo = excluded.correo
      `).bind(
        cliente.id ?? null,
        cliente.nombre ?? '',
        cliente.telefono ?? '',
        cliente.userId ?? userId ?? null,
        cliente.correo ?? ''
      ).run();
    }

    // Sincronizar PRODUCTOS
    for (const producto of productos) {
      await db.prepare(`
        INSERT INTO productos (id, cliente_id, nombre, descripcion, fecha_creacion, userId)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          cliente_id = excluded.cliente_id,
          nombre = excluded.nombre,
          descripcion = excluded.descripcion,
          fecha_creacion = excluded.fecha_creacion,
          userId = excluded.userId
      `).bind(
        producto.id ?? null,
        producto.cliente_id ?? null,
        producto.nombre ?? '',
        producto.descripcion ?? '',
        producto.fecha_creacion ?? '',
        producto.userId ?? userId ?? null
      ).run();
    }

    // Sincronizar MOVIMIENTOS
    for (const mov of movimientos) {
      await db.prepare(`
        INSERT INTO movimientos (id, producto_id, fecha, tipo, monto, descripcion, userId)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          producto_id = excluded.producto_id,
          fecha = excluded.fecha,
          tipo = excluded.tipo,
          monto = excluded.monto,
          descripcion = excluded.descripcion,
          userId = excluded.userId
      `).bind(
        mov.id ?? null,
        mov.producto_id ?? null,
        mov.fecha ?? '',
        mov.tipo ?? '',
        mov.monto ?? 0,
        mov.descripcion ?? '',
        mov.userId ?? userId ?? null
      ).run();
    }

    // Sincronizar PEDIDOS
    if (pedidos && pedidos.length > 0) {
      console.log(`🔄 Sincronizando ${pedidos.length} pedidos`);
      
      for (const ped of pedidos) {
        try {
          await db.prepare(`
            INSERT INTO pedidos (
              id, cliente_id, cliente_nombre, cliente_telefono, titulo, descripcion, fecha_entrega, 
              precio, hecho, fecha_hecho, userId, createdAt
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
              cliente_id = excluded.cliente_id,
              cliente_nombre = excluded.cliente_nombre,
              cliente_telefono = excluded.cliente_telefono,
              titulo = excluded.titulo,
              descripcion = excluded.descripcion,
              fecha_entrega = excluded.fecha_entrega,
              precio = excluded.precio,
              hecho = excluded.hecho,
              fecha_hecho = excluded.fecha_hecho,
              userId = excluded.userId,
              createdAt = excluded.createdAt
          `).bind(
            ped.id ?? null,
            ped.cliente_id ? parseInt(ped.cliente_id) : null,
            ped.cliente_nombre ?? '',
            ped.cliente_telefono ?? '',
            ped.titulo ?? '',
            ped.descripcion ?? '',
            ped.fecha_entrega ?? new Date().toISOString(),
            ped.precio ?? 0,
            ped.hecho ?? 0,
            ped.fecha_hecho || null,
            ped.userId ?? userId ?? null,
            ped.createdAt ?? new Date().toISOString()
          ).run();
          
          console.log(`✅ Pedido ${ped.id} sincronizado correctamente`);
        } catch (error) {
          console.error(`❌ Error al sincronizar pedido ${ped.id}:`, error);
        }
      }
    }

    // Procesar eliminaciones
    // Con ON DELETE CASCADE configurado, solo necesitamos eliminar los registros principales
    // y las eliminaciones en cascada se encargarán del resto
    console.log('🗑️  Procesando eliminaciones (con CASCADE):', JSON.stringify(deleted, null, 2));
    
    // Eliminar movimientos (si se especifican explícitamente)
    if (deleted.movimientos && deleted.movimientos.length > 0) {
      console.log(`🗑️  Eliminando ${deleted.movimientos.length} movimientos`);
      for (const id of deleted.movimientos) {
        try {
          await db.prepare('DELETE FROM movimientos WHERE id = ?')
            .bind(parseInt(id, 10))
            .run();
          console.log(`✅ Movimiento ${id} eliminado correctamente`);
        } catch (error) {
          console.error(`❌ Error al eliminar movimiento ${id}:`, error);
        }
      }
    }
    
    // Eliminar productos (si se especifican explícitamente)
    // La eliminación de un producto eliminará automáticamente sus movimientos
    if (deleted.productos && deleted.productos.length > 0) {
      console.log(`🗑️  Eliminando ${deleted.productos.length} productos (con eliminación en cascada de movimientos)`);
      for (const id of deleted.productos) {
        try {
          await db.prepare('DELETE FROM productos WHERE id = ?')
            .bind(parseInt(id, 10))
            .run();
          console.log(`✅ Producto ${id} y sus movimientos eliminados correctamente`);
        } catch (error) {
          console.error(`❌ Error al eliminar producto ${id}:`, error);
        }
      }
    }
    
    // Eliminar clientes
    // La eliminación de un cliente eliminará automáticamente sus productos y movimientos
    // gracias a ON DELETE CASCADE en las claves foráneas
    if (deleted.clientes && deleted.clientes.length > 0) {
      console.log(`🗑️  Eliminando ${deleted.clientes.length} clientes (con eliminación en cascada de productos y movimientos)`);
      for (const id of deleted.clientes) {
        try {
          const clienteId = parseInt(id, 10);
          console.log(`🗑️  Intentando eliminar cliente con ID: ${clienteId}`);
          
          // Verificar si el cliente existe antes de intentar eliminarlo
          const { results: clienteExiste } = await db.prepare('SELECT id FROM clientes WHERE id = ?')
            .bind(clienteId)
            .all();
            
          if (clienteExiste && clienteExiste.length > 0) {
            // Con ON DELETE CASCADE, solo necesitamos eliminar el cliente
            // y los registros relacionados se eliminarán automáticamente
            await db.prepare('DELETE FROM clientes WHERE id = ?')
              .bind(clienteId)
              .run();
            console.log(`✅ Cliente ${clienteId} y sus registros relacionados eliminados correctamente`);
          } else {
            console.log(`⚠️  Cliente ${clienteId} no encontrado, omitiendo...`);
          }
        } catch (error) {
          console.error(`❌ Error al eliminar cliente ${id}:`, error);
        }
      }
    }
    
    // Eliminar pedidos (si se especifican)
    if (deleted.pedidos && deleted.pedidos.length > 0) {
      console.log(`🗑️  Eliminando ${deleted.pedidos.length} pedidos`);
      for (const id of deleted.pedidos) {
        try {
          const pedidoId = parseInt(id, 10);
          console.log(`🗑️  Intentando eliminar pedido con ID: ${pedidoId}`);
          
          // Verificar si el pedido existe antes de intentar eliminarlo
          const { results: pedidoExiste } = await db.prepare('SELECT id FROM pedidos WHERE id = ?')
            .bind(pedidoId)
            .all();
            
          if (pedidoExiste && pedidoExiste.length > 0) {
            await db.prepare('DELETE FROM pedidos WHERE id = ?')
              .bind(pedidoId)
              .run();
            console.log(`✅ Pedido ${pedidoId} eliminado correctamente`);
          } else {
            console.log(`⚠️  Pedido ${pedidoId} no encontrado, omitiendo...`);
          }
        } catch (error) {
          console.error(`❌ Error al eliminar pedido ${id}:`, error);
        }
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Datos sincronizados correctamente',
        received: {
          clientes: clientes.length,
          productos: productos.length,
          movimientos: movimientos.length
        }
      }),
      { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
    );
  } catch (error) {
    console.error('Error en sync:', error);
    return new Response(
      JSON.stringify({ error: 'Error al sincronizar datos', details: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }
}

async function handleGetSyncData(request, db, url) {
  try {
    const userId = url.searchParams.get('userId');
    if (!userId) {
      return new Response(JSON.stringify({ 
        success: false,
        error: 'Se requiere userId' 
      }), { 
        status: 400, 
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders 
        } 
      });
    }

    console.log(`🔍 Buscando datos para userId: ${userId}`);
    
    // Recuperar datos con columnas específicas
    const { results: clientes = [] } = await db.prepare(`
      SELECT id, nombre, telefono, '' as correo
      FROM clientes 
    `).all();

    const { results: productos = [] } = await db.prepare(`
      SELECT 
        p.id, 
        p.nombre, 
        p.descripcion, 
        0 as precio, 
        0 as cantidad, 
        p.cliente_id as clienteId,
        '${userId}' as userId,
        p.fecha_creacion as createdAt
      FROM productos p
    `).all();

    const { results: movimientos = [] } = await db.prepare(`
      SELECT 
        m.id, 
        m.tipo, 
        m.monto, 
        m.descripcion, 
        m.fecha, 
        m.producto_id as productoId,
        p.cliente_id as clienteId,
        '${userId}' as userId,
        m.fecha as createdAt
      FROM movimientos m
      JOIN productos p ON m.producto_id = p.id
    `).all();

    // Obtener pedidos
    const { results: pedidos = [] } = await db.prepare(`
      SELECT 
        id, 
        cliente_id as clienteId,
        titulo, 
        descripcion, 
        fecha_entrega, 
        precio,
        hecho,
        fecha_hecho,
        cliente_nombre,
        cliente_telefono,
        '${userId}' as userId,
        fecha_entrega as createdAt
      FROM pedidos
      WHERE userId = ?
    `).bind(userId).all();

    console.log(`📊 Datos encontrados - Clientes: ${clientes.length}, Productos: ${productos.length}, Movimientos: ${movimientos.length}, Pedidos: ${pedidos.length}`);

    const responseData = {
      success: true,
      message: 'Datos sincronizados correctamente',
      data: {
        clientes: clientes.map(c => ({
          id: c.id,
          nombre: c.nombre || '',
          telefono: c.telefono || '',
          correo: c.correo || '',
          userId: userId,
          direccion: '' // Campo agregado para compatibilidad con el modelo en Flutter
        })),
        productos: productos.map(p => ({
          id: p.id,
          nombre: p.nombre || '',
          descripcion: p.descripcion || '',
          precio: p.precio || 0,
          cantidad: p.cantidad || 0,
          clienteId: p.clienteId,
          userId: p.userId || userId,
          createdAt: p.createdAt || new Date().toISOString()
        })),
        movimientos: movimientos.map(m => ({
          id: m.id,
          tipo: m.tipo || '',
          monto: m.monto || 0,
          descripcion: m.descripcion || '',
          fecha: m.fecha || new Date().toISOString(),
          productoId: m.productoId,
          clienteId: m.clienteId,
          userId: m.userId || userId,
          createdAt: m.createdAt || new Date().toISOString()
        })),
        pedidos: pedidos.map(ped => ({
          id: ped.id,
          cliente_id: ped.clienteId?.toString() || '',
          cliente_nombre: ped.cliente_nombre || '',
          cliente_telefono: ped.cliente_telefono || '',
          titulo: ped.titulo || '',
          descripcion: ped.descripcion || '',
          fecha_entrega: ped.fecha_entrega || new Date().toISOString(),
          precio: ped.precio || 0,
          hecho: ped.hecho || 0,
          fecha_hecho: ped.fecha_hecho || null,
          userId: ped.userId || userId,
          createdAt: ped.createdAt || new Date().toISOString()
        }))
      }
    };

    return new Response(
      JSON.stringify(responseData),
      { 
        status: 200,
        headers: { 
          'Content-Type': 'application/json',
          ...corsHeaders 
        } 
      }
    );
  } catch (error) {
    console.error('Error al obtener datos de sync:', error);
    return new Response(
      JSON.stringify({ 
        error: 'Error al obtener datos de sincronización', 
        details: error.message 
      }), 
      { 
        status: 500, 
        headers: { 
          'Content-Type': 'application/json', 
          ...corsHeaders 
        } 
      }
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
      JSON.stringify({ error: 'Error al consultar suscripciones', details: error.message }),
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

    // Asegúrate que el campo en la tabla es "id", NO "userId"
    const { success } = await db.prepare(
      'UPDATE usuarios SET plan = ? WHERE id = ?'
    ).bind(plan, userId).run();

    if (success) {
      return new Response(
        JSON.stringify({ success: true, message: 'Plan actualizado correctamente' }),
        { headers: { 'Content-Type': 'application/json', ...corsHeaders } }
      );
    } else {
      return new Response(
        JSON.stringify({ error: 'Error al actualizar el plan' }),
        { status: 500, headers: corsHeaders }
      );
    }
  } catch (error) {
    console.error('Error al actualizar plan:', error);
    return new Response(
      JSON.stringify({ error: 'Error al actualizar el plan', details: error.message }),
      { status: 500, headers: corsHeaders }
    );
  }

}

function handleOptions(request) {
  return new Response(null, { headers: corsHeaders });
}
