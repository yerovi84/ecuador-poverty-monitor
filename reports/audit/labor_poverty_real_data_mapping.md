# Labor Poverty Real Data Mapping

Project: Ecuador Poverty Monitor  
Phase: 4N labor real-data inspection and output build  
Source scope: ENEMDU annual 2025 person-level microdata, inspected through the project raw-data environment variable only. No private path, row-level record, household identifier, person identifier, survey design variable name, or survey design value is stored in this report.

## Inspection Result

Annual inputs were available through the local environment variable during QA. The person file was read with `enemduR::enemdu_read_data()` and transformed with `enemduR::enemdu_build_variables()`.

Safe inspection summary:

| Variable | Status | Use in this phase |
| --- | --- | --- |
| `condact` | Confirmed in raw and built data | Core labor condition variable |
| `condactn` | Not present | Not used |
| `p03` | Confirmed | Age filter for population age 15 and older |
| `p20`, `p21`, `p22`, `p32`, `p34`, `p35` | Confirmed | Documented as labor survey inputs; not used to reconstruct `condact` |
| `pobreza` | Confirmed | Income poverty status for labor profiles |
| `epobreza` | Confirmed | Extreme income poverty status for labor profiles |
| `ingtot_pc` | Confirmed after `enemduR` build | Available for audit, but not used to recompute poverty in this phase |
| `area` | Confirmed | National, urban, and rural domains |
| Survey design inputs | Confirmed | Internal estimation only; names and values are not stored in this report or in public outputs |

## Confirmed `condact` Categories

The annual 2025 activity-condition variable exposes the expected 10-code structure:

| Code | Label | Phase mapping |
| --- | --- | --- |
| 0 | Menores de 15 anos | Excluded from working-age labor denominators |
| 1 | Empleo Adecuado/Pleno | Employed; adequate/full employment |
| 2 | Subempleo por insuficiencia de tiempo de trabajo | Employed; subemployment |
| 3 | Subempleo por insuficiencia de ingresos | Employed; subemployment |
| 4 | Otro empleo no pleno | Employed; other non-full employment |
| 5 | Empleo no remunerado | Employed; unpaid employment |
| 6 | Empleo no clasificado | Employed; unclassified employment |
| 7 | Desempleo abierto | Unemployed |
| 8 | Desempleo oculto | Unemployed |
| 9 | Poblacion Economicamente Inactiva | Outside the labor force |

## Output Decision

Because `condact` was confirmed, the phase proceeds beyond mapping and writes aggregate-only outputs:

- `data/derived/annual/annual_labor_poverty.rds`
- `data/derived/site/site_labor_poverty_profiles.rds`

The annual output uses only aggregate estimates and metadata. It does not include raw microdata identifiers or survey design columns.

## Indicators Built

The output includes national, urban, and rural rows for:

- `labor_force_participation_rate`
- `employment_rate_working_age`
- `outside_labor_force_share`
- `unemployment_rate`
- `adequate_employment_rate`
- `subemployment_rate`
- `poverty_rate_by_labor_status`
- `extreme_poverty_rate_by_labor_status`
- `estimated_poor_by_labor_status`

Unemployment is estimated over the labor force denominator. Adequate/full employment and subemployment are estimated over employed people age 15 and older. Poverty profiles use people age 15 and older by labor-market status with valid annual poverty flags.

## Deferred Scope

Formal employment is not built in this phase because a defensible formal/informal classification was not confirmed from the inspected variable set. Quintile outputs are also deferred because no compatible annual quintile rule was confirmed in the current pipeline during this phase.

## Safety Notes

The report intentionally avoids storing private raw-data paths, row examples, personal identifiers, household identifiers, survey design variable names, and survey design values. The build uses the survey design internally and writes aggregate-only estimates with quality and suppression flags.
