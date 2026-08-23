Batch_C3D_to_RCNL2025_TRC_noBTK_v3_forceSacral.m
==================================================

Objetivo
--------
Convertir todos los C3D de una carpeta en TRC compatibles con RCNL2025, asegurando que TODOS los TRC exportados incluyan el marcador Sacral.

Uso
---
1. Coloca en la misma carpeta:
   - C3D_to_TRC_RCNL2025_forceSacral.m
   - RCNL2025.osim
   - todos los archivos .c3d

2. En MATLAB:
   cd('C:\ruta\a\tu\carpeta')
   C3D_to_TRC_RCNL2025_forceSacral

3. El script creará:
   TRC_files_RCNL2025_forceSacral

Criterio de creación de Sacral
------------------------------
Para cada frame, el script construye Sacral con esta jerarquía:

1. Si existe SACR real y es válido: Sacral = SACR.
2. Si no existe SACR, pero existen LPSI y RPSI: Sacral = punto medio entre LPSI y RPSI.
3. Si solo existe un PSIS y existen LASI/RASI: se mantiene X/Y del PSIS disponible y se coloca Z en la línea media de los ASIS.
4. Si solo existe un PSIS y existen C7/T10: se coloca el marcador sobre la línea vertical posterior C7-T10 a la altura del PSIS.
5. Si no hay PSIS pero existen LASI/RASI y C7/T10: se coloca sobre la línea vertical posterior C7-T10 a la altura media de los ASIS.
6. Como último recurso, usa el punto medio de LASI/RASI. Esta opción se marca como muy baja confianza.

Importante
----------
Cuando Sacral no procede de un marcador físico SACR, debe documentarse como marcador estimado/pseudo-marcador. En el informe de salida se indica qué método se ha usado y en cuántos frames.
