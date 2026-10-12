# Generación y validación de recetas

`recipe_code.js` es el contenido del nodo **Code in JavaScript** del flujo de
acceso a recetas. No contiene credenciales ni configuración de licencias.
Ejecutar `node --test tool/n8n/recipe_code.test.cjs` antes de publicarlo.
Reemplazar también el mensaje de sistema de **AI Agent** con
`recipe_agent_sign_instructions.txt`; no acumular instrucciones anteriores.

## Algoritmo

1. El primer carácter del valor esperado determina si la muestra es negativa.
2. Se busca el valor absoluto en los campos numéricos de la trama, considerando
   coma/punto equivalentes y ceros iniciales. No se incluyen signos al buscarlo.
3. Si el valor esperado comienza por `-`, se ubica también un signo menos en la
   trama, antes o después del peso, incluso separado por letras o controles.
4. Se construye una expresión que capture `weight` y, solo para muestras negativas,
   `sign`. El signo acepta `-`, `+` o ausencia, con relleno horizontal variable.

La IA aporta la ubicación del campo cuando el mismo valor aparece varias veces.
El nodo usa las posiciones capturadas como referencia; no conserva anclas ni el
encabezado completo del regex propuesto. Sin una propuesta utilizable, el nodo
busca la magnitud directamente; prioriza campos decimales y, para una muestra
negativa, el campo más cercano al signo menos.

Solo se conserva el contexto vecino que distingue el peso y el texto entre peso
y signo. Los otros números dentro de ese tramo se generalizan. El encabezado y
los controles externos ETX/CR/LF no son requisitos de extracción. Se conserva el
separador y la cantidad de decimales; la parte entera puede crecer. Las capturas
no pueden ser fragmentos de otro número. No hay etiquetas ni posiciones
específicas de un modelo de indicador.

Antes de devolver la receta, el nodo comprueba que hay una única coincidencia,
que captura el campo elegido y que reconstruye el valor esperado. Los errores
mantienen la receta previa e incluyen un diagnóstico local: `magnitude` si el
peso está ausente, `sign` si una muestra negativa carece de menos, o `extraction`
si no se pudo aislar inequívocamente el campo.

`AI Agent.output` puede ser texto JSON u objeto JSON. **Respond to Webhook** sigue
enviando únicamente `$json.response`; el diagnóstico permanece en n8n. El sobre
de autorización, la acción de receta y los datos de licencia se conservan.
No cambiar conexiones, credenciales, validación de solicitudes, SQL ni autorización.
Conservar el historial del flujo para poder restaurar la versión anterior. Los
snapshots completos deben guardarse fuera del repositorio por su configuración
privada. No probar el generador con solicitudes ficticias a licencias de producción.

## Compatibilidad y captura

Pondera combina los grupos `weight` y `sign` y sigue aceptando las recetas
anteriores con una captura. La decodificación TCP/RS-232 no se modifica.
La muestra enviada queda fija y visible en el diálogo del valor esperado. Si
contiene un único número, la app sugiere ese peso. La app valida la receta contra
esa misma muestra antes de guardarla.

En F12 y captura automática, una muestra negativa define el retorno de tara:
con `-0.20`, se vuelve a `-0.20` para habilitar otra captura. Con una muestra
positiva o cero se vuelve a cero y solo se registran pesos positivos. El punto
de retorno se deriva de la receta y no se suma ni resta al peso recibido.

Las pruebas incluyen BR-15 `+000.562kg` y GI-410 con `  -B` y `   B`.
La regresión de la ejecución 1591 verifica que una receta creada con encabezado,
ETX y CR/LF también lee las muestras del operador sin ese envoltorio. Se prueban
valores repetidos, signo antes/después, caracteres especiales, cambios de peso,
crecimiento de la parte entera y límites de captura numérica.

Después de publicar, solicitar una receta nueva: las recetas ya guardadas no se
reescriben automáticamente. Verificar con hardware el refresco del peso y el
retorno a cero o tara entre capturas. Las pruebas locales comprueban las tramas
capturadas y la integración con Dart; no certifican drivers ni hardware de otros
equipos. Mantener la verificación de errores de red y de autorización existente.

## Protección de identidad de instalación

`sql/20261002_prevent_duplicate_installations.sql` protege las dos rutas que
pueden registrar equipos. Serializa por producto y huella física y rechaza una
identidad nueva cuando el mismo equipo ya está registrado. No borra ni fusiona
duplicados históricos; estos deben revisarse manualmente antes de agregar una
restricción única a la tabla.
