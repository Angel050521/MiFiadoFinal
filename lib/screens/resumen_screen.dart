import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/movimiento.dart';
import '../models/cliente.dart';

class ResumenScreen extends StatefulWidget {
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  final _db = DatabaseHelper();
  int _totalClientes = 0;
  double _totalCargos = 0;
  double _totalAbonos = 0;

  @override
  void initState() {
    super.initState();
    _cargarResumen();
  }

  Future<void> _cargarResumen() async {
    final clientes = await _db.getClientes();
    final movimientos = <Movimiento>[];

    for (var cliente in clientes) {
      final productos = await _db.getProductosPorCliente(cliente.id!);
      for (var producto in productos) {
        final movs = await _db.getMovimientosPorProducto(producto.id!);
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

    setState(() {
      _totalClientes = clientes.length;
      _totalCargos = cargos;
      _totalAbonos = abonos;
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
