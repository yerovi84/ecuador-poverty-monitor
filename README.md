# Ecuador Poverty Monitor

A static Quarto portfolio product for reading poverty in Ecuador beyond a single headline number.

Built by **Alejandro Yerovi** using [`enemduR`](https://github.com/yerovi84/enemduR) as the analytical engine.

Public site: <https://yerovi84.github.io/ecuador-poverty-monitor/>

---

## Purpose

The **Ecuador Poverty Monitor** is a reproducible, public-facing product for communicating poverty, deprivation, territory, labor conditions, and statistical quality in Ecuador.

The monitor is designed for policy analytics, data storytelling, applied social statistics, and portfolio review. It helps readers understand what is measured, how estimates should be compared, and where each published result has interpretation limits.

The monitor does not replace official statistics. It is a downstream analytical and communication layer built from public ENEMDU microdata, curated derived outputs, Quarto pages, and an explicit methodological contract.

The central idea is simple:

> Poverty is not a single number. To understand it properly, readers need income, deprivation, territory, labor conditions, and measurement quality.

---

## Current public product

This repository publishes a static Quarto website from the `docs/` directory through GitHub Pages.

Implemented public pages:

| Page | File | Status |
|---|---|---|
| Home | `index.qmd` | Published product framing and reading roadmap |
| Why it matters | `pages/01_why-monitor.qmd` | Published motivation and public reading contract |
| Income poverty | `pages/02_income-poverty.qmd` | Published annual 2025 income-poverty profile |
| Deprivation and multidimensional poverty | `pages/03_deprivation-multidimensional-poverty.qmd` | Published annual 2025 executive profile for income poverty, NBI, extreme NBI, TPM, and TPEM |
| Measurement and statistical quality | `pages/04_methodology-quality.qmd` | Published methodology, benchmark, quality, domain, and communication contract |
| Territorial view of income poverty | `pages/05_territorial-province-income-poverty.qmd` | Published provincial income-poverty map and executive table for annual ENEMDU 2025 |
| Labor market and poverty | `pages/06_labor-market-poverty.qmd` | Published labor attachment, employment quality, and poverty profile for annual ENEMDU 2025 |
| Sampling frame and representativity | `pages/a01_sampling-frame-representativity.qmd` | Published technical annex connected to Measurement and statistical quality |
| Spanish executive layer | `es/index.qmd` | Published executive summary in Spanish |

The sampling-frame annex is a technical annex of the Measurement layer. It is not a sixth analytical layer.

---

## Public architecture

The public site is organized around five analytical layers:

| Layer | Public page | Role |
|---|---|---|
| Income | Income poverty | Reads income poverty and extreme income poverty against public annual benchmark tabulations. |
| Deprivation | Deprivation and multidimensional poverty | Reads NBI, extreme NBI, TPM, and TPEM alongside income poverty. |
| Territory | Territorial view of income poverty | Separates provincial poverty incidence from population concentration. |
| Labor | Labor market and poverty | Reads labor-force attachment, employment quality, and household poverty descriptively. |
| Measurement | Measurement and statistical quality | Documents benchmark status, quality metadata, valid domains, publication language, and interpretation limits. |

The Measurement layer also links to the **Sampling frame and representativity** annex, which explains why household survey frames, coverage, and domains matter for poverty, labor, and territorial interpretation.

---

## Analytical engine

`enemduR` is the analytical engine. The monitor is a separate public narrative product that consumes curated outputs and turns them into a static Quarto site.

Recommended stable portfolio release:

```r
remotes::install_github("yerovi84/enemduR@v0.1.1")
```

For active local development of `enemduR`, the package can also be loaded from a local clone:

```r
devtools::load_all("../enemduR", reset = TRUE)
```

The site-level Quarto pages should consume curated outputs. They should not open raw microdata or recalculate indicators during publication.

---

## Curated site outputs

Current curated site-level outputs:

```text
data/derived/site/site_kpis.rds
data/derived/site/site_income_poverty_profiles.rds
data/derived/site/site_deprivation_multidimensional_kpis.rds
data/derived/site/site_territorial_province_income_poverty.rds
data/derived/site/site_labor_poverty_profiles.rds
data/derived/site/site_periods.rds
data/derived/site/site_sources.rds
data/derived/site/site_quality_flags.rds
```

These files are lightweight publication outputs. They contain only aggregate fields required by the site and metadata needed for interpretation.

Local analytical outputs may exist during development, but they are not versioned unless explicitly curated for site publication.

---

## Data policy

Raw ENEMDU microdata are not versioned in this repository.

The repository may store:

- source code;
- Quarto documents;
- configuration files;
- CSS and design assets;
- static HTML generated by Quarto in `docs/`;
- lightweight, curated derived outputs for site publication;
- metadata and reproducibility notes.

The repository must not store:

- raw ENEMDU `.sav`, `.dta`, `.por`, `.sas7bdat`, `.csv`, or equivalent microdata files;
- private local paths;
- credentials;
- timestamps embedded in versionable analytical outputs;
- temporary cache files;
- large untracked artifacts.

`EPM_RAW_DATA_ROOT` is required only for workflows that resolve private raw microdata locations. It should be set in the local environment and must not be written into versioned outputs or public files.

---

## Product architecture

The monitor follows a three-speed analytical structure:

| Layer | ENEMDU periodicity | Main use | Territorial scope |
|---|---|---|---|
| Monthly pulse | Monthly | Recent labor and headline context | National and urban/rural |
| Quarterly view | Quarterly | Five-city monitoring | National, urban/rural, and five main cities |
| Annual core | Annual | Full poverty and territorial analysis | National, urban/rural, five main cities, and 24 provinces |

The current portfolio release is centered on the annual core. Monthly and quarterly layers provide product architecture for future expansion without forcing every indicator into inappropriate levels of disaggregation.

---

## Repository structure

```text
ecuador-poverty-monitor/
+-- README.md
+-- _quarto.yml
+-- index.qmd
+-- es/
|   +-- index.qmd
+-- pages/
|   +-- 01_why-monitor.qmd
|   +-- 02_income-poverty.qmd
|   +-- 03_deprivation-multidimensional-poverty.qmd
|   +-- 04_methodology-quality.qmd
|   +-- 05_territorial-province-income-poverty.qmd
|   +-- 06_labor-market-poverty.qmd
|   +-- a01_sampling-frame-representativity.qmd
+-- config/
+-- assets/
|   +-- css/
|   +-- img/
+-- data/
|   +-- derived/
|       +-- site/
+-- scripts/
+-- R/
+-- docs/
```

---

## Reproduction

Clone the repository and install the R dependencies used by the project:

```bash
Rscript scripts/00_install_requirements.R
```

Run the setup check:

```bash
Rscript scripts/00_setup.R
```

Render the static site:

```bash
quarto render
```

The rendered site is written to:

```text
docs/
```

Before proposing a commit, run:

```bash
quarto check
quarto render
git diff --check
git status --short
```

Use explicit paths when staging. Do not use `git add .`.

---

## Methodological language

Preferred language:

- based on public ENEMDU microdata;
- survey-weighted analytical estimate;
- compared against public annual INEC tabulations;
- benchmark comparison for analytical reproducibility;
- close benchmark match under the documented tolerance;
- official-source alignment documentation;
- no official institutional validation;
- not directly benchmarked in this build;
- outside tolerance and requiring methodological review;
- descriptive association, profile, contrast, or reading.

Avoid language that implies formal institutional validation, certification, endorsement, approval, official ranking, or causality.

---

## Interpretation limits

The monitor should be read with these limits:

- It is not an official statistical release and does not carry institutional validation.
- Benchmark alignment documents analytical reproducibility only.
- Survey-weighted analytical profiles are not automatically benchmarked against public annual tabulations.
- Territorial and subgroup estimates must be read inside their domain and quality contract.
- Labor-market results are descriptive and should not be presented as causal claims.
- The sampling-frame annex explains survey-design interpretation. It does not audit, certify, or correct official statistics.
- More detailed geography is useful only when the survey design supports that level of reading.

---

## Development guardrails

This repository is a static Quarto site. It is not a Shiny app, a React dashboard, or a heavy interactive product.

Do not:

- commit raw ENEMDU microdata;
- recalculate or publish indicators without an explicit output contract;
- modify curated `.rds` outputs casually;
- expose private paths;
- add dynamic timestamps to versionable outputs;
- invent deprivation, NBI, IPM, TPM, labor, quintile, or territorial results before outputs exist;
- claim official INEC validation;
- claim causality.

---

## Portfolio status

The current release is portfolio-ready once local render, link review, language checks, and GitHub Pages QA are clean.

Public layers currently implemented:

- Income poverty;
- Deprivation and multidimensional poverty;
- Territorial view of income poverty;
- Labor market and poverty;
- Measurement and statistical quality;
- Sampling frame and representativity as a Measurement annex.

---

## License

To be defined.
