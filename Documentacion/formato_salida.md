# Formato de salida — Pondera 1.0.12

El peso correspondiente a la muestra sirve para comprobar la receta. Debe ser
el peso completo que muestra el indicador: si envía `+000.508kg`, se ingresa
`0.508` o `0,508`. Este valor también conserva la referencia de tara cuando es
negativo.

En **Formato de salida**, debajo de **Unidades de medida**, se eligen tres
opciones independientes:

- **Separador decimal:** como muestra el indicador, punto o coma. La primera
  opción sigue el separador del peso recibido, aunque al crear la receta se
  haya ingresado otro separador.
- **Cantidad de decimales:** como en la lectura, o un número fijo entre 0 y 6.
- **Al reducir decimales:** redondear o recortar sin redondear.

Para escribir `0,51` en Excel a partir de `0.508`, seleccionar **Coma (,)**,
**2 decimales** y **Redondear**. Para escribir `0,50`, cambiar la última opción
a **Recortar (sin redondear)**. Se completan los ceros necesarios: `0.5` se
escribe `0,50` con dos decimales.

El redondeo lleva las mitades al valor de mayor magnitud: `1.005` produce `1,01`
y `-1.005` produce `-1,01`. El recorte elimina los decimales sobrantes hacia cero:
`-0.508` produce `-0,50`. Un resultado de cero se muestra sin signo negativo.

La vista previa usa la última lectura válida del indicador y se actualiza con
cada peso recibido y cada cambio de formato o unidades. Muestra **Peso recibido**,
**Se escribirá** y la unidad de salida. Si todavía no hay una lectura válida,
se muestra un mensaje de espera. Al desconectar o cambiar la receta, se espera
una lectura nueva; no se conserva una vista previa de la conexión anterior.

El formato se aplica después de convertir las unidades, tanto al peso mostrado
como al enviado por teclado. La vista previa usa el mismo cálculo que la salida.
El peso completo sigue determinando la estabilidad, el rango, la tara y el
retorno a cero. Un peso pequeño distinto de cero puede escribirse `0,00` si así
lo establece el formato; no se convierte por ello en un retorno a cero.

Los cambios se guardan automáticamente y se usan desde la siguiente lectura.
No hace falta crear otra receta ni acceder a internet. También se conservan al
reiniciar Pondera o sustituir la receta. De forma predeterminada se mantiene el
separador y la cantidad de decimales del indicador.
