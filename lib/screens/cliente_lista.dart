import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../utils/network_util.dart';
import '../utils/sync_helper.dart';
import 'movimientos_screen.dart';

class ClienteListaScreen extends StatefulWidget {
  const ClienteListaScreen({Key? key}) : super(key: key);

  @override
  State<ClienteListaScreen> createState() => ClienteListaScreenState();
}

class ClienteListaScreenState extends State<ClienteListaScreen> {
  final _db = DatabaseHelper.instance;
  List<Cliente> _clientes = [];
  String _busqueda = '';
  String _estadoConexion = 'Desconectado';
  String _ultimaSync = 'Nunca';
  bool _pendienteSync = false;

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
    await cargarClientes();
    await _cargarEstadoSync();
    
    // Verificar si hay cambios pendientes de sincronizar
    if (mounted) {
      final pendiente = await SyncHelper.hayPendientes();
      if (pendiente) {
        _sincronizarSiEsPosible();
      }
    }
  }

  Future<void> cargarClientes() async {
    final clientes = await _db.getClientes();
    setState(() => _clientes = clientes);
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

  Future<void> _eliminarCliente(Cliente cliente) async {
    try {
      // Asegurarse de que el ID se pase como String
      await _db.eliminarCliente(cliente.id!.toString());
      await SyncHelper.marcarPendiente();
      await _sincronizarSiEsPosible();
      await cargarClientes();
      _mostrarSnackBar('Cliente eliminado');
    } catch (e) {
      print('❌ Error al eliminar cliente: $e');
      _mostrarSnackBar('Error al eliminar el cliente');
    }
  }

  Future<bool> _sincronizarSiEsPosible() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      final token = prefs.getString('token');
      final plan = prefs.getString('plan');

      // Verificar si hay conexión a internet
      final hayConexion = await NetworkUtil.hayConexion();
      if (!hayConexion) {
        _mostrarSnackBar('❌ No hay conexión a internet');
        return false;
      }

      // Verificar credenciales
      if (userId == null || token == null) {
        _mostrarSnackBar('❌ No se encontró la sesión. Inicia sesión nuevamente.');
        // Limpiar datos de sesión
        await prefs.remove('token');
        await prefs.remove('userId');
        // Navegar a pantalla de login
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
        }
        return false;
      }

      // Verificar plan
      if (plan != 'nube100mxn' && plan != 'premium150mxn') {
        _mostrarSnackBar('❌ Tu plan no permite sincronización');
        print('⚠️ Plan actual no válido para sincronización: $plan');
        return false;
      }

      // Mostrar indicador de carga
      if (mounted) {
        setState(() {
          _estadoConexion = 'Sincronizando...';
        });
      }

      // Realizar la sincronización
      try {
        await SyncHelper.sincronizar(userId, token);
        
        // Actualizar la interfaz
        if (mounted) {
          await _cargarEstadoSync();
          _mostrarSnackBar('✅ Sincronización exitosa');
        }
        return true;
      } catch (e) {
        print('❌ Error en sincronización: $e');
        
        // Manejar errores específicos
        if (e.toString().toLowerCase().contains('no autorizado') || 
            e.toString().contains('401')) {
          _mostrarSnackBar('❌ Tu sesión ha expirado. Inicia sesión nuevamente.');
          // Limpiar datos de sesión
          await prefs.remove('token');
          await prefs.remove('userId');
          // Navegar a pantalla de login
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, '/welcome', (route) => false);
          }
        } else {
          _mostrarSnackBar('❌ Error al sincronizar: ${e.toString()}');
          if (mounted) {
            _estadoConexion = 'Error de sincronización';
          }
        }
        return false;
      } finally {
        if (mounted) {
          await _cargarEstadoSync();
          await cargarClientes();
        }
      }
    } catch (e) {
      print('❌ Error en _sincronizarSiEsPosible: $e');
      if (mounted) {
        _mostrarSnackBar('❌ Error inesperado: ${e.toString()}');
        // Recargar el estado para asegurar que la UI esté actualizada
        await _cargarEstadoSync();
      }
      return false;
    }
  }

  void _mostrarSnackBar(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: const Color(0xFF0066CC),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _mostrarDialogoRestaurar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF252A3D),
        title: const Text("¿Restaurar desde la nube?", style: TextStyle(color: Colors.white)),
        content: const Text("Esto reemplazará todos los datos actuales.", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SyncHelper.restaurarDesdeNube(context);
              await cargarClientes();
              _cargarEstadoSync();
            },
            child: const Text("Restaurar", style: TextStyle(color: Colors.redAccent)),
          )
        ],
      ),
    );
  }

  Widget _buildEstadoSyncCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252A3D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            _estadoConexion == 'Conectado' ? Icons.wifi : _estadoConexion == 'Sincronizando...' ? Icons.sync : Icons.wifi_off,
            color: _estadoConexion == 'Conectado' ? Colors.greenAccent : _estadoConexion == 'Sincronizando...' ? Colors.blueAccent : Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Estado: $_estadoConexion\nÚltima sincronización: $_ultimaSync',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          if (_pendienteSync)
            const Icon(Icons.warning, color: Colors.orangeAccent),
        ],
      ),
    );
  }

  void _mostrarOpciones(Cliente cliente) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF252A3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.redAccent),
            title: const Text('Eliminar cliente', style: TextStyle(color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _eliminarCliente(cliente);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar por nombre o teléfono
    final filtro = _busqueda.toLowerCase();
    final clientesFiltrados = _clientes.where((c) {
      final matchNombre = c.nombre.toLowerCase().contains(filtro);
      final matchTelefono = c.telefono.toLowerCase().contains(filtro);
      return matchNombre || matchTelefono;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        title: const Text('Clientes', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _mostrarDialogoRestaurar,
            icon: const Icon(Icons.cloud_download),
          ),
          IconButton(
            onPressed: _sincronizarSiEsPosible,
            tooltip: 'Sincronizar ahora',
            icon: Icon(
              _pendienteSync ? Icons.cloud_sync : Icons.cloud_done,
              color: _pendienteSync ? Colors.orangeAccent : Colors.greenAccent,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildEstadoSyncCard(),
            TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Buscar cliente',
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
              child: clientesFiltrados.isEmpty
                  ? const Center(
                child: Text(
                  "No hay clientes registrados.",
                  style: TextStyle(color: Colors.white70),
                ),
              )
                  : ListView.builder(
                itemCount: clientesFiltrados.length,
                itemBuilder: (context, index) {
                  final cliente = clientesFiltrados[index];
                  return Card(
                    color: const Color(0xFF252A3D),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 8,
                    margin: const EdgeInsets.only(bottom: 12),
                    shadowColor: Colors.black54,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0066CC),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(
                        cliente.nombre,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: cliente.telefono.isNotEmpty
                          ? Text('Tel: ${cliente.telefono}',
                          style: const TextStyle(color: Colors.white54))
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MovimientosScreen(cliente: cliente),
                          ),
                        );
                      },
                      onLongPress: () => _mostrarOpciones(cliente),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}