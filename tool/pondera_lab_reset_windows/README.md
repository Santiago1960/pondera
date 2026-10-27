# Pondera Lab Reset para Windows

Utilidad interna y separada de Pondera para preparar los equipos usados durante
las pruebas previas a producción. No debe distribuirse a clientes ni agregarse
al instalador de Pondera.

## Alcance

La utilidad opera exclusivamente sobre los datos locales del usuario actual:

- Comprueba que `pondera.exe` esté cerrado.
- Analiza `%APPDATA%\com.caicedosantiago\pondera`.
- Mueve esa carpeta a un respaldo fechado bajo
  `%APPDATA%\com.caicedosantiago\PonderaLabReset\backups`.
- Restaura únicamente el almacenamiento seguro que contiene
  `pondera_installation_id`, sin alterar una identidad segura adicional si
  existe.
- Elimina del perfil activo la licencia anterior, la receta, las fechas de
  prueba y los estados remotos, pero los conserva dentro del respaldo.
- Registra el resultado, sin valores de licencia ni identificadores, bajo
  `%LOCALAPPDATA%\Bitgenial\PonderaLabReset\logs`.

No modifica la base de datos, n8n, `MachineGuid`, el fingerprint ni el
`installation_id`. El servidor sigue siendo responsable de impedir que un
cliente reinicie su trial reinstalando o limpiando la aplicación.

## Flujo de seguridad

1. **Analizar** muestra exactamente qué datos existen y bloquea la operación si
   Pondera está abierto o la ruta no pasa las validaciones.
2. El operador debe escribir `RESTABLECER`.
3. **Crear respaldo y limpiar** vuelve a analizar antes de actuar.
4. Si falla la restauración de la identidad después de mover los datos, se
   intenta restaurar inmediatamente la carpeta original.

La utilidad no acepta rutas por línea de comandos y nunca borra recursivamente
la carpeta original: la mueve a un respaldo recuperable.

## Compilación

Requiere Visual Studio con las herramientas de C++ y CMake. Desde una consola
de desarrollador:

```powershell
cmake -S . -B build-ninja -G Ninja
cmake --build build-ninja
ctest --test-dir build-ninja --output-on-failure
```

El ejecutable de compilación queda en `build-ninja\pondera_lab_reset.exe`. La
copia entregable de esta versión se encuentra en
`dist\pondera_lab_reset-1.1.0.exe`.

## Validación antes de producción

Además de las pruebas de esta utilidad, deben comprobarse en n8n estos casos:

1. Equipo limpio y sin registro en la base: inicia un trial de 15 días.
2. Equipo ya registrado y cliente reinstalado: conserva el vencimiento original.
3. Equipo con trial vencido y cliente reinstalado: continúa vencido.
