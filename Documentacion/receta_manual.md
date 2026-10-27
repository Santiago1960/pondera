# Receta autorizada sin internet — Pondera 1.0.10

El PC del cliente no necesita acceder a internet. Necesita una licencia importada
vigente y un medio para entregar y recibir archivos. Una demo local no permite
usar esta modalidad.

1. Conectar el indicador y recibir una trama en Pondera.
2. En «Receta de lectura», elegir «Solicitar receta sin internet».
3. Revisar la muestra fija e introducir su peso correspondiente. La trama se
   copia automáticamente, incluidos sus controles; no se transcribe.
4. Guardar el archivo `.bitgenial-recipe-request` y enviarlo a Bitgenial desde
   cualquier dispositivo que tenga conexión.
5. Bitgenial procesa el archivo en su servicio y entrega la respuesta
   `.bitgenial-recipe`, cifrada para ese PC y firmada por Bitgenial.
6. En Pondera elegir «Cargar receta autorizada» y seleccionar la respuesta.
   No es necesario volver a recibir exactamente el mismo peso al importarla:
   se comprueba contra la muestra original de la solicitud.
7. Comprobar la lectura y las capturas con diferentes pesos y retorno a cero o
   tara. Si se usa tara, solicitar la receta con la muestra negativa que define
   ese punto de retorno, igual que en el proceso por internet.

Solo se mantiene una solicitud pendiente. Guardar una nueva sustituye a la
anterior. Una respuesta incorrecta no elimina la solicitud ni la receta activa.
Una actualización online correcta sustituye la receta e invalida la solicitud
pendiente. Se puede volver a importar la respuesta que ya esté activa.

La respuesta no activa ni renueva la licencia. Otra instalación, otra licencia,
una firma inválida o una respuesta modificada se rechazan. La receta se conserva
protegida y se verifica nuevamente al abrir Pondera. La expresión no se muestra
ni se admite su ingreso libre.

Las recetas antiguas guardadas sin protección necesitan generarse nuevamente
una vez después de actualizar a 1.0.10. Se conservan la licencia, la conexión y
las demás preferencias. Las recetas online nuevas también quedan protegidas
localmente y asociadas a la instalación/licencia que las obtuvo.

El servicio emisor es la siguiente etapa. La parte de Pondera se prueba con
respuestas generadas exclusivamente con claves públicas de prueba; esas firmas
no se aceptan en el instalador de producción.

## Limpieza del equipo del cliente

Con Pondera cerrado y usando la cuenta habitual, Pondera Lab Reset 1.1.0 respalda
y retira los datos locales, incluyendo receta, solicitud pendiente y referencia
horaria. Conserva la identidad y el almacén seguro de claves del equipo. Luego
se instala 1.0.10, se importa la licencia vigente y se configura la conexión.
El control horario existente no se modifica con esta versión.
