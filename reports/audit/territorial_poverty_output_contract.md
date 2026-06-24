# Provincial poverty output contract

## Scope

Phase 4K creates an annual, province-level analytical output for income poverty and extreme income poverty only. It does not create a public Quarto page, maps, shapefiles, NBI, TPM or TPEM provincial outputs.

## Answers to contract questions

1. The current annual pipeline can calculate income poverty by province through `enemduR::enemdu_kpi_income_poverty()` with `group_vars = ".epm_province_code"` and `domain_level = "provincia_24"`.
2. The annual person microdata contain the territorial province variable `prov`.
3. `province_code` is derived from `prov` as a two-character DPA text code, from `01` through `24`.
4. `province_name` is assigned from a fixed 24-province lookup keyed by `province_code`.
5. The provincial calculation keeps the same survey design contract used for national and urban/rural income poverty: `ids = "upm"`, `strata = "estrato"` and `weight = "fexp"`.
6. A local annual output is generated at `data/derived/annual/annual_income_poverty_province.rds`.
7. A curated site output is generated at `data/derived/site/site_territorial_province_income_poverty.rds`.
8. The curated output includes the minimum public contract columns plus precision columns `se`, `cv` and `df`.
9. `quality_flag` uses the integrated representativity flag returned by `enemduR`; `suppression_flag` is `not_suppressed` only when `quality_flag == "design_domain_reliable"` and `review_required` otherwise.
10. Top 5 by estimated persons in poverty can be calculated for `indicator_id == "poverty_rate"` as `estimate * weighted_n`.
11. Ranking by poverty rate is calculated only for non-suppressed poverty-rate rows, so the output does not rank rows requiring review.
12. Provinces below the quality threshold are those with `suppression_flag == "review_required"`.

## Output columns

The curated site output contains:

```text
site_section
display_priority
period
survey_type
domain
domain_value
province_code
province_name
indicator_id
indicator_label
indicator_family
estimate
estimate_type
unit
display_estimate
display_unit
weighted_n
unweighted_n
estimated_poor_count
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
ranking_metric
rank_by_estimated_poor_count
rank_by_poverty_rate
public_note
source_layer
official_alignment
method_note
```

## Ranking contract

The preferred executive metric is `estimated_poor_count`, defined for `poverty_rate` rows as:

```text
estimated_poor_count = estimate * weighted_n
```

This is calculated from unrounded estimates and weighted denominators. It is not reconstructed from rounded display values.

Three views should be compared before any public table:

- top 5 by `estimated_poor_count`;
- top 5 by `estimate` for `poverty_rate`;
- top 5 by `weighted_n`.

For national executive reading, the recommended ranking is top 5 by estimated persons in poverty. For territorial incidence, poverty-rate ranking should be used only where `quality_flag` and `suppression_flag` allow it.

## Quality and suppression

The output uses real precision metadata from `enemduR`: standard error, CV, degrees of freedom, decision and integrated representativity flag. No new arbitrary thresholds are introduced in this repository.

Rules applied:

- `quality_flag = representativity_flag` from `enemduR`;
- `suppression_flag = "not_suppressed"` when `quality_flag == "design_domain_reliable"`;
- `suppression_flag = "review_required"` otherwise;
- `rank_by_estimated_poor_count` and `rank_by_poverty_rate` are populated only for non-suppressed `poverty_rate` rows.

The output remains analytical and subject to precision and representativeness review before publication as rankings.

## Benchmark contract

Provincial rows use:

```text
benchmark_status = "not_directly_benchmarked_against_public_annual_tabulations"
```

No provincial close-match claim is made because no public annual provincial benchmark comparison is implemented in this phase.

## Geometry and public page boundary

The output contains no geometry. The future map should join on `province_code` to the separate cartographic presentation layer documented in the territorial geo audit. Galapagos displacement, Canar geometry review and orphan-join checks remain cartographic publication tasks, not part of this statistical output.

## Preliminary quality result

After running `scripts/03_build_annual_core.R` and `scripts/04_build_site_metadata.R`:

- curated output dimensions: 48 rows and 36 columns;
- poverty-rate rows: 15 `not_suppressed`, 9 `review_required`;
- extreme-poverty-rate rows: 13 `not_suppressed`, 11 `review_required`;
- benchmark status for all rows: `not_directly_benchmarked_against_public_annual_tabulations`.

### Top 5 by estimated persons in poverty

| Rank | Province | Estimated persons in poverty | Poverty rate | Weighted population | Quality |
|---:|---|---:|---:|---:|---|
| 1 | Guayas | 932,505 | 19.959% | 4,672,009 | design_domain_reliable |
| 2 | Manabi | 421,236 | 24.589% | 1,713,126 | design_domain_reliable |
| 3 | Pichincha | 380,909 | 11.283% | 3,375,828 | design_domain_reliable |
| 4 | Esmeraldas | 304,332 | 44.212% | 688,354 | design_domain_reliable |
| 5 | Los Rios | 218,776 | 22.048% | 992,290 | design_domain_reliable |

### Top 5 by poverty rate

| Rank | Province | Poverty rate | Estimated persons in poverty | Weighted population | Quality |
|---:|---|---:|---:|---:|---|
| 1 | Esmeraldas | 44.212% | 304,332 | 688,354 | design_domain_reliable |
| 2 | Pastaza | 36.976% | 44,759 | 121,047 | design_domain_reliable |
| 3 | Santa Elena | 30.411% | 128,328 | 421,980 | design_domain_reliable |
| 4 | Bolivar | 28.200% | 66,930 | 237,344 | design_domain_reliable |
| 5 | Manabi | 24.589% | 421,236 | 1,713,126 | design_domain_reliable |

### Top 5 by weighted population

| Rank | Province | Weighted population | Estimated persons in poverty | Poverty rate | Quality |
|---:|---|---:|---:|---:|---|
| 1 | Guayas | 4,672,009 | 932,505 | 19.959% | design_domain_reliable |
| 2 | Pichincha | 3,375,828 | 380,909 | 11.283% | design_domain_reliable |
| 3 | Manabi | 1,713,126 | 421,236 | 24.589% | design_domain_reliable |
| 4 | Los Rios | 992,290 | 218,776 | 22.048% | design_domain_reliable |
| 5 | Azuay | 912,294 | 118,197 | 12.956% | design_domain_reliable |

### Rows requiring review

For `poverty_rate`, the following provinces have `suppression_flag = "review_required"`: Carchi, Chimborazo, Imbabura, Loja, Morona Santiago, Napo, Zamora Chinchipe, Sucumbios and Orellana.

For `extreme_poverty_rate`, the following provinces have `suppression_flag = "review_required"`: Carchi, Cotopaxi, Chimborazo, Imbabura, Loja, Morona Santiago, Napo, Pastaza, Zamora Chinchipe, Sucumbios and Orellana.
