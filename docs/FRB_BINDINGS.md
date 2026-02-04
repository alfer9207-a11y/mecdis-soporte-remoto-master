# FRB bindings (flutter_rust_bridge) — Mec-Dis RustDesk rebrand

## Problema
`flutter_rust_bridge_codegen` v1.80.1 requiere Rust >= 1.82, pero RustDesk se compila con Rust 1.75.
Por estabilidad, el CI (GitHub Actions) **NO debe** ejecutar el codegen.

## Política del repo
- Los bindings se generan localmente y se commitean:
  - `src/bridge_generated.rs`
  - `src/bridge_generated.io.rs` (si aplica)
  - `flutter/lib/generated_bridge.dart`
  - `flutter/lib/generated_bridge.freezed.dart` (si se genera)
  - `flutter/macos/Runner/bridge_generated.h` (si aplica)
- El CI solo compila (sin codegen).

## Generación local (Windows)
```powershell
rustup toolchain install 1.82.0
cargo +1.82.0 install flutter_rust_bridge_codegen --version 1.80.1 --features uuid --locked
flutter_rust_bridge_codegen --rust-input .\src\flutter_ffi.rs --dart-output .\flutter\lib\generated_bridge.dart
```

Opcional (macOS header):
```powershell
flutter_rust_bridge_codegen --rust-input .\src\flutter_ffi.rs --dart-output .\flutter\lib\generated_bridge.dart --c-output .\flutter\macos\Runner\bridge_generated.h
```
