import 'dart:io';
import 'package:flutter/material.dart';

void main() {
  runApp(const MecDisNoBackendApp());
}

/// Modo diagnóstico: UI funcionando sin backend.
/// Esto evita congelamientos mientras se integra el servicio real.
class MecDisNoBackendApp extends StatelessWidget {
  const MecDisNoBackendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mec-Dis Soporte Remoto',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5BD6)),
      ),
      home: const _NoBackendHome(),
    );
  }
}

class _NoBackendHome extends StatelessWidget {
  const _NoBackendHome();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                      'Modo diagnóstico (NO_BACKEND_TEST)\nLa UI está lista. El servicio aún no inicia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _closeApp,
                      child: const Text('Cerrar'),
                    ),
                    const SizedBox(height: 8),
                    Text(
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
