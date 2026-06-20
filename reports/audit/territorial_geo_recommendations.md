# Recomendaciones para la capa territorial

## Recomendación principal

Avanzar con una futura página provincial anual, usando la capa de 24 provincias como **cartographic presentation geometry** y manteniendo separados:

- el output estadístico provincial;
- el lookup DPA;
- la geometría de presentación;
- la capa cantonal de referencia.

La página no debe construirse hasta que existan estimaciones provinciales agregadas, precisión y reglas de supresión.

## Geometría provincial

Usar provisionalmente `PROVINCIA_INEC_EDIT.json` para el diseño del mapa porque:

- cubre las 24 provincias;
- `provincia` es una llave DPA única;
- la complejidad es razonable para un mapa estático;
- Galápagos ya está compuesto cerca del continente.

Condiciones:

1. rotular el desplazamiento de Galápagos;
2. no usar la capa para mediciones espaciales;
3. reproyectar a EPSG:4326 antes de una salida web;
4. no corregir overlaps mediante orden arbitrario;
5. resolver la discrepancia de Cañar antes de declarar la geometría como fuente territorial exacta.

Los 53 overlaps suman solo 7.622 km² y son tolerables para un primer prototipo estático, pero deben permanecer como una deuda cartográfica explícita.

## Saneamiento recomendado

No se recomienda “limpiar” directamente el JSON mediante `buffer(0)` o diferencias secuenciales.

La alternativa segura es reconstruir las 23 provincias continentales desde límites cantonales compartidos, incorporar Galápagos desplazado como feature independiente y ejecutar una simplificación topológica conjunta. Este proceso requiere:

- fuente autorizada;
- QA de 24 códigos;
- comprobación de overlaps y huecos;
- revisión visual;
- un derivado externo no versionado.

Si no se valida una fuente autorizada, usar la geometría actual únicamente con la advertencia metodológica y sin afirmar exactitud limítrofe.

## Capa cantonal

Usarla para destacar:

- Quito: `1701`;
- Guayaquil: `0901`;
- Cuenca: `0101`;
- Machala: `0701`;
- Ambato: `1801`.

No unir por nombre. No interpretar los polígonos como dominios cantonales de pobreza. La capa tampoco es una cobertura cantonal nacional completa porque no contiene los cantones de Galápagos.

## Tabla de cinco provincias

Orden de preferencia:

1. cinco provincias con mayor número estimado de personas en pobreza;
2. población ponderada como contexto;
3. tasa de pobreza solo entre provincias elegibles por calidad.

Cada tabla debe nombrar el criterio en el título. Si menos de cinco provincias cumplen calidad, publicar menos filas y explicar la supresión.

## Puertas de publicación

El producto provincial es publicable cuando:

- existen 24 códigos provinciales o supresiones explícitas;
- no hay duplicados ni huérfanos de join;
- las estimaciones son anuales;
- precisión, representatividad y supresión están documentadas;
- el mapa diferencia valores publicables y no publicables;
- la geometría tiene procedencia y vintage;
- Galápagos está identificado como desplazado;
- la tabla top 5 usa estimaciones no redondeadas y elegibilidad de ranking.

Hasta entonces, la recomendación es publicar únicamente documentación metodológica, no resultados provinciales.
