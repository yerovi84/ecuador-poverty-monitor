# Labor and poverty output contract

## Purpose

This document defines the technical, methodological and editorial contract for a future labor-and-poverty layer in the Ecuador Poverty Monitor. It is a design artifact for the next implementation phase; it does not create labor estimates, public pages or derived data.

The labor layer should connect employment conditions with income poverty, extreme income poverty and income distribution using public ENEMDU microdata and the same separation already used in the monitor: source microdata, local analytical outputs, curated site outputs and public Quarto storytelling.

## Analytical question

The future labor layer should answer:

> Why having work does not always mean being out of poverty?

The question is descriptive and associative. It should show how labor-force status, employment quality and informality relate to income poverty and income quintiles. It must not claim that employment status causes poverty or that the monitor creates a new official labor classification.

## Current repository status

The repository already anticipates a labor family in configuration, but no labor output has been implemented yet.

- `config/indicators.yml` defines labor placeholders for unemployment, adequate employment, underemployment and a quarterly five-city labor pulse.
- `config/paths.yml` defines `monthly_labor`, `quarterly_labor` and `annual_labor` output routes.
- `scripts/01_build_monthly_pulse.R` and `scripts/02_build_quarterly_view.R` currently validate domains and output routes only; both explicitly state that real indicator calculation is pending.
- `scripts/03_build_annual_core.R` currently builds income poverty, income-poverty profiles, provincial poverty and deprivation/multidimensional poverty. It does not build `annual_labor`.
- `scripts/04_build_site_metadata.R` currently publishes site outputs for national/area KPIs, income-poverty profiles, territorial province poverty, deprivation/multidimensional KPIs, periods, sources and quality flags. It does not publish a site labor output.
- `data/derived/site/` currently contains no `site_labor_*` file.

## Unit of analysis

Recommended unit: person.

The labor layer should estimate person-level distributions and poverty profiles. Household-level poverty variables may be attached to persons, but the reported unit should remain people unless a future indicator explicitly uses households.

## Universe definitions

The future output should define universes explicitly and avoid mixing denominators.

| Universe | Recommended use | Notes |
|---|---|---|
| Total population | Contextual population shares and poverty profile by broad labor attachment if valid. | Must not be used for rates that require working-age eligibility. |
| Working-age population | Labor-force participation, outside-labor-force share, employed and unemployed distribution. | Requires a real-data age rule aligned with ENEMDU labor concepts. |
| Labor force / PEA | Unemployment and composition of economically active population. | Requires confirmed labor-force status variable and valid categories. |
| Employed population | Employment quality, adequate/full employment, subemployment, unpaid employment, formal/informal employment if definable. | Should not include unemployed or outside-labor-force persons. |
| People with valid income-poverty status | Poverty and extreme poverty by labor condition. | Requires poverty variables or a reusable poverty derivation already produced by the annual pipeline. |
| People with valid income quintile | Quintile profile by labor condition. | Requires a confirmed quintile variable or future annual quintile output. |

## Indicator list

### Core descriptive labor indicators

| Indicator id proposal | Label | Denominator | Required data |
|---|---|---|---|
| `working_age_population_share` | Working-age population share | Total population | Age and working-age rule. |
| `labor_force_participation_rate` | Labor-force participation | Working-age population | Labor-force status / PEA membership. |
| `outside_labor_force_share` | Outside labor force | Working-age population | Labor-force status. |
| `employment_rate_working_age` | Employed among working-age population | Working-age population | Employment status. |
| `unemployment_rate` | Unemployment | Labor force | Labor-force status. |
| `adequate_employment_rate` | Adequate/full employment | Employed population or labor force, depending on ENEMDU reference definition. | Employment quality status. |
| `subemployment_rate` | Subemployment | Employed population or labor force, depending on ENEMDU reference definition. | Employment quality status. |
| `other_non_full_employment_rate` | Other non-full employment | Employed population or labor force, if available. | Employment quality status. |
| `unpaid_employment_rate` | Unpaid employment | Employed population, if available. | Occupational/income category. |
| `informal_employment_rate` | Informal employment | Employed population, if available and definable. | Formality/informality variables. |

### Poverty-by-labor indicators

| Indicator id proposal | Label | Denominator | Output metric |
|---|---|---|---|
| `poverty_rate_by_labor_status` | Income poverty by labor condition | People in each labor condition with valid poverty status | Share below income-poverty line. |
| `extreme_poverty_rate_by_labor_status` | Extreme income poverty by labor condition | People in each labor condition with valid poverty status | Share below extreme income-poverty line. |
| `estimated_poor_by_labor_status` | Estimated people in poverty by labor condition | People in valid labor and poverty universe | Survey-weighted total. |
| `poverty_rate_by_employment_quality` | Income poverty by employment quality | Employed people with valid poverty status | Share below income-poverty line. |
| `poverty_rate_by_formality` | Income poverty by formal/informal employment | Employed people with valid formality and poverty status | Share below income-poverty line. |

### Income-distribution indicators

| Indicator id proposal | Label | Denominator | Output metric |
|---|---|---|---|
| `quintile_distribution_by_labor_status` | Income quintiles by labor condition | People with valid quintile and labor status | Share by quintile. |
| `labor_status_by_quintile` | Labor condition within each quintile | People with valid quintile and labor status | Share by labor condition. |
| `employment_quality_by_quintile` | Employment quality across income quintiles | Employed people with valid quintile and employment quality | Share by employment category. |

## Required variables

These variables or derived equivalents must be confirmed in real annual ENEMDU data before implementation:

| Variable group | Candidate variables | Required for |
|---|---|---|
| Survey design | `fexp`, `upm`, `estrato` | Weighted estimates and precision. |
| Domain | `area`, and optionally province or city variables only when the period/domain contract allows them. | National and urban/rural reporting. |
| Person and household linkage | Person and household identifiers, household id or equivalent. | Attaching household poverty status to persons if needed. |
| Age | Age variable used by ENEMDU / `enemduR`. | Working-age population. |
| Labor-force status | `condact`, `condactn` or `enemduR`-derived equivalent. | Labor force, outside labor force, employed, unemployed. |
| Employment questions | `p20`, `p21`, `p22`, `p32`, `p34`, `p35` and related variables if present. | Employment quality, unpaid employment, formality/informality review. |
| Income poverty status | Poverty and extreme-poverty variables derived by `enemduR` or the annual poverty pipeline. | Poverty by labor condition. |
| Income quintile | Existing or future quintile variable/output. | Quintile by labor condition. |

## Optional variables

Optional variables should be used only after real-data inspection confirms definitions and missing-value behavior:

- sector or branch of activity;
- occupational category;
- social security affiliation;
- establishment size;
- contract status;
- hours worked;
- income from labor;
- unpaid family work category;
- formality/informality indicator if ENEMDU or `enemduR` provides a stable definition.

## Output schema proposal

Two local annual outputs and one curated site output are recommended for the next implementation phase.

### Local analytical output

Proposed path: `data/derived/annual/annual_labor_poverty.rds`.

Recommended columns:

```text
period
survey_type
domain
domain_value
indicator_id
indicator_label
indicator_family
labor_dimension
labor_dimension_label
labor_value
labor_label
estimate
estimate_type
unit
display_estimate
display_unit
weighted_n
unweighted_n
estimated_count
se
cv
df
analysis_unit
universe
source
method_status
benchmark_status
quality_flag
suppression_flag
public_note
source_layer
official_alignment
method_note
```

### Optional local cross-tab output

Proposed path: `data/derived/annual/annual_labor_quintiles.rds`.

Recommended additional columns:

```text
quintile
quintile_label
row_share
column_share
joint_share
```

### Curated site output

Proposed path: `data/derived/site/site_labor_poverty_profiles.rds`.

The site output should:

- include aggregate rows only;
- exclude person identifiers, household identifiers, sampling unit columns, private paths and dynamic timestamps;
- preserve period, survey type, universe and domain metadata;
- keep only fields needed by the public page;
- include enough quality metadata to support visible caution without showing internal variable names on the page.

## Quality and precision contract

The labor output should follow the existing monitor pattern:

- use survey weights and design metadata (`fexp`, `upm`, `estrato`) where available;
- carry standard error, coefficient of variation and degrees of freedom when produced by the estimator;
- define a `quality_flag` from the estimation engine or the repository's agreed representativity rules;
- define a public suppression rule before ranking or highlighting subgroup estimates;
- never rank categories or domains that fail the publication rule;
- include `weighted_n` and `unweighted_n` in technical outputs, but keep public tables focused on interpretation.

The first labor build should avoid province-level labor-poverty reporting unless a separate domain-quality contract is completed.

## Benchmark status

Initial recommended benchmark status:

```text
not_directly_benchmarked_against_public_annual_tabulations
```

Labor indicators may later be compared with public ENEMDU labor bulletins or tabulations, but the exact reference, period, denominator and tolerance must be documented before any close-match language is used.

For poverty-by-labor and quintile-by-labor profiles, no direct benchmark should be assumed. These should be described as analytical profiles based on public ENEMDU microdata.

## Allowed public language

The future page may say:

- labor market and poverty;
- employment conditions;
- income poverty;
- poverty risk;
- household vulnerability;
- working-age population;
- labor force;
- adequate/full employment;
- subemployment;
- unemployment;
- informal employment, only if a valid definition is confirmed;
- income quintiles;
- analytical estimates;
- based on public ENEMDU microdata;
- associated with, linked to, or read together with poverty.

## Forbidden public language

The future page must not:

- describe a labor-poverty ranking as official;
- imply INEC approval of monitor estimates;
- state that INEC has validated the monitor's labor estimates;
- claim a causal employment effect on poverty;
- write that employment produces poverty;
- say the monitor creates an official labor classification;
- imply that work quality categories are newly certified by the monitor.

## Risks

| Risk | Level | Mitigation |
|---|---|---|
| Variable names differ across monthly, quarterly and annual files. | High | Validate real annual variables before coding output. |
| `condact` and `condactn` may encode different concepts or category levels. | High | Build a category dictionary from real data and documentation. |
| Formality/informality may require multiple variables and a precise official definition. | High | Keep formality optional until definition is confirmed. |
| Poverty status is household-derived but reported for people. | Medium | State unit of analysis clearly and attach poverty status only through the established pipeline. |
| Quintiles may not exist yet as a curated annual output. | Medium | Treat quintile cross-tabs as dependent on the annual quintile phase. |
| Small subgroups may be unstable. | Medium | Apply quality and suppression rules before publication. |
| Public readers may infer causality. | Medium | Use association/profile language consistently. |

## Definition of done for output phase 4N

The next output phase is complete when:

- real annual ENEMDU variables are inspected without writing microdata to the repository;
- labor status, employment quality and optional formality variables are mapped and documented;
- poverty status and quintile dependencies are confirmed;
- `annual_labor_poverty.rds` is built as aggregate-only output;
- `site_labor_poverty_profiles.rds` is built for Quarto;
- output schemas contain no private paths, raw identifiers or dynamic timestamps;
- precision and suppression metadata are present;
- benchmark status is explicit;
- public-language constraints are documented;
- no public page is created until the product design phase is accepted.
