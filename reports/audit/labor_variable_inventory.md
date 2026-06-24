# Labor variable inventory

## Scope

This inventory is based only on safe repository inspection: configuration files, scripts and existing aggregate site outputs. No microdata were opened, modified or copied. Therefore, this is a design inventory, not a real-data codebook.

## Variables and fields confirmed in repository code

| Variable or field | Confirmed where | Current role | Risk |
|---|---|---|---|
| `fexp` | `scripts/03_build_annual_core.R`; validation excludes it from public outputs | Survey weight for annual poverty/deprivation calculations. | Low for existence in annual person data, but still confirm in labor build. |
| `upm` | `scripts/03_build_annual_core.R`; validation excludes it from public outputs | Survey primary sampling unit. | Low for annual design use. |
| `estrato` | `scripts/03_build_annual_core.R`; validation excludes it from public outputs | Survey strata. | Low for annual design use. |
| `area` | `scripts/03_build_annual_core.R`, `config/domains.yml` | Urban/rural domain variable. | Low for national/urban/rural labor profiles. |
| `prov` | `scripts/03_build_annual_core.R` | Province variable for annual territorial poverty. | Not recommended for first labor page without a separate labor representativity review. |
| `period` | Site outputs and annual scripts | Output period metadata. | Low. |
| `survey_type` | Site outputs and scripts | Distinguishes annual/monthly/quarterly layers. | Low. |
| `poverty_rate` | Existing site and annual outputs | Income poverty indicator. | Low as an existing analytical output; linking to labor categories still pending. |
| `extreme_poverty_rate` | Existing site and annual outputs | Extreme income poverty indicator. | Low as an existing analytical output; linking to labor categories still pending. |
| `weighted_n`, `unweighted_n` | Existing site outputs | Denominator metadata. | Low as output convention. |
| `se`, `cv`, `df` | Provincial and profile site outputs | Precision metadata where produced. | Medium for future labor outputs, depending on estimator support. |
| `quality_flag`, `suppression_flag` | Provincial output pattern | Internal publication metadata. | Medium; rules must be adapted to labor subgroups. |

## Labor indicators confirmed in configuration

| Config entry | File | Layer | Status |
|---|---|---|---|
| `five_cities_quarterly_labor` | `config/indicators.yml` | Quarterly | Configured as a future labor profile; no calculation implemented. |
| `unemployment_rate` | `config/indicators.yml` | Monthly | Configured; no calculation implemented. |
| `adequate_employment_rate` | `config/indicators.yml` | Monthly | Configured; no calculation implemented. |
| `underemployment_rate` | `config/indicators.yml` | Monthly | Configured; no calculation implemented. |

## Output routes confirmed in configuration

| Output route | File | Status |
|---|---|---|
| `monthly/monthly_labor.rds` | `config/paths.yml` | Route exists; builder scaffold does not calculate indicators. |
| `quarterly/quarterly_labor.rds` | `config/paths.yml` | Route exists; builder scaffold does not calculate indicators. |
| `annual/annual_labor.rds` | `config/paths.yml` | Route exists; no annual labor builder implemented. |

No site-level labor output route exists yet in `config/paths.yml`.

## Candidate labor variables not confirmed by current repository code

The task identified these candidate variables for future inspection:

| Candidate variable | Expected use | Current confirmation | Risk |
|---|---|---|---|
| `condact` | Labor-force or activity condition. | Not referenced in current scripts/config. | High until real data are inspected. |
| `condactn` | Alternative or normalized activity condition. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p20` | Employment/activity question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p21` | Employment/activity question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p22` | Employment/activity question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p32` | Employment quality or hours/income question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p34` | Employment quality/formality question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| `p35` | Employment quality/formality question candidate. | Not referenced in current scripts/config. | High until real data are inspected. |
| Formality/informality variables | Formal/informal employment. | No confirmed variable or definition in current code. | High. |
| Quintile variable | Income quintile by labor condition. | Config has annual quintile output route; no existing site quintile output. | Medium to high. |
| Income-poverty derived variables | Poverty status attached to person records. | Existing aggregate poverty outputs exist; row-level derived variables need implementation review. | Medium. |

## Variables detected in existing site outputs

Existing site outputs are aggregate-only and do not expose labor variables. They do confirm the monitor's output conventions:

- `site_kpis.rds`: national and urban/rural income poverty KPIs.
- `site_income_poverty_profiles.rds`: poverty profiles by age, sex and adult education.
- `site_territorial_province_income_poverty.rds`: province-level poverty and extreme-poverty aggregates.
- `site_deprivation_multidimensional_kpis.rds`: income, NBI, TPM and TPEM indicators for national and area domains.
- `site_periods.rds`, `site_sources.rds`, `site_quality_flags.rds`: metadata outputs.

No `site_labor_*` output exists.

## Pending real-data inspection

The next phase must inspect annual ENEMDU person-level data safely, without committing or copying microdata. Required checks:

1. Confirm whether `condact` and/or `condactn` exist in annual person data.
2. Extract labels and category codes for labor-force status.
3. Confirm whether employment quality categories can be derived directly or through `enemduR`.
4. Confirm whether adequate/full employment, subemployment, other non-full employment and unpaid employment are mutually exclusive categories or separate indicators.
5. Confirm whether formal/informal employment has a stable source variable or requires a documented composite rule.
6. Confirm the age variable and working-age threshold used in ENEMDU labor definitions.
7. Confirm whether poverty status can be attached at person level using existing `enemduR` variables before aggregation.
8. Confirm whether income quintiles exist in raw/derived data or require a new annual quintile output.
9. Check missing-value behavior for labor variables by universe.
10. Confirm that `fexp`, `upm`, `estrato` and `area` are present in the same data used for labor estimates.

## Risk summary by variable group

| Variable group | Risk | Reason |
|---|---|---|
| Survey design variables | Low | Already used in annual poverty/deprivation builds. |
| Urban/rural domain | Low | Already used in annual outputs. |
| Labor-force status | High | Candidate names are not referenced in current code. |
| Employment quality | High | Definitions may require multiple variables and official category mapping. |
| Formality/informality | High | No confirmed source variable or rule in current repository. |
| Poverty status by person | Medium | Aggregate poverty outputs exist, but labor cross-tabs need row-level status before aggregation. |
| Quintiles | Medium to high | Route exists, but no current site output or confirmed implementation. |
| Precision metadata | Medium | Existing outputs carry precision for some layers; labor estimator support must be verified. |

## Recommendation for phase 4N

Phase 4N should begin with a controlled annual microdata inspection step that prints only variable names, labels, category dictionaries and aggregate availability checks. It should not write microdata, expose private paths or create public pages.
