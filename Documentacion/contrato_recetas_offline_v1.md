# Contrato v1: recetas offline de Bitgenial para Pondera

Estado: cliente implementado en 1.0.10+11; servicio emisor pendiente. Este documento
fija el contrato que deberá implementar el servicio. No se desplegó ni se
modificó n8n, el servidor, la base de datos o sus credenciales en esta etapa.

## Solicitud

Archivo UTF-8 JSON compacto, extensión `.bitgenial-recipe-request`, sin BOM.
El orden de los campos es el producido por `OfflineRecipeRequest.encode()`.
El servicio calcula SHA-256 sobre los bytes originales subidos, sin volver a
serializar ni modificar la trama. Base64url se emite sin padding en todo el
protocolo. Los archivos de respuesta se limitan a 131072 bytes.

Campos exactos:

- `schema_version`: número 1.
- `type`: `bitgenial.pondera.recipe-request`.
- `product`: `pondera`.
- `request_id`: identificador aleatorio `RAC-<UUID v4>`.
- `installation_id`, `device_fingerprint_hash`.
- `license_id`, `license_file_sha256` (formato existente `sha256:<hex>`).
- `license_document`: texto exacto del documento de licencia firmado instalado.
- `recipient_public_key`: clave pública X25519 de 32 bytes, base64url.
- `cipher`: `X25519-HKDF-SHA256-A256GCM`.
- `platform`, `app_version`.
- `created_at`: ISO 8601 UTC terminada en `Z`; no es una hora de confianza.
- `trama`: muestra exacta, máximo 8192 caracteres, controles escapados por JSON.
- `valor_esperado`: peso numérico con signo opcional y coma/punto decimal.

La clave privada X25519 no sale del PC. Está en FlutterSecureStorage usando el
mismo perfil de protección que la identidad de instalación. Los datos activos
y la solicitud pendiente se mantienen fuera de ese almacén para que Lab Reset
los retire, conservando identidad y claves.

## Autorización que deberá realizar el servidor

La solicitud es entrada no confiable. Antes de emitir una receta, el servidor
debe verificar la firma real del documento de licencia; calcular su hash; cotejar
producto, instalación, licencia y huella con sus registros; y comprobar su
vigencia, gracia y ausencia de revocación/bloqueo. No confiar en nombres,
identificadores ni fechas aportados por el cliente sin cotejarlos.

Este canal no emite trials ni renueva licencias. El servidor debe comprobar el
regex contra la muestra y el peso solicitado. Debe conservar los valores exactos
`trama` y `valor_esperado` en la respuesta cifrada. No enviar una clave privada al
cliente ni exponer la clave de firma en la interfaz para operadores.

## Cifrado de la respuesta

1. Generar un par X25519 efímero nuevo por respuesta.
2. Calcular ECDH X25519 entre la privada efímera y `recipient_public_key`.
   Rechazar secretos compartidos completamente cero.
3. `request_sha256` es base64url de SHA-256 de los bytes de la solicitud original.
4. Derivar 32 bytes con HKDF-SHA256: IKM = secreto ECDH; salt = los 32 bytes de
   SHA-256 de solicitud; info = UTF-8 de `bitgenial:pondera:recipe-encryption:v1`.
5. Cifrar con AES-256-GCM. Nonce aleatorio nuevo de 12 bytes; AAD = los 32 bytes
   de SHA-256 de la solicitud; etiqueta GCM de 16 bytes.
6. El texto claro es UTF-8 JSON con exactamente `regex_pattern`, `trama` y
   `valor_esperado`. El regex debe ser compatible con el lector Dart de Pondera,
   incluyendo grupos `weight` y `sign` si corresponden.

## Payload firmado

UTF-8 JSON con exactamente estos campos; su orden es libre porque se firman
sus bytes originales y se transportan completos en base64url:

- `schema_version`: 1; `type`: `bitgenial.pondera.recipe-response`.
- `product`: `pondera`; `cipher`: `X25519-HKDF-SHA256-A256GCM`.
- `recipe_id`: identificador de emisión; `request_id`.
- `request_sha256`.
- `installation_id`, `device_fingerprint_hash`, `license_id`, `license_file_sha256`.
- `recipient_public_key`, `ephemeral_public_key` (ambas X25519 de 32 bytes).
- `issued_at`: hora UTC real del emisor, ISO 8601 terminada en `Z`.
- `valid_until`: UTC terminada en `Z`, como máximo el final de la gracia de la
  licencia; si no hay gracia, su vencimiento. Solo puede ser null con licencia
  perpetua sin vencimiento. Nunca se amplía la vigencia de la licencia local.
- `nonce`, `ciphertext`, `mac`: base64url sin padding.

Se firma Ed25519 sobre la concatenación de:

1. UTF-8 de `bitgenial:pondera:recipe-response:v1`.
2. Un byte cero (`00`).
3. Los bytes originales del payload JSON.

Este prefijo separa la firma de recetas de las firmas de licencias. No se firma
la representación base64url, y no se usa el sobre de licencia como receta.

## Sobre final `.bitgenial-recipe`

JSON UTF-8 con exactamente:

```json
{
  "schema_version": 1,
  "type": "bitgenial.pondera.recipe-response",
  "algorithm": "Ed25519",
  "key_id": "bitgenial-licensing-prod-2026-01",
  "payload": "<base64url del payload firmado>",
  "signature": "<base64url de firma Ed25519 de 64 bytes>"
}
```

La clave privada correspondiente ya pertenece a la infraestructura de firma de
Bitgenial. Este cambio solo usa sus claves públicas existentes; no genera ni
distribuye nuevas claves privadas de producción. Las claves de desarrollo se
aceptan únicamente en compilaciones de depuración y pruebas.

## Comprobaciones y persistencia del cliente

La aplicación verifica firma antes de descifrar; campos/algoritmos/versiones
exactos; destinatario, huella, licencia y su hash; clave receptora propia;
solicitud pendiente y su digest; vigencia; MAC; muestra y peso exactos; y una
única extracción numérica correcta. La hora de emisión admite como máximo cinco
minutos de adelanto sobre el reloj local, cuya licencia se valida por separado.

Se persiste el sobre cifrado y firmado completo, no el regex descifrado. Se
verifica de nuevo al arrancar y se respeta su vencimiento durante la ejecución.
No se aceptan campos antiguos `pondera_recipe` como autorización.

La ruta online existente sigue autorizándose mediante el servicio HTTPS actual.
Sus respuestas nuevas se guardan en una caché AES-256-GCM local autenticada,
ligada a instalación/huella/licencia/hash. Su clave de 32 bytes se deriva con
HKDF-SHA256 del secreto local de instalación para recetas, salt UTF-8
`bitgenial:pondera:recipe-storage:v1`, info UTF-8 `AES-256-GCM`. AAD tiene ese mismo
contexto de almacenamiento. Esto no sustituye por una firma de servidor las
respuestas online existentes; su unificación futura debe conservar este contrato.

Una revocación nueva solo puede conocerse al reconectar. El archivo de receta
no recupera bloqueos horarios, no elimina una revocación conocida y no altera
la licencia. No se promete impedir la modificación del ejecutable por alguien
que controle el equipo.
