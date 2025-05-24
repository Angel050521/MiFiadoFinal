import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:printing/printing.dart';
import '../db/database_helper.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';
import '../utils/sync_helper.dart';
import '../utils/pdf_generator.dart';
import '../widgets/producto_selector.dart';
import '../widgets/movimiento_list.dart';
import '../widgets/movimiento_form.dart';
import '../widgets/vista_global.dart';

class MovimientosScreen extends StatefulWidget {
  final Cliente cliente;

  const MovimientosScreen({super.key, required this.cliente});

  @override
  State<MovimientosScreen> createState() => _MovimientosScreenState();
}

class _MovimientosScreenState extends State<MovimientosScreen> {
  final _montoController = TextEditingController();
  final _descController = TextEditingController();
  String _tipo = 'cargo';
  final _db = DatabaseHelper();
  List<Producto> _productos = [];
  Producto? _productoSeleccionado;
  List<Movimiento> _movimientos = [];
  double _saldoProducto = 0.0;

  bool _esVistaGlobal = false;
  double _saldoTotal = 0.0;
  Map<int, double> _saldosPorProducto = {};

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _exportarPdfGlobal() async {
    // Cargar productos antes de generar el PDF
    await _cargarProductos();

    List<Movimiento> todosLosMovimientos = [];

    for (var producto in _productos) {
      final movs = await _db.getMovimientosPorProducto(producto.id!);
      todosLosMovimientos.addAll(movs);
    }

    if (todosLosMovimientos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No hay movimientos para exportar.")),
      );
      return;
    }

    final file = await PdfGenerator.generarResumen(
      widget.cliente,
      todosLosMovimientos,
      global: true,
      productos: _productos, // ahora sí están correctamente cargados
    );

    await Printing.sharePdf(
      bytes: await file.readAsBytes(),
      filename: 'Resumen_Global_${widget.cliente.nombre}.pdf',
    );
  }

  Future<void> _cargarProductos() async {
    final todos = await _db.getProductosPorCliente(widget.cliente.id!);
    _productos = todos;

    if (_productos.isNotEmpty) {
      if (_productoSeleccionado == null || !_productos.contains(_productoSeleccionado)) {
        _productoSeleccionado = _productos.first;
      }
      await _cargarMovimientos();
    } else {
      setState(() {
        _productoSeleccionado = null;
        _movimientos.clear();
      });
    }
  }

  Future<void> _cargarMovimientos() async {
    if (_productoSeleccionado == null) {
      setState(() {
        _movimientos = [];
        _saldoProducto = 0.0;
      });
      return;
    }

    final lista = await _db.getMovimientosPorProducto(_productoSeleccionado!.id!);
    final saldo = lista.fold(0.0, (acc, m) => m.tipo == 'cargo' ? acc + m.monto : acc - m.monto);

    setState(() {
      _movimientos = lista;
      _saldoProducto = saldo;
    });
  }

  Future<void> _agregarMovimiento() async {
    final monto = double.tryParse(_montoController.text);
    if (monto == null || monto <= 0 || _productoSeleccionado == null) return;

    final nuevo = Movimiento(
      productoId: _productoSeleccionado!.id!,
      fecha: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
      tipo: _tipo,
      monto: monto,
      descripcion: _descController.text,
    );

    await _db.insertMovimiento(nuevo);
    _montoController.clear();
    _descController.clear();
    await _cargarMovimientos();
    await _cargarProductos();
    await _sincronizarSiEsPremium();
  }

  Future<void> _liquidarDeuda() async {
    if (_productoSeleccionado == null || _saldoProducto <= 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("¿Confirmar liquidación?"),
        content: const Text("Se abonará el total restante de este producto."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Aceptar")),
        ],
      ),
    );

    if (confirm != true) return;

    final movimiento = Movimiento(
      productoId: _productoSeleccionado!.id!,
      fecha: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
      tipo: 'abono',
      monto: _saldoProducto,
      descripcion: 'Liquidación total',
    );

    await _db.insertMovimiento(movimiento);
    await _cargarMovimientos();
    await _cargarProductos();
    await _sincronizarSiEsPremium();
  }

  Future<void> _sincronizarSiEsPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token') ?? '';
    final userId = prefs.getString('userId') ?? '';
    final plan = prefs.getString('plan') ?? '';

    if (token.isEmpty || userId.isEmpty || (plan != 'premium' && plan != 'nube')) return;

    await SyncHelper.sincronizarSiConectado(userId: userId, token: token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        foregroundColor: Colors.white,
        title: Text(_esVistaGlobal
            ? 'Vista global'
            : 'Movimientos de ${widget.cliente.nombre}'),
        actions: [
          if (_esVistaGlobal)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Exportar PDF Global',
              onPressed: _exportarPdfGlobal,
            ),
          if (!_esVistaGlobal && _movimientos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final file = await PdfGenerator.generarResumen(widget.cliente, _movimientos);
                await Printing.sharePdf(
                  bytes: await file.readAsBytes(),
                  filename: 'Resumen_${widget.cliente.nombre}.pdf',
                );
              },
              tooltip: 'Exportar a PDF',
            ),
          IconButton(
            icon: Icon(_esVistaGlobal ? Icons.shopping_bag : Icons.account_balance_wallet),
            tooltip: _esVistaGlobal ? 'Ver por producto' : 'Ver cuenta principal',
            onPressed: () async {
              setState(() => _esVistaGlobal = !_esVistaGlobal);
              if (_esVistaGlobal) {
                await _cargarVistaGlobal();
              } else {
                await _cargarProductos();
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _esVistaGlobal
            ? VistaGlobal(
                saldoTotal: _saldoTotal,
                saldosPorProducto: _saldosPorProducto,
                productos: _productos,
                onAbonarGlobal: _mostrarDialogoAbonoGlobal,
                nombreCliente: widget.cliente.nombre,
              )
            : _buildVistaProducto(),
      ),
      floatingActionButton: _esVistaGlobal 
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.payments),
              label: const Text("Abonar Globalmente"),
              onPressed: _mostrarDialogoAbonoGlobal,
            )
          : FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0066CC),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text("Nuevo Movimiento"),
              onPressed: _mostrarFormulario,
      ),
    );
  }

  Widget _buildVistaProducto() {
    return Column(
      children: [
        ProductoSelector(
          productos: _productos,
          productoSeleccionado: _productoSeleccionado,
          onProductoChanged: (value) {
            setState(() {
              _productoSeleccionado = value;
            });
            _cargarMovimientos();
          },
          onAgregarProducto: _mostrarFormularioProducto,
        ),
        const SizedBox(height: 12),
        Text(
          'Saldo del producto: \$${_saldoProducto.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: _saldoProducto > 0 ? Colors.redAccent : Colors.greenAccent,
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _saldoProducto > 0 ? _liquidarDeuda : null,
          icon: const Icon(Icons.cleaning_services),
          label: const Text('Liquidar Deuda'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0066CC),
            foregroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: MovimientoList(movimientos: _movimientos),
        ),
      ],
    );
  }

  void _mostrarFormularioProducto() {
    final _nombreController = TextEditingController();
    final _descripcionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF252A3D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Nuevo Producto", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nombreController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Nombre del producto", Icons.label),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descripcionController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration("Descripción", Icons.description),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              final nombre = _nombreController.text.trim();
              final descripcion = _descripcionController.text.trim();
              if (nombre.isNotEmpty) {
                final nuevo = Producto(
                  clienteId: widget.cliente.id!,
                  nombre: nombre,
                  descripcion: descripcion,
                  fechaCreacion: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                );
                await _db.insertProducto(nuevo);
                Navigator.pop(context);
                await _cargarProductos();
                setState(() => _productoSeleccionado = _productos.last);
                await _cargarMovimientos();
              }
            },
            child: const Text("Guardar", style: TextStyle(color: Colors.greenAccent)),
          ),
        ],
      ),
    );
  }

  void _mostrarFormulario() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF252A3D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: MovimientoForm(
            montoController: _montoController,
            descController: _descController,
            tipo: _tipo,
            onTipoChanged: (value) => setState(() => _tipo = value!),
            onGuardar: () async {
              Navigator.pop(context);
              await _agregarMovimiento();
            },
          ),
        );
      },
    );
  }

  Future<void> _cargarVistaGlobal() async {
    final productos = await _db.getProductosPorCliente(widget.cliente.id!);
    final saldos = <int, double>{};
    double total = 0;

    for (var p in productos) {
      final movs = await _db.getMovimientosPorProducto(p.id!);
      final saldo = movs.fold(0.0, (s, m) => m.tipo == 'cargo' ? s + m.monto : s - m.monto);
      if (saldo > 0) {
        saldos[p.id!] = saldo;
        total += saldo;
      }
    }

    setState(() {
      _saldosPorProducto = saldos;
      _saldoTotal = total;
    });
  }

  Future<void> _mostrarDialogoAbonoGlobal() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Abono global"),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: "Monto total a abonar"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              final monto = double.tryParse(controller.text.trim());
              if (monto != null && monto > 0) {
                Navigator.pop(ctx);
                await _abonarGlobalmente(monto);
              }
            },
            child: const Text("Aceptar"),
          ),
        ],
      ),
    );
  }

  Future<void> _abonarGlobalmente(double totalAbono) async {
    if (_saldosPorProducto.isEmpty || totalAbono <= 0) return;

    double acumulado = 0;
    int index = 0;
    final total = _saldosPorProducto.values.reduce((a, b) => a + b);

    for (var entry in _saldosPorProducto.entries) {
      index++;
      double proporcion = entry.value / total;
      double abono = (totalAbono * proporcion).floorToDouble();
      if (index == _saldosPorProducto.length) {
        abono = totalAbono - acumulado;
      } else {
        acumulado += abono;
      }

      await _db.insertMovimiento(Movimiento(
        productoId: entry.key,
        fecha: DateFormat('yyyy-MM-dd – kk:mm').format(DateTime.now()),
        tipo: 'abono',
        monto: abono,
        descripcion: 'Abono proporcional',
      ));
    }

    await _cargarVistaGlobal();
    await _sincronizarSiEsPremium();
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1B1E2F),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white30),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF0066CC)),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}