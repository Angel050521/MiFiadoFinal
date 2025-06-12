import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/pedido.dart';
import '../models/gasto.dart';
import '../services/nube_service.dart';
import '../utils/network_util.dart';
import '../utils/sync_helper.dart';
import 'pedido_form_screen.dart';
import 'pedido_detail_screen.dart';
import 'gasto_form_screen.dart';

class PedidosScreen extends StatefulWidget {
  const PedidosScreen({Key? key}) : super(key: key);

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  List<Gasto> _gastos = [];
  final _db = DatabaseHelper.instance;
  List<Pedido> _pedidos = [];
  String _busqueda = '';  // texto de búsqueda
  String _estadoConexion = 'Desconectado';
  String _ultimaSync = 'Nunca';
  bool _pendienteSync = false;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Recargar datos cada vez que la pantalla se vuelva a mostrar
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    await _cargarPedidos();
    await _cargarGastos();
    await _cargarEstadoSync();
    
    // Verificar si hay cambios pendientes de sincronizar
    if (mounted) {
      final pendiente = await SyncHelper.hayPendientes();
      if (pendiente) {
        _sincronizarSiEsPosible();
      }
    }
  }
  
  Future<void> _cargarEstadoSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final conectado = await NetworkUtil.hayConexion();
      final ultima = prefs.getString('last_sync') ?? 'Nunca';
      final pendiente = await SyncHelper.hayPendientes();

      if (mounted) {
        setState(() {
          _estadoConexion = conectado ? 'Conectado' : 'Desconectado';
          _ultimaSync = ultima;
          _pendienteSync = pendiente;
        });
      }
    } catch (e) {
      print('❌ Error en _cargarEstadoSync: $e');
      if (mounted) {
        _mostrarSnackBar('Error al cargar el estado de sincronización');
      }
    }
  }
  
  Future<bool> _sincronizarSiEsPosible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');

      // Verificar si hay conexión a internet
      final hayConexion = await NetworkUtil.hayConexion();
      if (!hayConexion) {
        _mostrarSnackBar('❌ No hay conexión a internet');
        return false;
      }

      if (userId == null || token == null) {
        _mostrarSnackBar('❌ No se encontró la sesión del usuario');
        return false;
      }

      setState(() => _sincronizando = true);

      // Obtener pedidos de la nube
      final resultado = await NubeService.obtenerPedidosDesdeNube(
        userId: userId,
        token: token,
      );

      if (resultado['success'] == true) {
        final List<dynamic> pedidosRemotos = resultado['pedidos'] ?? [];
        
        // Guardar pedidos en la base de datos local
        for (var pedidoData in pedidosRemotos) {
          try {
            final pedido = Pedido.fromMap(pedidoData);
            await _db.insertOrUpdatePedido(pedido);
          } catch (e) {
            print('❌ Error al guardar pedido localmente: $e');
          }
        }

        // Actualizar la lista de pedidos
        await _cargarPedidos();
        
        // Actualizar última sincronización
        final ahora = DateTime.now();
        final formatter = DateFormat('dd/MM/yyyy HH:mm');
        await prefs.setString('last_sync', formatter.format(ahora));
        
        setState(() {
          _ultimaSync = formatter.format(ahora);
          _pendienteSync = false;
        });
        
        _mostrarSnackBar('✅ Pedidos sincronizados correctamente');
        return true;
      } else {
        _mostrarSnackBar('❌ ${resultado['error'] ?? 'Error al sincronizar pedidos'}');
        return false;
      }
    } catch (e) {
      print('❌ Error en _sincronizarSiEsPosible: $e');
      _mostrarSnackBar('❌ Error al sincronizar: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() => _sincronizando = false);
      }
    }
  }
  
  void _mostrarSnackBar(String mensaje) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _cargarPedidos() async {
    final lista = await _db.getPedidos();
    setState(() => _pedidos = lista);
  }

  Future<void> _cargarGastos() async {
    final lista = await _db.getGastos();
    setState(() => _gastos = lista);
  }

  Future<void> _eliminar(String id) async {
    await _db.eliminarPedido(int.parse(id));
    await SyncHelper.marcarPendiente();
    _cargarPedidos();
    await SyncHelper.intentarSincronizar();
  }

  Future<void> _marcarHecho(Pedido p) async {
    final ahora = DateTime.now();
    final actualizado = p.copyWith(
      hecho: !p.hecho,
      fechaHecho: !p.hecho ? ahora : null,
    );
    await _db.updatePedido(actualizado);
    await SyncHelper.marcarPendiente();
    _cargarPedidos();
    await SyncHelper.intentarSincronizar();
  }

  Map<String, List<Pedido>> _groupByFecha(List<Pedido> all) {
    final now = DateTime.now();
    final estaSemana = now.add(const Duration(days: 7));
    final proximaSemana = now.add(const Duration(days: 14));

    final sinFecha = <Pedido>[];
    final vencidosHoy = <Pedido>[];
    final semana = <Pedido>[];
    final siguiente = <Pedido>[];
    final masTarde = <Pedido>[];

    for (var p in all) {
      final f = p.fechaEntrega;
      if (f == null) {
        sinFecha.add(p);
      } else if (f.isBefore(now.add(const Duration(days: 1)))) {
        vencidosHoy.add(p);
      } else if (f.isBefore(estaSemana)) {
        semana.add(p);
      } else if (f.isBefore(proximaSemana)) {
        siguiente.add(p);
      } else {
        masTarde.add(p);
      }
    }

    return {
      if (vencidosHoy.isNotEmpty) 'Hoy / Vencidos': vencidosHoy,
      if (sinFecha.isNotEmpty)    'Sin fecha': sinFecha,
      if (semana.isNotEmpty)      'Esta semana': semana,
      if (siguiente.isNotEmpty)   'Próxima semana': siguiente,
      if (masTarde.isNotEmpty)    'Más tarde': masTarde,
    };
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCard(Pedido p) {
    return InkWell(
      onTap: () async {
        final mod = await Navigator.push<Pedido?>(
          context,
          MaterialPageRoute(builder: (_) => PedidoDetailScreen(pedido: p)),
        );
        if (mod != null) {
          _cargarPedidos();
          await SyncHelper.marcarPendiente();
          await SyncHelper.intentarSincronizar();
        }
      },
      onLongPress: () => _showOptions(p),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        color: const Color(0xFF252A3D),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  p.titulo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  p.clienteNombre ?? 'Sin nombre',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _labelFecha(p.fechaEntrega),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  p.hecho ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 28,
                  color: p.hecho ? Colors.greenAccent : Colors.white54,
                ),
                onPressed: () => _marcarHecho(p),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(Pedido p) {
    showModalBottomSheet(
      backgroundColor: const Color(0xFF1B1E2F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.lightBlueAccent),
              title: const Text('Editar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => PedidoFormScreen(pedido: p)),
                ).then((ok) {
                  if (ok == true) _cargarPedidos();
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF252A3D),
                    title: const Text('Confirmar'),
                    content: const Text('¿Seguro que quieres eliminar este pedido?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _eliminar(p.id!);
                          SyncHelper.marcarPendiente();
                          SyncHelper.intentarSincronizar();
                        },
                        child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
String _labelFecha(DateTime? fecha) {
  if (fecha == null) return 'Sin fecha';
  final now = DateTime.now();

  // Solo año, mes y día
  final hoy = DateTime(now.year, now.month, now.day);
  final diaPedido = DateTime(fecha.year, fecha.month, fecha.day);

  final diff = diaPedido.difference(hoy).inDays;
  
  if (diff < 0) return 'Vencido';
  if (diff == 0) {
    // Calcular horas restantes para hoy
    final horasRestantes = fecha.difference(now).inHours;
    if (horasRestantes <= 0) {
      return 'Hoy (vencido)';
    } else if (horasRestantes == 1) {
      return 'En 1 hora';
    } else {
      return 'En $horasRestantes horas';
    }
  }
  if (diff == 1) return 'Mañana';
  return 'En $diff días';
}

  Widget _buildEstadoSyncCard() {
    return Card(
      color: const Color(0xFF252A3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _sincronizando
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _pendienteSync ? Icons.cloud_off : Icons.cloud_done,
                    color: _pendienteSync ? Colors.orangeAccent : Colors.greenAccent,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Estado: $_estadoConexion',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    'Última sincronización: $_ultimaSync',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _descargarPedidosDeNube() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF252A3D),
        title: const Text(
          "¿Restaurar pedidos desde la nube?",
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          "Esto reemplazará todos los pedidos locales actuales.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.white54),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Cierra el diálogo
              setState(() => _sincronizando = true);
              try {
                final prefs = await SharedPreferences.getInstance();
                final userId = prefs.getString('userId');
                final token = prefs.getString('token');

                if (userId == null || token == null) {
                  _mostrarSnackBar('❌ No se encontró la sesión del usuario');
                  return;
                }

                // Llama a tu servicio para obtener los pedidos de la nube
                final resultado = await NubeService.descargarPedidosYGastosDesdeNube(
                  userId: userId,
                  token: token,
                );

                if (resultado['success'] == true) {
                  // Borra todos los pedidos y gastos locales antes de restaurar
                  await _db.eliminarTodosLosPedidos();
                  await _db.eliminarTodosLosGastos();

                  final List<dynamic> pedidosRemotos = resultado['pedidos'] ?? [];
                  int pedidosRestaurados = 0;
                  for (var pedidoData in pedidosRemotos) {
                    try {
                      final pedido = Pedido.fromMap(pedidoData);
                      await _db.insertOrUpdatePedido(pedido);
                      pedidosRestaurados++;
                    } catch (e) {
                      print('❌ Error al guardar pedido localmente: $e');
                    }
                  }

                  final List<dynamic> gastosRemotos = resultado['gastos'] ?? [];
                  int gastosRestaurados = 0;
                  for (var gastoData in gastosRemotos) {
                    try {
                      final gasto = Gasto.fromMap(gastoData);
                      await _db.insertGasto(gasto);
                      gastosRestaurados++;
                    } catch (e) {
                      print('❌ Error al guardar gasto localmente: $e');
                    }
                  }

                  await _cargarPedidos();
                  _mostrarSnackBar('✅ Restaurados $pedidosRestaurados pedidos y $gastosRestaurados gastos desde la nube');
                } else {
                  _mostrarSnackBar('❌ ${resultado['error'] ?? 'Error al restaurar pedidos y gastos'}');
                }
              } catch (e) {
                print('❌ Error en _descargarPedidosDeNube: $e');
                _mostrarSnackBar('❌ Error al restaurar: $e');
              } finally {
                if (mounted) setState(() => _sincronizando = false);
                _cargarEstadoSync();
              }
            },
            child: const Text(
              "Restaurar",
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar pedidos por cliente o teléfono
    final filtro = _busqueda.toLowerCase();
    final filtrados = _pedidos.where((p) {
      final matchCliente = (p.clienteNombre ?? '').toLowerCase().contains(filtro);
      final matchTelefono = (p.clienteTelefono ?? '').toLowerCase().contains(filtro);
      return matchCliente || matchTelefono;
    }).toList();
    final pendientes = filtrados.where((p) => !p.hecho).toList();
    final secciones = _groupByFecha(pendientes);

    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: const Text('Pedidos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1B1E2F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Botón blanco para descargar pedidos de la nube
          IconButton(
            icon: const Icon(Icons.cloud_download),
            color: Colors.white,
            tooltip: 'Descargar pedidos de la nube',
            onPressed: _sincronizando ? null : _descargarPedidosDeNube,
          ),
          // Botón de sincronización (verde/naranja)
          IconButton(
            onPressed: _sincronizarSiEsPosible,
            tooltip: 'Sincronizar ahora',
            icon: _sincronizando
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    _pendienteSync ? Icons.cloud_sync : Icons.cloud_done,
                    color: _pendienteSync ? Colors.orangeAccent : Colors.greenAccent,
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEstadoSyncCard(),
            // Barra de búsqueda
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Buscar pedido',
                labelStyle: const TextStyle(color: Colors.white70),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: const Color(0xFF252A3D),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white30),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF0066CC)),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) => setState(() => _busqueda = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: secciones.isEmpty
                  ? const Center(
                child: Text(
                  'No hay pedidos registrados.',
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: secciones.keys.length,
                itemBuilder: (ctx, i) {
                  final key = secciones.keys.elementAt(i);
                  final lista = secciones[key]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(key),
                      ...lista.map(_buildCard),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 16, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Botón Agregar Gasto
            GestureDetector(
              onTap: () async {
                // Obtener el token de autenticación
                final prefs = await SharedPreferences.getInstance();
                final token = prefs.getString('token') ?? '';
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GastoFormScreen(
                      onGuardar: (gasto) async {
                        try {
                          // Insertar en la base de datos local
                          final id = await _db.insertGasto(gasto);
                          
                          // Actualizar el ID del gasto con el generado por la base de datos
                          final gastoConId = Gasto(
                            id: id.toString(),
                            concepto: gasto.concepto,
                            monto: gasto.monto,
                            fecha: gasto.fecha,
                          );
                          
                          // Sincronizar con la nube
                          await SyncHelper.sincronizarGasto(gastoConId, token);
                          
                          // Actualizar la UI
                          _cargarGastos();
                          setState(() {});
                          
                          // Mostrar mensaje de éxito
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Gasto guardado y sincronizado'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          print('❌ Error al guardar el gasto: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al guardar el gasto. Se guardará localmente.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              },
              child: Container(
                width: 180,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF0066CC),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0066CC).withOpacity(0.6),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.attach_money, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Agregar Gasto',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Botón Agregar Pedido
            GestureDetector(
              onTap: () {
                Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => const PedidoFormScreen()),
                ).then((ok) {
                  if (ok == true) _cargarPedidos();
                });
              },
              child: Container(
                width: 180,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BFFF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00BFFF).withOpacity(0.6),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Colors.white),
                    SizedBox(width: 8),
                    Text(
                      'Agregar Pedido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
