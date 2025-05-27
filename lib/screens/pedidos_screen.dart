import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/pedido.dart';
import '../models/gasto.dart';
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

  final _db = DatabaseHelper();
  List<Pedido> _pedidos = [];
  String _busqueda = '';  // texto de búsqueda

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
    _cargarGastos();
  }

  Future<void> _cargarPedidos() async {
    final lista = await _db.getPedidos();
    setState(() => _pedidos = lista);
  }

  Future<void> _cargarGastos() async {
    final lista = await _db.getGastos();
    setState(() => _gastos = lista);
  }

  Future<void> _eliminar(int id) async {
    await _db.eliminarPedido(id);
    _cargarPedidos();
  }

  Future<void> _marcarHecho(Pedido p) async {
    await _db.updatePedido(p.copyWith(hecho: !p.hecho));
    _cargarPedidos();
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
        if (mod != null) _cargarPedidos();
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
                  p.cliente,
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
    final diff = fecha.difference(now).inDays;
    if (diff < 0) return 'Vencido';
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Mañana';
    return 'En $diff días';
  }

  @override
  Widget build(BuildContext context) {
    // Filtrar pedidos por cliente o teléfono
    final filtro = _busqueda.toLowerCase();
    final filtrados = _pedidos.where((p) {
      final matchCliente = p.cliente.toLowerCase().contains(filtro);
      final matchTelefono = (p.telefono ?? '').toLowerCase().contains(filtro);
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'gasto',
            backgroundColor: const Color(0xFF0066CC),
            icon: const Icon(Icons.attach_money),
            label: const Text('Agregar gasto'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GastoFormScreen(
                    onGuardar: (gasto) async {
                      await _db.insertGasto(gasto);
                      _cargarGastos();
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'pedido',
            backgroundColor: const Color(0xFF00BFFF),
            child: const Icon(Icons.add, size: 32),
            onPressed: () {
              Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PedidoFormScreen()),
              ).then((ok) {
                if (ok == true) _cargarPedidos();
              });
            },
          ),
        ],
      ),
    );
  }
}