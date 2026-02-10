# Mec-Dis CI Fix v2 — Opus sin Manifest (Windows)

## Problema
En repos con `vcpkg.json`, vcpkg entra a *manifest mode* y termina compilando dependencias pesadas
(AV1/aom/etc.), lo cual falla de forma aleatoria en GitHub Actions Windows.

## Solución estable
Instalar **SOLO** `opus` usando *classic mode*:

- `vcpkg install opus --classic`
- Forzar root: `--x-install-root=C:\vcpkg\installed`
- Activar binary cache: `VCPKG_BINARY_SOURCES="clear;x-gha,readwrite"`

## Uso
Reemplaza tu archivo:
`.github/workflows/mecdis-windows.yml`
por el incluido aquí (o copia el step marcado).
