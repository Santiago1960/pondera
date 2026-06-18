# AGENTS.md

Guia de trabajo para agentes y colaboradores que modifiquen este repositorio.

## Proyecto

Pondera es una aplicacion Flutter de escritorio para macOS y Windows 10/11.

La app se comunica con balanzas o dispositivos de pesaje mediante:

- Ethernet/TCP.
- RS-232 mediante `flutter_libserialport`.
- Integracion HTTP con n8n.

Objetivo principal: capturar, limpiar, convertir y enviar lecturas de peso de forma confiable, manteniendo una experiencia de escritorio simple para operadores.

## Alcance Tecnico

- Framework: Flutter.
- Lenguaje principal: Dart.
- Plataformas objetivo: macOS, Windows 10 y Windows 11.
- Directorio principal de codigo: `lib/`.
- Integraciones nativas:
  - `macos/` para configuracion y codigo nativo de macOS.
  - `windows/` para configuracion y codigo nativo de Windows.
- Persistencia local: `shared_preferences`.
- Red: sockets TCP y HTTP.
- Puerto serial: `flutter_libserialport`.

## Principios De Trabajo

- Mantener los cambios pequenos, revisables y orientados al problema solicitado.
- Respetar la estructura existente antes de introducir abstracciones nuevas.
- Evitar refactors amplios si no son necesarios para completar la tarea.
- No modificar archivos generados salvo que el cambio lo requiera explicitamente.
- No revertir cambios locales de otra persona.
- Documentar decisiones tecnicas solo cuando ayuden a evitar ambiguedad futura.
- Hacer los cambios de a uno por vez y revisarlo antes de continuar con otros

## Comandos Habituales

Instalar dependencias:

```sh
flutter pub get
```

Analizar codigo:

```sh
flutter analyze
```

Ejecutar tests, cuando existan:

```sh
flutter test
```

Ejecutar en macOS:

```sh
flutter run -d macos
```

Ejecutar en Windows:

```sh
flutter run -d windows
```

Compilar para macOS:

```sh
flutter build macos
```

Compilar para Windows:

```sh
flutter build windows
```

## Verificacion Esperada

Antes de cerrar un cambio, ejecutar al menos:

```sh
flutter analyze
```

Si el cambio toca logica de parseo, conversion, red, serializacion o persistencia, agregar o actualizar tests cuando el proyecto tenga una carpeta `test/`.

Si el cambio toca comportamiento nativo o integraciones de hardware, verificar manualmente en la plataforma afectada cuando sea posible:

- macOS: permisos, firma, entitlements, acceso a red y puertos seriales.
- Windows 10/11: DLLs, plugins generados, teclado, red y puertos COM.

## Estructura Recomendada

Arquitectura final acordada para `lib/`:

```text
lib/
  main.dart
  app/
    pondera_app.dart
    app_theme.dart
  core/
    config/
      app_config.dart
    constants/
      preference_keys.dart
    utils/
      date_formatters.dart
      diagnostics_formatters.dart
  features/
    connection/
      domain/
        connection_type.dart
        connection_status.dart
        scale_connection_config.dart
      data/
        tcp_scale_connection.dart
        serial_scale_connection.dart
        serial_port_catalog.dart
      application/
        connection_controller.dart
      presentation/
        connection_settings_panel.dart
        connection_status_panel.dart
    scale_reading/
      domain/
        scale_reading.dart
        weight_unit.dart
        weight_converter.dart
        reading_parser.dart
      application/
        scale_reading_controller.dart
      presentation/
        current_weight_panel.dart
        units_settings_panel.dart
        raw_data_log_panel.dart
    recipe/
      domain/
        regex_recipe.dart
      data/
        n8n_recipe_client.dart
        recipe_repository.dart
      application/
        recipe_controller.dart
      presentation/
        recipe_actions_panel.dart
    keyboard_output/
      domain/
        key_command.dart
      data/
        macos_keyboard_output.dart
        windows_keyboard_output.dart
      application/
        keyboard_output_service.dart
      presentation/
        keyboard_settings_panel.dart
    license/
      domain/
        demo_license.dart
      application/
        demo_license_controller.dart
      presentation/
        demo_status_text.dart
    settings/
      domain/
        app_settings.dart
      data/
        settings_repository.dart
  platform/
    method_channels/
      windows_keyboard_channel.dart
  shared/
    widgets/
    layout/
```

Responsabilidades por carpeta:

- `main.dart`: punto de entrada solamente. Debe inicializar Flutter y llamar a `runApp`.
- `app/`: composicion global de la aplicacion, tema y configuracion visual de alto nivel.
- `core/`: utilidades y constantes transversales sin dependencia directa de UI ni hardware.
- `features/`: modulos funcionales del producto. Cada feature contiene sus modelos, servicios, controladores y widgets propios.
- `platform/`: wrappers explicitos para APIs nativas, method channels y diferencias macOS/Windows.
- `shared/`: widgets o helpers reutilizables que no pertenecen claramente a una feature.

Reglas de dependencia:

- `presentation/` puede depender de `application/` y `domain/`.
- `application/` coordina casos de uso y puede depender de `domain/`, `data/` y `settings/`.
- `domain/` debe ser Dart puro siempre que sea posible. No debe importar Flutter, sockets, HTTP, serial ports ni `shared_preferences`.
- `data/` contiene efectos externos: TCP, RS-232, HTTP, almacenamiento local y clientes nativos.
- Una feature no debe importar widgets internos de otra feature. Si algo se comparte de verdad, moverlo a `shared/` o `core/`.
- `platform/` no debe contener reglas de negocio; solo adapta capacidades del sistema operativo.

Ruta de migracion desde el `main.dart` actual:

1. Extraer constantes, enums y claves de preferencias sin cambiar comportamiento.
2. Extraer funciones puras y testeables: conversion de unidades, formateo de peso, parseo de lecturas y comandos de teclado.
3. Extraer persistencia a `settings_repository.dart`.
4. Separar clientes externos: TCP, RS-232, n8n y salida de teclado por plataforma.
5. Separar controladores de aplicacion para conexion, receta, licencia demo y lectura de peso.
6. Dividir la pantalla principal en paneles de presentacion pequenos.
7. Dejar `main.dart` y `app/pondera_app.dart` como capa de arranque y composicion.

Regla practica: extraer codigo desde `main.dart` solo cuando la responsabilidad este clara y el cambio pueda verificarse de forma aislada.

## Convenciones Dart/Flutter

- Seguir `package:flutter_lints/flutter.yaml`.
- Preferir widgets pequenos cuando reduzcan complejidad real.
- Mantener nombres descriptivos para estados, timers, conexiones y datos de hardware.
- Liberar recursos en `dispose`: sockets, timers, streams, puertos seriales y controladores.
- Manejar errores de red y serial sin bloquear la UI.
- Evitar valores magicos nuevos; promoverlos a constantes cuando expresen reglas del dominio.

## UI Y Experiencia De Escritorio

- Priorizar claridad operacional sobre estilo decorativo.
- Mantener estados visibles: conectado, desconectado, reconectando, leyendo, error.
- Evitar cambios que dificulten lectura rapida del peso actual.
- Los formularios de conexion deben ser tolerantes a errores y mostrar diagnosticos accionables.
- Validar que los textos importantes no se corten en ventanas pequenas.

## Integraciones Y Hardware

Al tocar Ethernet/TCP:

- Considerar timeouts, reconexion, acumuladores de bytes y mensajes parciales.
- No asumir que cada lectura llega completa en un unico paquete.

Al tocar RS-232:

- Verificar baud rate, data bits, stop bits, paridad y control de flujo.
- Manejar ausencia de puertos y desconexiones fisicas.

Al tocar n8n/HTTP:

- No hardcodear secretos.
- Mantener diagnosticos utiles sin exponer datos sensibles.
- Revisar el manejo de certificados antes de cambiar fallbacks.

## Configuracion Y Datos Sensibles

- No commitear credenciales, tokens, certificados privados ni URLs privadas nuevas sin confirmacion.
- Preferir configuracion externa para valores que cambien por cliente, entorno o despliegue.
- Si una URL, IP o parametro queda hardcodeado por necesidad temporal, marcarlo como `TODO` con contexto.

## Archivos Que Requieren Cuidado

- `pubspec.yaml`: dependencias, versiones y assets.
- `pubspec.lock`: mantener sincronizado con `pubspec.yaml`.
- `macos/Runner/*.entitlements`: permisos de plataforma.
- `macos/Runner/Info.plist`: configuracion de app macOS.
- `windows/runner/*`: comportamiento nativo Windows.
- `windows/flutter/generated_*` y `macos/Flutter/GeneratedPluginRegistrant.swift`: normalmente generados por Flutter.

## Checklist Para Cambios

- [ ] El cambio resuelve el objetivo solicitado.
- [ ] `flutter analyze` no reporta errores nuevos.
- [ ] Se revisaron estados de error relevantes.
- [ ] Se validaron recursos liberados en ciclos de conexion/desconexion.
- [ ] No se introdujeron secretos ni configuracion sensible.
- [ ] Se actualizaron tests o se dejo claro por que no aplican.
- [ ] Se verifico la plataforma afectada cuando el cambio depende de macOS o Windows.

## Pendientes De Definir

- Estrategia de configuracion por cliente o entorno.
- Politica de versionado y builds distribuibles.
- Cobertura minima de tests para parseo de lecturas y conversion de unidades.
- Flujo de QA con hardware real.
