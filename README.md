# Stage1:

* Descargar el SIC desde la página de Hacienda del siguiente elnace:
https://www.hacienda.go.cr/docs/Sic_Tributacion.msi
* Instalarlo en la computadora.
* Usar accesspv para ver la contraseña del MDB de Hacienda. (adminSicH)
* Utilizar Microsoft Access para exportar las 2 tablas en CSV en codificación UTF-8

# Stage2:

* Utilizar el script process_split.sh para dar el formato correcto a las cedulas.
  Ojo, Es un script en bash.
  Se incluye un pequeño ejemplo del archivo exportado del Microsoft Access MDB a CSV para probar el script.
* Subir a MongoDB en dos collections, una para cedulas físicas y otra para jurídicas, conservando la primer fila con los nombres de columnas.
* * Se debe asegurar que el campo de CEDULA se utiliza como tipo string.
