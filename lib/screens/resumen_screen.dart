import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/movimiento.dart';
import '../models/cliente.dart';
import '../models/gasto.dart';

class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  final _db = DatabaseHelper.instance;
  int _totalClientes = 0;
  double _totalCargos = 0;
  double _totalAbonos = 0;

  // NUEVO: variables para la card de pedidos
  int _totalPedidosMes = 0;
  int _pedidosPendientes = 0;
  double _gananciasBrutas = 0;

  // GASTOS
  double _totalGastos = 0;
  double _gananciasNetas = 0;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    final clientes = await _db.getClientes();
    final movimientos = <Movimiento>[];

    for (var cliente in clientes) {
      final productos = await _db.getProductosPorCliente(int.parse(cliente.id!));
      for (var producto in productos) {
        final movs = await _db.getMovimientosPorProducto(int.parse(producto.id!));
        movimientos.addAll(movs);
      }
    }

    double cargos = 0;
    double abonos = 0;
    for (var m in movimientos) {
      if (m.tipo == 'cargo') {
        cargos += m.monto;
      } else {
        abonos += m.monto;
      }
    }

    // --- Pedidos: cálculo de métricas ---
    final pedidos = await _db.getAllPedidos();
    final now = DateTime.now();
    final primerDiaMes = DateTime(now.year, now.month, 1);

    int totalMes = 0;
    int pendientes = 0;
    double ganancias = 0;

    for (var p in pedidos) {
      // Total del mes: pedidos marcados como hechos en el mes actual
      if (p.hecho && p.fechaHecho != null) {
        final fecha = p.fechaHecho!;
        if (!fecha.isBefore(primerDiaMes) && !fecha.isAfter(now)) {
          totalMes++;
        }
      }
      // Pendientes
      if (!p.hecho) pendientes++;
      // Ganancias brutas (solo pedidos hechos)
      if (p.hecho && p.precio != null) {
        ganancias += p.precio!;
      }
    }

    // --- Gastos del mes ---
    final gastosMes = await _db.getGastosDelMes(now);
    double totalGastos = 0;
    for (var g in gastosMes) {
      totalGastos += g.monto;
    }
    double gananciasNetas = ganancias - totalGastos;

    setState(() {
      _totalClientes = clientes.length;
      _totalCargos = cargos;
      _totalAbonos = abonos;
      // NUEVO
      _totalPedidosMes = totalMes;
      _pedidosPendientes = pendientes;
      _gananciasBrutas = ganancias;
      _totalGastos = totalGastos;
      _gananciasNetas = gananciasNetas;
    });
  }

  @override
  Widget build(BuildContext context) {
    final deudaTotal = _totalCargos - _totalAbonos;
    final saldoPromedio = _totalClientes > 0 ? deudaTotal / _totalClientes : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        title: const Text('Resumen'),
        backgroundColor: const Color(0xFF1B1E2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            _buildCard(
              title: "Resumen General de Deudas y Pedidos",
              children: [
                _buildItem("🔢 Total de clientes registrados", _totalClientes.toString()),
                _buildItem("💰 Total de deuda acumulada", "\$${deudaTotal.toStringAsFixed(2)}"),
                _buildItem("💸 Total de abonos realizados", "\$${_totalAbonos.toStringAsFixed(2)}"),
                _buildItem("📈 Saldo promedio por cliente", "\$${saldoPromedio.toStringAsFixed(2)}"),
              ],
            ),
            const SizedBox(height: 24),
            _buildCard(
              title: "Pedidos (mes actual)",
              children: [
                _buildItem("📦 Total pedidos del mes", _totalPedidosMes.toString()),
                _buildItem("⏳ Pedidos pendientes", _pedidosPendientes.toString()),
                _buildItem("💵 Ganancias brutas", "\$${_gananciasBrutas.toStringAsFixed(2)}"),
                _buildItem("🧾 Total gastos del mes", "\$${_totalGastos.toStringAsFixed(2)}"),
                _buildItem("💰 Ganancias netas", "\$${_gananciasNetas.toStringAsFixed(2)}"),
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      color: const Color(0xFF252A3D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                )),
            const Divider(color: Colors.white30),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }
}
