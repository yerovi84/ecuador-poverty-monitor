# Ecuador Poverty Monitor

A Quarto-based storytelling data product for understanding poverty in Ecuador beyond a single headline number.

Built by **Alejandro Yerovi** using [`enemduR`](https://github.com/yerovi84/enemduR) as the analytical engine.

---

## Purpose

The **Ecuador Poverty Monitor** is a reproducible, narrative, and visually engaging data product designed to explain how poverty is measured in Ecuador using ENEMDU microdata.

This project is not intended to replace official statistics. It is a downstream analytical and communication product that uses reproducible workflows to organize, explain, visualize, and contextualize poverty indicators.

The central idea is simple:

> Poverty is not a single number.  
> To understand it properly, we need income, structural deprivation, multidimensional poverty, labor conditions, territory, and sampling quality.

---

## Analytical engine

This site uses `enemduR` as its analytical infrastructure.

Recommended stable portfolio release:

```r
remotes::install_github("yerovi84/enemduR@v0.1.0")
```

For active local development of `enemduR`, the package can also be loaded from a local clone:

```r
devtools::load_all("../enemduR", reset = TRUE)
```

---

## Product architecture

The monitor follows a three-speed analytical structure:

| Layer | ENEMDU periodicity | Main use | Territorial scope |
|---|---|---|---|
| Monthly pulse | Monthly | Recent labor and headline context | National and urban/rural |
| Quarterly view | Quarterly | Five-city monitoring | National, urban/rural, and five main cities |
| Annual core | Annual | Full poverty and territorial analysis | National, urban/rural, five main cities, and 24 provinces |

The annual layer is the main narrative foundation of the product.

The monthly and quarterly layers provide recent context without forcing all indicators into inappropriate levels of disaggregation.

---

## Pages

The initial site structure is:

1. `index.qmd`  
   Landing page and product framing.

2. `pages/01_why-monitor.qmd`  
   Why this monitor exists, what ENEMDU is, and why poverty needs context.

Future planned pages:

3. `pages/02_income-poverty.qmd`  
   Income poverty and extreme poverty.

4. `pages/03_quintiles.qmd`  
   Income quintiles and poverty structure.

5. `pages/04_nbi.qmd`  
   Structural poverty through Unsatisfied Basic Needs.

6. `pages/05_tpm.qmd`  
   Multidimensional poverty and extreme multidimensional poverty.

7. `pages/06_territory.qmd`  
   National, urban/rural, provincial, and city-level analysis.

8. `pages/07_labor.qmd`  
   Labor market, unemployment, and poverty.

9. `pages/08_representativity.qmd`  
   Representativity, precision, and limits of inference.

10. `pages/09_sampling-frame.qmd`  
    Technical discussion of the sampling frame and the need for updating.

11. `methodology.qmd`  
    Reproducibility, sources, limitations, and analytical workflow.

---

## Repository structure

```text
ecuador-poverty-monitor/
├─ README.md
├─ _quarto.yml
├─ index.qmd
├─ pages/
│  └─ 01_why-monitor.qmd
├─ config/
│  ├─ periods.yml
│  └─ domains.yml
├─ assets/
│  ├─ css/
│  │  └─ site.css
│  ├─ img/
│  │  └─ brand/
│  └─ infographics/
├─ data/
│  ├─ derived/
│  └─ external/
│     └─ lookup/
├─ scripts/
├─ R/
└─ docs/
```

---

## Data policy

Raw ENEMDU microdata are not stored in this repository.

The repository may store:

- source code;
- Quarto documents;
- configuration files;
- CSS and design assets;
- generated charts or infographics;
- lightweight derived outputs;
- metadata tables;
- reproducibility notes.

The repository must not store:

- raw `.sav`, `.dta`, or `.csv` microdata files from ENEMDU;
- private local paths;
- credentials;
- temporary cache files;
- large untracked artifacts.

---

## Update strategy

The project is designed to be parametrized.

Period configuration is centralized in:

```text
config/periods.yml
```

Domain and representativity rules are centralized in:

```text
config/domains.yml
```

This allows the site to be updated by changing period inputs and rebuilding derived outputs, rather than manually rewriting the narrative structure.

---

## Development status

Current phase:

```text
Phase 3 — Initial Quarto scaffold
```

Current goal:

- create the minimum Quarto site structure;
- define the visual and editorial foundation;
- fix period configuration;
- prepare the repository for the data pipeline phase.

---

## Validation

Recommended local validation:

```bash
quarto render
```

Recommended Git validation:

```bash
git status
git diff --check
git diff
```

If the site renders successfully and the diff contains only expected files, the phase can be committed.

---

## Suggested commit

```bash
git add README.md _quarto.yml index.qmd pages/01_why-monitor.qmd config/periods.yml config/domains.yml assets/css/site.css .gitignore
git commit -m "Create initial Quarto scaffold for Ecuador Poverty Monitor"
```

---

## License

To be defined.

Recommended options:

- MIT License for code;
- CC BY 4.0 for narrative content and graphics;
- explicit attribution for official data sources.
