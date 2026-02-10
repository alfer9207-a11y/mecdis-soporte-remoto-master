import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MecDisApp());
}

class MecDisApp extends StatelessWidget {
  const MecDisApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1F2937); // gris oscuro (Opción B)
    const surface = Color(0xFFF7F8FB); // blanco/gris muy claro
    const border = Color(0xFFE5E7EB);

    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: primary,
      surface: surface,
      outline: border,
    );

    return MaterialApp(
      title: 'Mec-Dis Soporte Remoto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        scaffoldBackgroundColor: surface,
        appBarTheme: const AppBarTheme(
          backgroundColor: surface,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF111827),
            side: const BorderSide(color: border),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: border),
          ),
        ),
      ),
      home: const Home(),
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ConnectionPage(),
      const AboutPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/mecdis_logo.png', height: 26),
            const SizedBox(width: 10),
            const Text('Mec-Dis Soporte Remoto'),
          ],
        ),
        actions: const [
          _PortableFolderButton(),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: pages[_tab],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.link), label: 'Conexión'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'Acerca de'),
        ],
      ),
    );
  }
}

class _PortableFolderButton extends StatefulWidget {
  const _PortableFolderButton();
  @override
  State<_PortableFolderButton> createState() => _PortableFolderButtonState();
}

class _PortableFolderButtonState extends State<_PortableFolderButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Abrir carpeta portable',
      icon: const Icon(Icons.folder_open),
      onPressed: () async {
        final base = Directory.current.path;
        final portable = p.join(base, 'portable');
        if (Directory(portable).existsSync()) {
          try {
            await Process.start('explorer.exe', [portable], runInShell: true);
          } catch (_) {}
        }
      },
    );
  }
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  Process? _backendProc;
  Timer? _healthTimer;

  String _status = 'Detenido';
  String _backendPath = '';
  String _lastHealth = '—';
  final _log = <String>[];
  final _portCtrl = TextEditingController(text: '21118');

  @override
  void initState() {
    super.initState();
    _backendPath = _defaultBackendPath();
    _logLine('Iniciando Mec-Dis Soporte Remoto');
    _startHealthLoop();
    Future.microtask(() async {
      if (File(_backendPath).existsSync()) {
        await _startBackend();
      } else {
        _logLine('Backend NO encontrado: $_backendPath');
      }
    });
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    _backendProc?.kill(ProcessSignal.sigterm);
    _portCtrl.dispose();
    super.dispose();
  }

  String _defaultBackendPath() {
    final base = Directory.current.path;
    return p.join(base, 'portable', 'backend', 'mecdis-backend.exe');
  }

  void _logLine(String msg) {
    final ts = DateTime.now()
        .toIso8601String()
        .replaceFirst('T', ' ')
        .split('.')
        .first;
    setState(() {
      _log.insert(0, '[$ts] $msg');
      if (_log.length > 300) _log.removeRange(300, _log.length);
    });
  }

  Future<void> _startBackend() async {
    final backendFile = File(_backendPath);
    if (!backendFile.existsSync()) {
      _logLine('No se puede iniciar: backend no existe en $_backendPath');
      setState(() => _status = 'No encontrado');
      return;
    }
    if (_backendProc != null) {
      _logLine('Backend ya está iniciado (PID: ${_backendProc!.pid})');
      return;
    }
    try {
      _logLine('Iniciando backend...');
      final proc = await Process.start(
        backendFile.path,
        const [],
        runInShell: true,
        workingDirectory: backendFile.parent.path,
      );

      proc.stdout.transform(const SystemEncoding().decoder).listen((d) {
        for (final line in d.split('\n')) {
          final t = line.trim();
          if (t.isNotEmpty) _logLine('BACKEND: $t');
        }
      });
      proc.stderr.transform(const SystemEncoding().decoder).listen((d) {
        for (final line in d.split('\n')) {
          final t = line.trim();
          if (t.isNotEmpty) _logLine('BACKEND_ERR: $t');
        }
      });

      proc.exitCode.then((code) {
        _logLine('Backend terminó con código: $code');
        if (mounted) {
          setState(() {
            _backendProc = null;
            _status = 'Detenido';
          });
        }
      });

      setState(() {
        _backendProc = proc;
        _status = 'Ejecutándose (PID: ${proc.pid})';
      });
      _logLine('Backend iniciado (PID: ${proc.pid})');
    } catch (e) {
      _logLine('Error iniciando backend: $e');
      setState(() => _status = 'Error al iniciar');
    }
  }

  Future<void> _stopBackend() async {
    final proc = _backendProc;
    if (proc == null) {
      _logLine('Backend ya está detenido');
      return;
    }
    _logLine('Deteniendo backend (PID: ${proc.pid})...');
    try {
      final ok = proc.kill(ProcessSignal.sigterm);
      _logLine(ok ? 'SIGTERM enviado' : 'No se pudo enviar SIGTERM');
    } catch (e) {
      _logLine('Error al detener: $e');
    }
  }

  void _startHealthLoop() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      // healthcheck simple: si backend está vivo, marcamos OK
      final alive = _backendProc != null;
      if (!mounted) return;
      setState(() => _lastHealth = alive ? 'OK' : 'Detenido');
    });
  }

  @override
  Widget build(BuildContext context) {
    final backendExists = File(_backendPath).existsSync();

    return Padding(
      key: const ValueKey('conn'),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _HeroCard(
            status: _status,
            health: _lastHealth,
            backendExists: backendExists,
            backendPath: _backendPath,
            portCtrl: _portCtrl,
            onStart: _startBackend,
            onStop: _stopBackend,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registro (últimos eventos)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          itemCount: _log.length,
                          itemBuilder: (_, i) => Text(
                            _log[i],
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String status;
  final String health;
  final String backendPath;
  final bool backendExists;
  final TextEditingController portCtrl;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  const _HeroCard({
    required this.status,
    required this.health,
    required this.backendPath,
    required this.backendExists,
    required this.portCtrl,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    Widget pill(String k, String v) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          color: Colors.white,
        ),
        child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Soporte remoto profesional',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                        'Para control completo (ver pantalla y controlar), se recomienda instalar el servicio.',
                        style: TextStyle(color: Color(0xFF4B5563)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Image.asset('assets/mecdis_logo.png', height: 54),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                pill('Estado', status),
                pill('Health', health),
                pill('Backend', backendExists ? 'Encontrado' : 'No encontrado'),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText('Ruta backend: $backendPath'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Puerto healthcheck:'),
                const SizedBox(width: 10),
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: portCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      hintText: '21118',
                    ),
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: onStop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Detener'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('about'),
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/mecdis_logo.png', height: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Mec-Dis Soporte Remoto',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('Soporte remoto profesional',
                        style: TextStyle(color: Color(0xFF4B5563))),
                    SizedBox(height: 14),
                    Text('Contacto',
                        style:
                            TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Tepeyac 11A, Col. Centro, Sahuayo, Michoacán, C.P. 59000'),
                    SizedBox(height: 6),
                    Text('Tel: 353 690 1230'),
                    SizedBox(height: 6),
                    Text('WhatsApp: 353 105 2440 / 353 100 1977'),
                    SizedBox(height: 6),
                    Text('Correo: mec-disshy@hotmail.com'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
