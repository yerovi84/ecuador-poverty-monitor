# Auditoría de factibilidad geoespacial territorial

## Conclusión ejecutiva

La fuente geográfica local reorganizada contiene tres capas lógicas:

1. una referencia provincial detallada con 23 provincias codificadas, cinco zonas en estudio y una entidad genérica de islas;
2. una geometría provincial simplificada con los 24 códigos DPA y Galápagos desplazado;
3. una referencia cantonal con 218 cantones continentales, cinco zonas en estudio y una entidad genérica de islas.

La mejor capa para el futuro mapa provincial de reporte es `PROVINCIA_INEC_EDIT.json`. Tiene 24 códigos provinciales únicos, geometría ligera y una composición que acerca Galápagos al continente. Debe identificarse expresamente como **cartographic presentation geometry**: es adecuada para un mapa estático de comunicación, pero no representa la posición geográfica exacta y no debe usarse para áreas, distancias, centroides analíticos, vecindad real ni otras mediciones espaciales.

La página territorial sigue condicionada a un output ENEMDU anual, agregado y validado por provincia. Los outputs actuales solo contienen dominios nacional y urbano/rural, además de perfiles no territoriales. No se calcularon indicadores nuevos en esta fase.

La capa cantonal existe y permite ubicar los cinco cantones de referencia:

| Ciudad configurada | Código cantonal | Nombre en la capa |
|---|---:|---|
| Quito | `1701` | DISTRITO METROPOLITANO DE QUITO |
| Guayaquil | `0901` | GUAYAQUIL |
| Cuenca | `0101` | CUENCA |
| Machala | `0701` | MACHALA |
| Ambato | `1801` | AMBATO |

Debe usarse únicamente como referencia visual para esos dominios de ciudad. No sustenta estimaciones cantonales de pobreza.

## 1. Inventario recursivo

El inventario recursivo encontró 17 componentes que representan dos shapefiles y un JSON geográfico:

- grupo provincial: ocho componentes del shapefile detallado y un JSON provincial;
- grupo cantonal: ocho componentes del shapefile cantonal.

No se encontraron capas parroquiales, zonales o sectoriales dentro de las carpetas geográficas reorganizadas.

## 2. Capa provincial detallada

La referencia detallada tiene 29 features:

- 23 códigos provinciales oficiales;
- cinco features con código `90`;
- un feature `ISLA`.

El código provincial `20` no está representado como provincia. Por ello, `DPA_PROVIN` no es una llave completa ni única para un mapa de 24 provincias.

La capa tiene 1,520,232 coordenadas y es excesivamente detallada para publicación web directa. Sus 28 componentes menores de 0.01 km² pertenecen al feature genérico `ISLA`; deben tratarse como islas pequeñas potencialmente legítimas, no eliminarse automáticamente como slivers.

No hay geometrías inválidas, vacías ni solapamientos positivos.

## 3. Geometría provincial de presentación

La capa simplificada tiene:

- 24 códigos DPA provinciales únicos;
- 24 nombres únicos;
- 24 geometrías válidas y no vacías;
- 28,376 coordenadas;
- ausencia de piezas menores de 0.1 km²;
- EPSG:32717.

Galápagos aparece con centroide cartográfico aproximado en longitud -84.87 y latitud -0.20 después de interpretar el CRS. Esta posición confirma una composición desplazada hacia el continente, coherente con el propósito editorial informado por el usuario. La geometría debe rotularse en el mapa, por ejemplo:

> Galápagos se muestra en una ubicación cartográfica desplazada para mejorar la legibilidad. Su posición no representa la localización geográfica exacta.

El desplazamiento es aceptable para:

- mapas estáticos de reporte;
- comparación visual de tasas o categorías;
- una composición nacional en un solo panel.

No es aceptable para:

- cálculo o comparación de áreas;
- distancias al continente o entre provincias;
- centroides analíticos;
- relaciones de proximidad, vecindad o conectividad;
- análisis geodésico o espacial.

## 4. Validez, solapamientos, huecos y diferencias

### Validez individual

Las tres capas tienen cero geometrías inválidas y cero geometrías vacías. `st_make_valid()` sería una salvaguarda reproducible, pero actualmente no modificaría el problema principal porque los polígonos provinciales simplificados ya son válidos individualmente.

### Solapamientos provinciales

La geometría de presentación tiene 53 pares con solapamiento positivo:

- área total superpuesta: 7.622 km²;
- mediana por par: 0.108 km²;
- máximo: 1.097 km²;
- proporción respecto del área sumada de features: aproximadamente 0.003%.

La gravedad es:

- **baja para renderizado estático**, si se dibujan bordes y se revisa visualmente;
- **no aceptable para análisis espacial**, porque dos provincias reclaman pequeñas áreas comunes;
- **insuficiente para decidir propiedad territorial**, ya que una operación automática por orden asignaría cada solapamiento de forma arbitraria.

### Diferencias frente a la referencia detallada

Las capas comparten 23 códigos provinciales. La diferencia geométrica simétrica media es 1.282% respecto de la referencia detallada. Los mayores casos son:

| Código | Provincia | Diferencia aproximada |
|---:|---|---:|
| `03` | Cañar | 15.885% |
| `06` | Chimborazo | 3.350% |
| `09` | Guayas | 3.196% |
| `02` | Bolívar | 2.278% |

La diferencia de Cañar no es un simple defecto de validez y no debe corregirse por intuición. Requiere confirmar la fuente cartográfica que debe gobernar el producto.

### Cobertura cantonal

La capa cantonal tiene cero solapamientos positivos. Para los 23 códigos provinciales compartidos, la unión de cantones coincide con la geometría provincial detallada, sin diferencias medibles a la precisión del análisis.

El cantón Cañar contiene dos anillos interiores que suman aproximadamente 116.414 km². No constituyen huecos de la cobertura provincial: la unión de cantones de la provincia reproduce exactamente la referencia provincial. Son parte de la partición interna y no deben rellenarse automáticamente.

No se detectaron huecos evidentes en la cobertura de las 23 provincias continentales compartidas. No es posible certificar ausencia de huecos territoriales nacionales para Galápagos porque la capa cantonal no incluye sus tres cantones.

## 5. ¿Puede sanearse la geometría provincial?

### Operaciones seguras

Son seguras y documentables:

1. validar y, si fuera necesario, ejecutar `st_make_valid()`;
2. normalizar códigos como texto de dos caracteres;
3. excluir explícitamente `90` e `ISLA` de joins provinciales;
4. reproyectar la geometría de presentación desde EPSG:32717 a EPSG:4326 para salidas web;
5. comprobar duplicados, vacíos, overlaps y cobertura después de cada transformación;
6. mantener Galápagos como feature separado y etiquetado como desplazado.

### Operaciones que no son seguras sobre el JSON actual

No se recomienda:

- aplicar `st_difference()` en orden de filas para eliminar overlaps;
- usar `buffer(0)` esperando que resuelva la propiedad territorial;
- recortar límites manualmente;
- completar diferencias de Cañar por inspección visual;
- usar Google u otra cartografía no autorizada para modificar límites.

Estas operaciones pueden producir geometrías válidas, pero asignar territorio a la provincia equivocada.

### Procedimiento recomendado

La vía reproducible preferida para una futura geometría limpia es:

1. confirmar la fuente cartográfica autorizada;
2. disolver la cobertura cantonal por `DPA_PROVIN` para reconstruir las 23 provincias continentales con límites compartidos;
3. excluir códigos `90` e `ISLA` del dissolve provincial;
4. incorporar por separado la geometría desplazada de Galápagos;
5. ejecutar validación geométrica y de cobertura;
6. simplificar todas las provincias mediante un algoritmo que preserve topología compartida, no feature por feature;
7. reproyectar a EPSG:4326;
8. verificar 24 códigos únicos, cero overlaps materiales y cero huérfanos de join;
9. revisar visualmente bordes, islas y la composición de Galápagos;
10. guardar cualquier derivado únicamente fuera del repositorio, con sufijo `_presentation_cleaned`.

No se creó una geometría derivada en esta fase. Antes de hacerlo debe resolverse la discrepancia de Cañar y confirmarse la fuente cartográfica.

## 6. Capa cantonal y cinco ciudades

La capa cantonal tiene 224 códigos únicos:

- 218 cantones continentales con código DPA de cuatro caracteres;
- cinco zonas en estudio con prefijo `90`;
- un feature `ISLA`;
- no contiene los tres cantones de Galápagos.

En los 218 registros cantonales oficiales continentales, los dos primeros caracteres de `DPA_CANTON` coinciden con `DPA_PROVIN`.

Los nombres `BOLIVAR` y `OLMEDO` aparecen en dos provincias cada uno. Esto confirma que un join por nombre cantonal no es defendible; debe usarse `DPA_CANTON`.

Para Quito debe usarse `1701`: una búsqueda textual de “Quito” también encuentra `1709`, Puerto Quito.

La capa puede:

- delinear o destacar visualmente los cinco cantones;
- aportar una referencia cartográfica a resultados del dominio `five_cities`;
- permitir QA de códigos y nombres.

La capa no puede, por sí sola:

- convertir un resultado de ciudad en estimación cantonal;
- justificar un mapa cantonal de pobreza;
- cubrir todo Ecuador a nivel cantonal debido a la ausencia de los cantones de Galápagos.

## 7. Compatibilidad con ENEMDU y outputs actuales

El contrato del repositorio permite:

- provincia únicamente en la capa anual;
- cinco ciudades en capas trimestral y anual;
- ningún uso inferencial de cantón o parroquia.

Los outputs anuales presentes contienen solo:

- nacional;
- urbano/rural;
- perfiles por sexo, edad y educación.

No existen todavía `annual_territory.rds` ni `annual_representativity.rds`, y ningún output actual ofrece 24 filas provinciales con código DPA y calidad.

La geometría permite diseñar el producto, pero los datos actuales no permiten publicarlo.

## 8. “Cinco principales provincias”

El término debe explicitar el criterio. Se comparan tres alternativas:

| Alternativa | Interpretación | Ventaja | Riesgo |
|---|---|---|---|
| A | Mayor población ponderada | Da contexto demográfico | No identifica dónde se concentra la pobreza |
| B | Mayor número estimado de personas en pobreza | Responde a la carga nacional de pobreza | Requiere estimación de total y calidad suficiente |
| C | Mayor tasa de pobreza | Compara incidencia territorial | Puede premiar tasas inestables o poblaciones pequeñas |

Recomendación:

- usar **B** como tabla ejecutiva principal;
- usar tasas provinciales para comparación territorial solo cuando `quality_flag` permita publicación;
- presentar **A** como contexto opcional;
- no completar artificialmente cinco filas si menos de cinco provincias pasan el contrato de calidad.

El número de personas en pobreza debe provenir de una estimación survey-weighted de total con sus medidas de precisión. No debe reconstruirse en la capa pública multiplicando una tasa redondeada por una población redondeada.

## 9. Contrato mínimo de calidad provincial

Una provincia puede entrar al mapa o ranking solo si:

- pertenece al período anual y `domain = province`;
- su código DPA es válido y único;
- el universo y la unidad de análisis corresponden al indicador;
- tiene estimación, tamaño muestral y población ponderada;
- tiene error estándar, CV o la métrica de precisión adoptada;
- `quality_flag` autoriza publicación;
- no está suprimida;
- la regla de representatividad está documentada;
- los joins con geometría y lookup no tienen huérfanos;
- el ranking se calcula antes del formateo y redondeo.

Los umbrales numéricos de CV, muestra o grados de libertad deben definirse en el futuro contrato de representatividad; esta auditoría no inventa valores.

## 10. Outputs agregados necesarios

El futuro output curado territorial debe incluir como mínimo:

- `period`;
- `survey_type`;
- `domain = province`;
- `province_code`;
- `province_name`;
- `indicator_id`;
- `estimate`;
- `display_estimate`;
- `weighted_n`;
- `unweighted_n`;
- `quality_flag`;
- `benchmark_status`, cuando aplique;
- `method_note`;
- `public_note`.

Para mapa, precisión y ranking también se recomiendan:

- `se`, `cv`, `df`, límite inferior y superior;
- `estimate_status`, `suppression_flag` y `rank_eligible`;
- `estimated_poor_population` como estimación directa de total;
- precisión asociada al total estimado;
- universo, unidad de análisis, peso y fuente;
- versión de lookup y versión/vintage de geometría.

El output analítico no debe contener geometría. La geometría y los indicadores agregados deben permanecer separados hasta el join de presentación.

## 11. Decisión de factibilidad

| Componente | Decisión |
|---|---|
| Mapa provincial anual estático | Viable después de crear y validar outputs provinciales |
| Geometría con Galápagos desplazado | Aceptable como geometría cartográfica de presentación |
| Análisis espacial exacto con esa geometría | No viable |
| Tabla top 5 por personas en pobreza | Viable si existe estimación de total y calidad provincial |
| Ranking por tasa | Solo para provincias elegibles por calidad |
| Referencia de cinco ciudades | Viable mediante códigos cantonales específicos |
| Mapa cantonal de pobreza | No defendible bajo el contrato actual |

## 12. Comandos y procedimientos ejecutados

- confirmación de rama y estado Git;
- inventario recursivo de componentes geográficos;
- lectura de DBF, PRJ, CPG, XML y JSON;
- auditoría temporal con `pyshp`, `shapely` y `pyproj`;
- revisión de CRS, campos, códigos, nombres, bounding boxes y complejidad;
- pruebas de validez, vacíos, solapamientos, piezas pequeñas y anillos interiores;
- comparación de cobertura cantonal contra referencia provincial;
- comparación de la geometría provincial de presentación contra la referencia detallada;
- inspección de contratos YAML y schemas RDS actuales.

## 13. Riesgos abiertos

- autoridad y vigencia de la fuente de límites;
- discrepancia material de Cañar entre referencia y presentación;
- ausencia de cantones de Galápagos en la capa cantonal;
- falta de contrato numérico de precisión provincial;
- falta de outputs provinciales agregados;
- decisión pendiente sobre almacenamiento o generación de la geometría web;
- necesidad de indicar visualmente el desplazamiento de Galápagos;
- posible inestabilidad de rankings provinciales ante incertidumbre muestral.

## 14. Validación

- no se modificaron fuentes geográficas;
- no se creó geometría derivada;
- no se copiaron geodatos al repositorio;
- no se modificaron microdatos, scripts, outputs analíticos ni páginas;
- no se guardaron rutas privadas;
- no se realizó commit ni push.
