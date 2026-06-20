# Diseño preliminar del producto territorial provincial

## Propósito

La futura página debe responder dos preguntas distintas:

1. ¿cómo varía la incidencia de pobreza entre provincias con calidad publicable?
2. ¿en qué provincias se concentra el mayor número estimado de personas en pobreza?

El mapa responde mejor la primera. La tabla ejecutiva responde mejor la segunda.

## Estructura propuesta

### 1. Encabezado

- período anual;
- indicador seleccionado;
- universo y unidad de análisis;
- nota breve de representatividad;
- vínculo a metodología.

### 2. Mapa provincial

- choropleth por tasa;
- join por `province_code`;
- estado visual específico para valores suprimidos o no publicables;
- bordes provinciales visibles;
- Galápagos desplazado y rotulado;
- nota: el área del polígono no representa población;
- fuente y vintage de geometría.

Texto mínimo:

> Galápagos se presenta en una ubicación cartográfica desplazada para facilitar la lectura. La geometría es de presentación y no debe utilizarse para mediciones espaciales.

### 3. Tabla ejecutiva

Título preferido:

> Provincias con mayor número estimado de personas en pobreza

Columnas:

- posición;
- provincia;
- personas estimadas en pobreza;
- tasa de pobreza;
- población ponderada;
- calidad;
- nota o intervalo de incertidumbre.

El ranking debe usar valores no redondeados y solo filas `rank_eligible`.

### 4. Comparación de incidencia

Un gráfico ordenado de tasas puede complementar el mapa. Debe:

- mostrar intervalos o una señal de precisión;
- separar provincias publicables de suprimidas;
- evitar afirmar diferencias cuando los intervalos son ampliamente compatibles.

### 5. Cinco ciudades principales

Sección secundaria y claramente separada del análisis provincial:

- mapa de referencia que destaque los cantones `1701`, `0901`, `0101`, `0701` y `1801`;
- resultados únicamente del dominio ENEMDU `five_cities`;
- rótulo “referencia cartográfica cantonal”;
- ninguna afirmación de pobreza para el resto del cantón si el dominio estadístico representa una ciudad o área autorrepresentada distinta.

### 6. Calidad y método

- período y fuente;
- universo;
- diseño y ponderación;
- regla de precisión;
- supresiones;
- advertencia de Galápagos;
- limitación del ranking;
- versión del lookup y geometría.

## Contrato lógico del output provincial

Llave:

```text
period + indicator_id + province_code
```

Campos mínimos:

```text
period
survey_type
domain
province_code
province_name
indicator_id
estimate
display_estimate
weighted_n
unweighted_n
quality_flag
benchmark_status
method_note
public_note
```

Campos recomendados:

```text
se
cv
df
ci_low
ci_high
suppression_flag
rank_eligible
estimated_poor_population
estimated_poor_population_se
universe
analysis_unit
weight
source_layer
lookup_version
geometry_vintage
```

## Reglas de ranking

### A. Población ponderada

Útil para describir tamaño demográfico. No debe presentarse como ranking de pobreza.

### B. Personas estimadas en pobreza

Opción principal para lectura ejecutiva nacional. Debe ser una estimación de total producida por el diseño muestral, con precisión propia.

### C. Tasa de pobreza

Útil para incidencia territorial, pero solo con calidad aceptable. No es el ranking ejecutivo preferido.

Reglas comunes:

- excluir filas suprimidas;
- no reconstruir totales con cifras redondeadas;
- no forzar cinco posiciones;
- documentar empates o inestabilidad;
- no interpretar diferencias pequeñas sin considerar incertidumbre.

## Contrato cartográfico

La geometría de presentación debe:

- contener 24 códigos provinciales únicos;
- mantener Galápagos como feature independiente;
- registrar que Galápagos está desplazado;
- estar separada del output estadístico;
- transformarse a EPSG:4326 para web;
- pasar validez, overlap, gap y orphan-join checks;
- no utilizarse para áreas, distancias o centroides analíticos.

Para una imagen estática, la geometría puede permanecer fuera del repositorio durante el build, siempre que la política de ejecución y reproducibilidad lo permita. Para un mapa interactivo sería necesario aprobar un activo geográfico simplificado y su forma de publicación.

## Estados visuales de calidad

| Estado | Tratamiento sugerido |
|---|---|
| Publicable | Color de escala normal |
| Publicable con cautela | Color más tenue y señal de advertencia |
| Suprimido/no representativo | Tramado o gris neutro, sin valor numérico |
| Sin dato | Contorno y fondo vacío |

La leyenda debe separar “sin dato” de “no publicable”.

## Pruebas antes de publicar

- 24 códigos geométricos únicos;
- cero códigos analíticos huérfanos;
- cero geometrías sin fila o con tratamiento explícito;
- una fila por llave;
- período anual;
- `domain = province`;
- códigos preservados como texto;
- supresión aplicada antes de ranking;
- ranking reproducible con valores no redondeados;
- revisión visual de Galápagos;
- revisión de Cañar y límites compartidos;
- comprobación de que la sección de ciudades usa códigos cantonales, no nombres.

## Decisión de diseño

La primera versión debe ser estática, provincial y anual. El mapa debe priorizar incidencia; la tabla debe priorizar el número estimado de personas en pobreza. La capa cantonal entra solo como referencia visual para cinco ciudades y no amplía el dominio inferencial.
