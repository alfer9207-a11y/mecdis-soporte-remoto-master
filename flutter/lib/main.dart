import 'package:flutter/material.dart';

void main() {
  runApp(const NoBackendApp());
}

class NoBackendApp extends StatelessWidget {
  const NoBackendApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Mec-Dis Soporte Remoto\nUI OK (NO_BACKEND_TEST)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _close,
                child: Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _close() {
    // Cierre limpio en Windows
    Future.microtask(() => WidgetsBinding.instance.handleAppLifecycleStateChanged(AppLifecycleState.detached));
  }
}
