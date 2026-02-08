import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MecDisBackendSafeApp());
}

/// Fase 5 (Opción A): UI primero + backend como exe separado.
///
/// Objetivo: arrancar la UI siempre, y lanzar el backend en segundo plano
/// con timeout y diagnóstico, sin congelar Flutter.
class MecDisBackendSafeApp extends StatelessWidget {
  const MecDisBackendSafeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mec-Dis Soporte Remoto',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5BD6)),
      ),
      home: const _BackendSafeHome(),
    );
  }
}

enum _BackendState { notStarted, starting, active, error }

class _BackendSafeHome extends StatefulWidget {
  const _BackendSafeHome();

  @override
  State<_BackendSafeHome> createState() => _BackendSafeHomeState();
}

class _BackendSafeHomeState extends State<_BackendSafeHome> {
  static const Duration _startupTimeout = Duration(seconds: 8);

  _BackendState _state = _BackendState.notStarted;
  String _stateDetail = 'No iniciado';

  Process? _proc;
  StreamSubscription<List<int>>? _outSub;
  StreamSubscription<List<int>>? _errSub;
  Timer? _startupTimer;
  final List<String> _logTail = <String>[];

  @override
  void initState() {
    super.initState();
    // Auto-intento: si existe el backend, arrancarlo sin bloquear.
    unawaited(_tryAutoStart());
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    _outSub?.cancel();
    _errSub?.cancel();
    _proc?.kill();
    super.dispose();
  }

  Future<void> _tryAutoStart() async {
    final exe = _backendExePath();
    if (File(exe).existsSync()) {
      await _startBackend(manual: false);
    } else {
      setState(() {
        _state = _BackendState.error;
        _stateDetail = 'No se encontró backend\n$exe';
      });
    }
  }

  String _backendExePath() {
    // En Windows release: Platform.resolvedExecutable suele apuntar al .exe de la app.
    final baseDir = File(Platform.resolvedExecutable).parent.path;
    return _joinPath(baseDir, 'backend', 'mecdis-backend.exe');
  }

  String _joinPath(String a, [String? b, String? c]) {
    final sep = Platform.pathSeparator;
    var p = a.endsWith(sep) ? a.substring(0, a.length - 1) : a;
    if (b != null) p = '$p$sep$b';
    if (c != null) p = '$p$sep$c';
    return p;
  }

  Future<void> _startBackend({required bool manual}) async {
    final exe = _backendExePath();

    if (!File(exe).existsSync()) {
      setState(() {
        _state = _BackendState.error;
        _stateDetail = 'Backend no encontrado\n$exe';
      });
      return;
    }

    if (_proc != null) {
      // Si ya existe un proceso vivo, no lanzamos otro.
      // (Evita duplicados; para reinicio, el usuario primero cierra la app.)
      setState(() {
        _state = _BackendState.active;
        _stateDetail = 'Backend ya estaba iniciado';
      });
      return;
    }

    setState(() {
      _state = _BackendState.starting;
      _stateDetail = manual ? 'Iniciando (manual)…' : 'Iniciando…';
    });

    try {
      final p = await Process.start(
        exe,
        const <String>[],
        runInShell: false,
        workingDirectory: File(exe).parent.path,
      );

      _proc = p;
      _attachLogs(p);

      // Si el backend muere rápido, consideramos error.
      unawaited(
        p.exitCode.then((code) {
          if (!mounted) return;
          _startupTimer?.cancel();
          setState(() {
            _state = _BackendState.error;
            _stateDetail = 'Backend terminó (exit $code)';
          });
          _proc = null;
        }),
      );

      // Timeout: si sigue vivo tras X segundos, lo marcamos como activo.
      _startupTimer?.cancel();
      _startupTimer = Timer(_startupTimeout, () {
        if (!mounted) return;
        if (_proc != null) {
          setState(() {
            _state = _BackendState.active;
            _stateDetail = 'Activo (timeout OK)';
          });
        }
      });
    } catch (e) {
      setState(() {
        _state = _BackendState.error;
        _stateDetail = 'Error al iniciar: $e';
      });
      _proc = null;
    }
  }

  void _attachLogs(Process p) {
    void pushLine(String line) {
      if (line.trim().isEmpty) return;
      _logTail.add(line.trimRight());
      if (_logTail.length > 60) {
        _logTail.removeRange(0, _logTail.length - 60);
      }
    }

    _outSub?.cancel();
    _errSub?.cancel();
    _outSub = p.stdout.listen((chunk) {
      pushLine(utf8.decode(chunk, allowMalformed: true));
    });
    _errSub = p.stderr.listen((chunk) {
      pushLine('[ERR] ${utf8.decode(chunk, allowMalformed: true)}');
    });
  }

  String _diagnosticText() {
    final now = DateTime.now();
    final exe = _backendExePath();
    final exists = File(exe).existsSync();
    final state = _state.toString().split('.').last;
    final pid = _proc?.pid;

    final tail = _logTail.isEmpty ? '(sin logs capturados)' : _logTail.join('\n');

    return [
      'Mec-Dis Soporte Remoto — Diagnóstico',
      'Fecha: $now',
      'UI exe: ${Platform.resolvedExecutable}',
      'Backend exe esperado: $exe',
      'Backend existe: $exists',
      'Estado: $state',
      'Detalle: $_stateDetail',
      'PID: ${pid ?? '(no)'}',
      '--- LOG (últimas líneas) ---',
      tail,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final status = switch (_state) {
      _BackendState.notStarted => 'No iniciado',
      _BackendState.starting => 'Iniciando',
      _BackendState.active => 'Activo',
      _BackendState.error => 'Error',
    };

    final statusIcon = switch (_state) {
      _BackendState.notStarted => Icons.pause_circle_outline,
      _BackendState.starting => Icons.autorenew,
      _BackendState.active => Icons.check_circle_outline,
      _BackendState.error => Icons.error_outline,
    };

    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 24,
                    spreadRadius: 0,
                    offset: const Offset(0, 12),
                    color: cs.shadow.withOpacity(0.12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Placeholder de logo (texto). Se puede cambiar por Image.asset cuando metamos logo real.
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'MD',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimaryContainer,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Mec-Dis Soporte Remoto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Backend seguro (Opción A)\nLa UI inicia primero y el servicio va por separado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: cs.onSurfaceVariant),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Estado: $status',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _stateDetail,
                                  style: TextStyle(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: (_state == _BackendState.starting || _state == _BackendState.active)
                              ? null
                              : () => _startBackend(manual: true),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar servicio'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final text = _diagnosticText();
                            await Clipboard.setData(ClipboardData(text: text));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Diagnóstico copiado.')),
                            );
                          },
                          icon: const Icon(Icons.copy_all_outlined),
                          label: const Text('Copiar diagnóstico'),
                        ),
                        TextButton(
                          onPressed: _closeApp,
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ruta esperada del backend: backend\\mecdis-backend.exe\n'
                      'Tip: si Windows bloquea el archivo, usa “Más información” → “Ejecutar de todas formas”.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _closeApp() {
    // Cierre real para Windows (y en general desktop)
    exit(0);
  }
}
