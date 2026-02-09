import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MecDisShellApp());
}

class MecDisShellApp extends StatelessWidget {
  const MecDisShellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MEC-DIS SOPORTE REMOTO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF111827)),
        useMaterial3: true,
      ),
      home: const ShellHome(),
    );
  }
}

class ShellHome extends StatefulWidget {
  const ShellHome({super.key});

  @override
  State<ShellHome> createState() => _ShellHomeState();
}

class _ShellHomeState extends State<ShellHome> {
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
    _logLine('UI SHELL iniciada');
    _startHealthLoop();
    // Auto-start si existe (sin bloquear la UI)
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
    // Se asume estructura portable:
    // <carpeta del exe>/portable/backend/mecdis-backend.exe
    final base = Directory.current.path;
    return p.join(base, 'portable', 'backend', 'mecdis-backend.exe');
  }

  void _logLine(String msg) {
    final ts = DateTime.now().toIso8601String().replaceFirst('T', ' ').split('.').first;
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
      if (!ok) proc.kill(ProcessSignal.sigkill);
      setState(() {
        _backendProc = null;
        _status = 'Detenido';
      });
    } catch (e) {
      _logLine('Error deteniendo backend: $e');
    }
  }

  void _startHealthLoop() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      final res = await _healthcheck();
      if (!mounted) return;
      setState(() => _lastHealth = res);
    });
  }

  Future<String> _healthcheck() async {
    final running = _backendProc != null;
    final port = int.tryParse(_portCtrl.text.trim()) ?? 21118;

    // 1) Si hay proceso, intentamos abrir TCP rápido (si el backend expone puerto)
    // 2) Si no hay proceso, devolvemos Detenido.
    if (!running) return 'Detenido';

    try {
      final sock = await Socket.connect('127.0.0.1', port, timeout: const Duration(milliseconds: 500));
      sock.destroy();
      return 'OK (TCP 127.0.0.1:$port)';
    } catch (_) {
      // Si no hay puerto, al menos confirmar proceso vivo.
      return 'Vivo (proceso), sin puerto $port';
    }
  }

  Future<void> _openPortableFolder() async {
    final portableDir = p.join(Directory.current.path, 'portable');
    try {
      await Process.run('explorer', [portableDir], runInShell: true);
      _logLine('Abrir carpeta: $portableDir');
    } catch (e) {
      _logLine('No se pudo abrir Explorer: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final backendExists = File(_backendPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MEC-DIS SOPORTE REMOTO — UI SHELL'),
        actions: [
          IconButton(
            tooltip: 'Abrir carpeta portable',
            icon: const Icon(Icons.folder_open),
            onPressed: _openPortableFolder,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _StatusCard(
              status: _status,
              health: _lastHealth,
              backendPath: _backendPath,
              backendExists: backendExists,
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
                      const Text('Log (últimos eventos)', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            reverse: false,
                            itemCount: _log.length,
                            itemBuilder: (_, i) => Text(
                              _log[i],
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String status;
  final String health;
  final String backendPath;
  final bool backendExists;
  final TextEditingController portCtrl;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  const _StatusCard({
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill('Estado', status),
                _pill('Health', health),
                _pill('Backend', backendExists ? 'Encontrado' : 'No encontrado'),
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

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Text('$k: $v', style: const TextStyle(fontSize: 12)),
    );
  }
}
