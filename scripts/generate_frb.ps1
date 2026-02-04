# scripts/generate_frb.ps1
# Mec-Dis / RustDesk rebrand
# Genera bindings de flutter_rust_bridge localmente usando un toolchain moderno (Rust >= 1.82)
# y asegura que exista LLVM/Clang (libclang.dll) para que ffigen no falle.
#
# NOTA: Esto NO cambia el toolchain de compilación del proyecto (RustDesk sigue con 1.75).
# Solo usa el toolchain moderno para instalar/ejecutar flutter_rust_bridge_codegen.

param(
  [string]$Toolchain = "1.82.0",
  [string]$CodegenVersion = "1.80.1",
  [string]$RustInput = ".\src\flutter_ffi.rs",
  [string]$DartOutput = ".\flutter\lib\generated_bridge.dart",
  # Ruta típica de LLVM en Windows (winget)
  [string]$LlvmRoot = "C:\Program Files\LLVM"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
  Write-Host $msg -ForegroundColor Cyan
}

function Ensure-Command($name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue
  return $null -ne $cmd
}

function Ensure-LLVM {
  $libclang = Join-Path (Join-Path $LlvmRoot "bin") "libclang.dll"
  if (Test-Path $libclang) {
    Write-Host "   LLVM OK: $libclang"
    return $true
  }

  Write-Host "   LLVM/Clang no encontrado (falta libclang.dll). Intentando instalar con winget..." -ForegroundColor Yellow

  if (-not (Ensure-Command "winget")) {
    Write-Host "   ERROR: winget no está disponible en este Windows." -ForegroundColor Red
    Write-Host "   Solución: instala LLVM manualmente y asegúrate de tener:" -ForegroundColor Yellow
    Write-Host "     $libclang" -ForegroundColor Yellow
    throw "LLVM missing and winget not available."
  }

  # Intento de instalación (puede pedir confirmación / admin)
  & winget install -e --id LLVM.LLVM --accept-package-agreements --accept-source-agreements

  if (Test-Path $libclang) {
    Write-Host "   LLVM instalado: $libclang"
    return $true
  }

  Write-Host "   ERROR: no se detectó libclang.dll después de instalar LLVM." -ForegroundColor Red
  Write-Host "   Revisa que exista: $libclang" -ForegroundColor Yellow
  throw "LLVM installation did not provide libclang.dll at expected path."
}

Write-Host "== FRB Local Codegen (Mec-Dis) =="

# 1) Toolchain moderno (solo para codegen)
Write-Step "-> Installing rust toolchain $Toolchain (if needed)..."
rustup toolchain install $Toolchain | Out-Null

# 2) Asegurar LLVM para ffigen
Write-Step "-> Ensuring LLVM/Clang (libclang.dll) for ffigen..."
Ensure-LLVM | Out-Null

# Exportar LIBCLANG_PATH para que ffigen lo encuentre sí o sí
$env:LIBCLANG_PATH = Join-Path $LlvmRoot "bin"

# 3) Instalar flutter_rust_bridge_codegen con toolchain moderno si falta
Write-Step "-> Installing flutter_rust_bridge_codegen v$CodegenVersion (if needed)..."
$cargoList = (& cargo +$Toolchain install --list) 2>$null
if ($cargoList -and ($cargoList -match "flutter_rust_bridge_codegen")) {
  Write-Host "   flutter_rust_bridge_codegen already installed."
} else {
  cargo +$Toolchain install flutter_rust_bridge_codegen --version $CodegenVersion --locked
}

# 4) Generar bindings (incluye --llvm-path para ffigen)
Write-Step "-> Generating bindings..."
$llvmPathArg = $LlvmRoot
flutter_rust_bridge_codegen --rust-input $RustInput --dart-output $DartOutput --llvm-path $llvmPathArg

Write-Host "OK. Generated: $DartOutput" -ForegroundColor Green
Write-Host "Tip: ahora corre 'git status' y commitea src/bridge_generated.rs y flutter/lib/generated_bridge.dart" -ForegroundColor Green
