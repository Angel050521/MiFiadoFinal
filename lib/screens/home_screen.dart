import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'cliente_lista.dart' show ClienteListaScreen, ClienteListaScreenState;
import 'cliente_form.dart';
import 'resumen_screen.dart';
import 'suscripcion_screen.dart';
import 'pedidos_screen.dart'; // ✅ nueva sección de pedidos

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ClienteListaScreenState> _clienteListaKey = GlobalKey<ClienteListaScreenState>();
  int _currentIndex = 0;
  InterstitialAd? _interstitialAd;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();
    _screens = [
      _buildHomeContent(),                          // 0. Inicio
      ClienteListaScreen(key: _clienteListaKey),    // 1. Clientes
      const ResumenScreen(),                        // 2. Resumen
      const PedidosScreen(),                        // 3. Pedidos
      const SuscripcionScreen(),                    // 4. Premium
    ];
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-8287127512209971/9247923722',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) {
          debugPrint('Error al cargar interstitial: $error');
          _interstitialAd = null;
        },
      ),
    );
  }

  void _mostrarAnuncio() {
    if (_interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Gracias por apoyar viendo un anuncio!')),
          );
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al mostrar anuncio.')),
          );
        },
      );
      _interstitialAd!.show();
      _interstitialAd = null;
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anuncio no disponible aún')),
      );
      _loadInterstitialAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1E2F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1E2F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _screens[_currentIndex],
      floatingActionButton: _currentIndex == 1
          ? Container(
        decoration: BoxDecoration(
          color: const Color(0xFF00BFFF),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFFF).withOpacity(0.6),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              offset: const Offset(0, 2),
              blurRadius: 6,
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ClienteFormScreen()),
            );
            if (result == true && _currentIndex == 1) {
              _clienteListaKey.currentState?.cargarClientes();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1B1E2F),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white60,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Clientes'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Resumen'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'Premium'),
        ],
      ),
    );
  }

  Widget _buildApoyoButton() {
    return GestureDetector(
      onTap: _mostrarAnuncio,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00BFFF), Color(0xFF0091EA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00BFFF).withOpacity(0.4),
              offset: const Offset(0, 4),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.volunteer_activism, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Flexible(
              child: Text(
                'Apoya la app viendo un anuncio',
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF00BFFF).withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF00BFFF), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B1E2F), Color(0xFF0D0F1A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 40.0, left: 24.0, right: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bienvenido a Mi Fiado',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Controla todos tus préstamos y fiados en un solo lugar',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 140.0, left: 24.0, right: 24.0, bottom: 24.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                    child: Container(
                      width: constraints.maxWidth > 600 ? 600 : double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFeatureItem(
                              Icons.people,
                              'Gestión de Clientes',
                              'Administra la información de tus clientes y lleva un registro detallado de cada uno.',
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              Icons.shopping_cart,
                              'Productos Individuales',
                              'Agrega y gestiona productos individuales para cada cliente.',
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              Icons.attach_money,
                              'Control de Pagos',
                              'Registra abonos, genera recibos y lleva el control de saldos pendientes.',
                            ),
                            const SizedBox(height: 20),
                            _buildFeatureItem(
                              Icons.picture_as_pdf,
                              'Exportar a PDF',
                              'Genera reportes detallados en formato PDF.',
                            ),
                            const SizedBox(height: 20),
                            // ← Nueva sección de Pedidos
                            _buildFeatureItem(
                              Icons.assignment,
                              'Pedidos',
                              'Crea, edita, marca como hecho y elimina automáticamente tus pedidos según fecha.',
                            ),
                            const SizedBox(height: 30),
                            _buildApoyoButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
