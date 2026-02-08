import 'dart:io';
import 'dart:async';

void main() async {
  print("Mec-Dis Soporte Remoto UI iniciada");

  final backend = File('portable/backend/mecdis-backend.exe');
  if (backend.existsSync()) {
    try {
      Process.start(backend.path, [], runInShell: true);
      print("Backend iniciado");
    } catch (e) {
      print("Error iniciando backend: $e");
    }
  } else {
    print("Backend no encontrado");
  }

  Timer(Duration(seconds: 5), () {
    print("Healthcheck: OK (placeholder)");
  });
}
