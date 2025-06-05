
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import '../models/cliente.dart';
import '../models/movimiento.dart';
import '../models/producto.dart';

class PdfGenerator {
  static Future<File> generarResumen(
      Cliente cliente,
      List<Movimiento> movimientos, {
        bool global = false,
        List<Producto> productos = const [],
      }) async {
    final pdf = pw.Document();
    final saldo = movimientos.fold<double>(0, (prev, mov) {
      return mov.tipo == 'cargo' ? prev + mov.monto : prev - mov.monto;
    });

    final logoImage = await _loadLogo();

    final mapaProductos = {
      for (var p in productos) p.id!: p.nombre,
    };

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          buildBackground: (context) => logoImage != null
              ? pw.FullPage(
            ignoreMargins: true,
            child: pw.Opacity(
              opacity: 0.05,
              child: pw.Center(
                child: pw.Image(logoImage, width: 300),
              ),
            ),
          )
              : pw.Container(),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              if (logoImage != null) pw.Image(logoImage, width: 80),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text('Resumen de deuda',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.SizedBox(height: 10),
          pw.Text('Cliente: ${cliente.nombre}', style: pw.TextStyle(fontSize: 14)),
          if (cliente.telefono != null)
            pw.Text('Teléfono: ${cliente.telefono}', style: pw.TextStyle(fontSize: 14)),
          pw.SizedBox(height: 10),
          pw.Text('Fecha de generación: ${DateTime.now().toString().substring(0, 16)}',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
          pw.SizedBox(height: 12),
          pw.Text('Detalle de movimientos:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Fecha', 'Producto', 'Tipo', 'Monto', 'Descripción'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: pw.TextStyle(fontSize: 10),
            data: movimientos
                .toList()
                .reversed
                .map((mov) => [
              mov.fecha,
              mapaProductos[mov.productoId] ?? 'N/A',
              mov.tipo,
              '\$${mov.monto.toStringAsFixed(2)}',
              mov.descripcion?.isNotEmpty == true ? mov.descripcion! : 'Sin descripción',
            ])
                .toList(),
            border: pw.TableBorder.all(color: PdfColors.grey400),
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: saldo > 0 ? PdfColors.red100 : PdfColors.green100,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              'Saldo total: \$${saldo.toStringAsFixed(2)}',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: saldo > 0 ? PdfColors.red800 : PdfColors.green800,
              ),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Text('Generado con Mi Fiado',
                  style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Este documento es solo informativo y no representa un comprobante fiscal ni legal.',
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey700,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    final output = await getTemporaryDirectory();
    final fecha = DateTime.now().toIso8601String().substring(0, 10).replaceAll("-", "");
    final nombreCliente = cliente.nombre.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final file = File("${output.path}/Resumen_${global ? 'Global_' : ''}${nombreCliente}_$fecha.pdf");

    await file.writeAsBytes(await pdf.save());
    return file;
  }

  static Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final bytes = await rootBundle.load('assets/Logo_pdf.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }
}
