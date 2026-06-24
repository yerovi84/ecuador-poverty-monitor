source("scripts/00_setup.R")

epm_required_site_outputs <- function(config) {
  site_layout <- config$paths$derived_data_layout$site

  if (is.null(site_layout)) {
    .epm_abort("No `site` derived layer is defined in config/paths.yml; cannot write site metadata.")
  }

  outputs <- site_layout$outputs

  if (!is.list(outputs) || length(outputs) == 0L) {
    .epm_abort("Derived layer `site` must define outputs in config/paths.yml.")
  }

  required <- c(
    "site_kpis",
    "site_income_poverty_profiles",
    "site_territorial_province_income_poverty",
    "site_deprivation_multidimensional_kpis",
    "site_periods",
    "site_sources",
    "site_quality_flags"
  )
  missing <- setdiff(required, names(outputs))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Site metadata requires output contract(s) in config/paths.yml: %s",
      paste(missing, collapse = ", ")
    ))
  }

  required
}

epm_collapse_config_values <- function(x) {
  if (is.null(x)) {
    return(NA_character_)
  }

  if (length(x) == 0L) {
    return(NA_character_)
  }

  paste(as.character(x), collapse = "; ")
}

epm_require_scalar_config_value <- function(value, name) {
  if (!.epm_is_scalar_character(value)) {
    .epm_abort(sprintf("Required configuration value `%s` must be a non-empty string.", name))
  }

  value
}

epm_build_site_periods <- function(config) {
  layers <- epm_get_layers(config$periods)

  data.frame(
    layer = layers,
    enabled = vapply(layers, function(layer) {
      isTRUE(epm_get_layer_config(layer, config$periods)$enabled)
    }, logical(1)),
    label = vapply(layers, function(layer) {
      epm_require_scalar_config_value(
        epm_get_layer_config(layer, config$periods)$label,
        sprintf("periods.layers.%s.label", layer)
      )
    }, character(1)),
    survey_type = vapply(layers, function(layer) {
      epm_layer_survey_type(layer, config$periods)
    }, character(1)),
    configured_period = vapply(layers, function(layer) {
      epm_require_scalar_config_value(
        epm_get_layer_config(layer, config$periods)$period,
        sprintf("periods.layers.%s.period", layer)
      )
    }, character(1)),
    resolved_period = vapply(layers, function(layer) {
      epm_resolve_period(layer, config$periods)
    }, character(1)),
    allowed_domains = vapply(layers, function(layer) {
      epm_collapse_config_values(epm_layer_allowed_domains(layer, config$periods))
    }, character(1)),
    role = vapply(layers, function(layer) {
      epm_require_scalar_config_value(
        epm_get_layer_config(layer, config$periods)$role,
        sprintf("periods.layers.%s.role", layer)
      )
    }, character(1)),
    stringsAsFactors = FALSE
  )
}

epm_build_site_sources <- function(config) {
  config_files <- c("paths.yml", "periods.yml", "domains.yml", "indicators.yml")
  config_paths <- file.path("config", config_files)
  project_name <- epm_require_scalar_config_value(config$paths$project$name, "paths.project.name")
  repository <- epm_require_scalar_config_value(config$paths$project$repository, "paths.project.repository")
  engine_reference <- epm_require_scalar_config_value(
    config$periods$project$analytical_engine_reference,
    "periods.project.analytical_engine_reference"
  )

  data.frame(
    source_type = c("project", "repository", "analytical_engine", rep("configuration", length(config_files))),
    source_name = c(
      "name",
      "repository",
      "analytical_engine_reference",
      config_files
    ),
    source_value = c(
      project_name,
      repository,
      engine_reference,
      config_paths
    ),
    stringsAsFactors = FALSE
  )
}

epm_build_site_quality_flags <- function(config) {
  domains <- epm_valid_domains(config$domains)
  registry <- epm_domain_registry(config$domains)

  data.frame(
    domain = domains,
    label_es = vapply(domains, epm_domain_label, character(1), domains_config = config$domains, lang = "es"),
    label_en = vapply(domains, epm_domain_label, character(1), domains_config = config$domains, lang = "en"),
    variable = vapply(domains, function(domain) {
      value <- registry[[domain]]$variable
      if (is.null(value)) {
        return(NA_character_)
      }
      as.character(value)
    }, character(1)),
    valid_for = vapply(domains, function(domain) {
      epm_collapse_config_values(registry[[domain]]$valid_for)
    }, character(1)),
    configured_values = vapply(domains, function(domain) {
      epm_collapse_config_values(registry[[domain]]$values)
    }, character(1)),
    metadata_note = "Configuration metadata only; no survey microdata read and no indicators calculated.",
    stringsAsFactors = FALSE
  )
}

epm_empty_site_kpis <- function() {
  data.frame(
    site_section = character(),
    display_priority = integer(),
    period = character(),
    survey_type = character(),
    indicator_id = character(),
    indicator_label = character(),
    indicator_family = character(),
    domain = character(),
    domain_value = character(),
    estimate = numeric(),
    estimate_type = character(),
    unit = character(),
    display_estimate = numeric(),
    display_unit = character(),
    benchmark_estimate = numeric(),
    benchmark_difference_pp = numeric(),
    benchmark_status = character(),
    precision_flag = character(),
    method_status = character(),
    official_alignment = character(),
    source_layer = character(),
    stringsAsFactors = FALSE
  )
}

epm_empty_site_income_poverty_profiles <- function() {
  data.frame(
    site_section = character(),
    display_priority = integer(),
    period = character(),
    survey_type = character(),
    indicator_id = character(),
    indicator_label = character(),
    indicator_family = character(),
    domain = character(),
    domain_value = character(),
    profile_dimension = character(),
    profile_dimension_label = character(),
    profile_value = character(),
    profile_label = character(),
    estimate = numeric(),
    estimate_type = character(),
    unit = character(),
    display_estimate = numeric(),
    display_unit = character(),
    se = numeric(),
    cv = numeric(),
    n = integer(),
    df = numeric(),
    weighted_n = numeric(),
    precision_flag = character(),
    universe = character(),
    weight = character(),
    method_status = character(),
    profile_status = character(),
    benchmark_check = character(),
    benchmark_estimate = numeric(),
    benchmark_difference_pp = numeric(),
    benchmark_status = character(),
    official_alignment = character(),
    source_layer = character(),
    source_note = character(),
    method_note = character(),
    source_reference = character(),
    stringsAsFactors = FALSE
  )
}

epm_bind_rows_fill <- function(outputs) {
  outputs <- outputs[vapply(outputs, is.data.frame, logical(1))]
  outputs <- outputs[vapply(outputs, nrow, integer(1)) > 0L]

  if (length(outputs) == 0L) {
    return(data.frame())
  }

  all_cols <- unique(unlist(lapply(outputs, names), use.names = FALSE))
  normalized <- lapply(outputs, function(x) {
    missing <- setdiff(all_cols, names(x))

    for (col in missing) {
      x[[col]] <- NA
    }

    x[all_cols]
  })

  out <- do.call(rbind, normalized)
  row.names(out) <- NULL
  out
}

epm_empty_site_deprivation_multidimensional_kpis <- function() {
  data.frame(
    site_section = character(),
    display_priority = integer(),
    period = character(),
    survey_type = character(),
    domain = character(),
    domain_value = character(),
    indicator_id = character(),
    indicator_label = character(),
    indicator_family = character(),
    estimate = numeric(),
    display_estimate = numeric(),
    display_unit = character(),
    weighted_n = numeric(),
    unweighted_n = integer(),
    analysis_unit = character(),
    universe = character(),
    source = character(),
    method_status = character(),
    benchmark_status = character(),
    benchmark_estimate = numeric(),
    benchmark_difference_pp = numeric(),
    quality_flag = character(),
    public_note = character(),
    source_layer = character(),
    official_alignment = character(),
    method_note = character(),
    stringsAsFactors = FALSE
  )
}

epm_empty_site_territorial_province_income_poverty <- function() {
  data.frame(
    site_section = character(),
    display_priority = integer(),
    period = character(),
    survey_type = character(),
    domain = character(),
    domain_value = character(),
    province_code = character(),
    province_name = character(),
    indicator_id = character(),
    indicator_label = character(),
    indicator_family = character(),
    estimate = numeric(),
    estimate_type = character(),
    unit = character(),
    display_estimate = numeric(),
    display_unit = character(),
    weighted_n = numeric(),
    unweighted_n = integer(),
    estimated_poor_count = numeric(),
    se = numeric(),
    cv = numeric(),
    df = numeric(),
    analysis_unit = character(),
    universe = character(),
    source = character(),
    method_status = character(),
    benchmark_status = character(),
    quality_flag = character(),
    suppression_flag = character(),
    ranking_metric = character(),
    rank_by_estimated_poor_count = integer(),
    rank_by_poverty_rate = integer(),
    public_note = character(),
    source_layer = character(),
    official_alignment = character(),
    method_note = character(),
    stringsAsFactors = FALSE
  )
}

epm_site_province_priority <- function(indicator_id, province_code) {
  indicator_rank <- match(indicator_id, c("poverty_rate", "extreme_poverty_rate"))
  province_rank <- suppressWarnings(as.integer(province_code))

  if (is.na(indicator_rank)) {
    indicator_rank <- 99L
  }

  if (is.na(province_rank)) {
    province_rank <- 99L
  }

  as.integer((indicator_rank - 1L) * 100L + province_rank)
}

epm_site_kpi_priority <- function(indicator_id, domain, domain_value) {
  indicator_rank <- match(indicator_id, c("poverty_rate", "extreme_poverty_rate"))
  domain_rank <- ifelse(
    identical(domain, "national") & identical(domain_value, "national"),
    1L,
    ifelse(identical(domain, "area") & identical(domain_value, "urban"), 2L, 3L)
  )

  if (is.na(indicator_rank)) {
    indicator_rank <- 99L
  }

  as.integer((indicator_rank - 1L) * 10L + domain_rank)
}

epm_build_site_kpis <- function(config) {
  annual_path <- epm_output_path("annual", "annual_income_poverty", config$paths)

  if (!file.exists(annual_path)) {
    message("Annual income poverty output not found; writing empty site_kpis schema.")
    return(epm_empty_site_kpis())
  }

  annual <- epm_read_output(annual_path, required = TRUE)

  if (!is.data.frame(annual)) {
    .epm_abort("Annual income poverty output must be a data frame before building site_kpis.")
  }

  keep <- c(
    "period",
    "survey_type",
    "indicator_id",
    "indicator_label",
    "indicator_family",
    "domain",
    "domain_value",
    "estimate",
    "estimate_type",
    "unit",
    "display_estimate",
    "display_unit",
    "benchmark_estimate",
    "benchmark_difference_pp",
    "benchmark_status",
    "precision_flag",
    "method_status",
    "official_alignment",
    "source_layer"
  )

  missing <- setdiff(keep, names(annual))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty output is missing site KPI column(s): %s",
      paste(missing, collapse = ", ")
    ))
  }

  out <- annual[keep]
  out$site_section <- "home"
  out$display_priority <- mapply(
    epm_site_kpi_priority,
    out$indicator_id,
    out$domain,
    out$domain_value,
    USE.NAMES = FALSE
  )

  out <- out[c("site_section", "display_priority", keep)]
  out <- out[order(out$display_priority, out$indicator_id, out$domain, out$domain_value), , drop = FALSE]
  row.names(out) <- NULL

  forbidden <- epm_detect_forbidden_paths(out, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("site_kpis contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(out),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "site_kpis contains identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  out
}

epm_site_deprivation_priority <- function(indicator_id, domain) {
  indicator_rank <- match(
    indicator_id,
    c(
      "poverty_rate",
      "extreme_poverty_rate",
      "nbi_rate",
      "extreme_nbi_rate",
      "tpm_rate",
      "tpem_rate"
    )
  )
  domain_rank <- match(domain, c("national", "urban", "rural"))

  if (is.na(indicator_rank)) {
    indicator_rank <- 99L
  }

  if (is.na(domain_rank)) {
    domain_rank <- 99L
  }

  as.integer((indicator_rank - 1L) * 10L + domain_rank)
}

epm_site_deprivation_domain <- function(domain, domain_value) {
  value <- as.character(domain_value)
  fallback <- as.character(domain)
  out <- ifelse(!is.na(value) & nzchar(value), value, fallback)
  out[out == "area"] <- fallback[out == "area"]
  out
}

epm_site_output_col <- function(data, col, default) {
  if (col %in% names(data)) {
    return(data[[col]])
  }

  rep(default, nrow(data))
}

epm_prepare_income_for_deprivation_site <- function(annual) {
  if (!is.data.frame(annual) || nrow(annual) == 0L) {
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  annual <- annual[annual$indicator_id %in% c("poverty_rate", "extreme_poverty_rate"), , drop = FALSE]

  if (nrow(annual) == 0L) {
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  domain <- epm_site_deprivation_domain(annual$domain, annual$domain_value)

  data.frame(
    period = as.character(annual$period),
    survey_type = as.character(annual$survey_type),
    domain = domain,
    domain_value = domain,
    indicator_id = as.character(annual$indicator_id),
    indicator_label = as.character(annual$indicator_label),
    indicator_family = as.character(annual$indicator_family),
    estimate = as.numeric(annual$estimate),
    display_estimate = as.numeric(annual$display_estimate),
    display_unit = as.character(annual$display_unit),
    weighted_n = as.numeric(annual$weighted_n),
    unweighted_n = as.integer(annual$n),
    analysis_unit = "people in households",
    universe = as.character(annual$universe),
    source = "Public ENEMDU annual 2025 microdata",
    method_status = as.character(annual$method_status),
    benchmark_status = as.character(annual$benchmark_status),
    benchmark_estimate = as.numeric(annual$benchmark_estimate),
    benchmark_difference_pp = as.numeric(annual$benchmark_difference_pp),
    quality_flag = as.character(annual$precision_flag),
    public_note = "Income poverty estimates are survey-weighted analytical estimates with annual public-tabulation benchmark comparison.",
    source_layer = as.character(annual$source_layer),
    official_alignment = as.character(annual$official_alignment),
    method_note = as.character(annual$method_note),
    stringsAsFactors = FALSE
  )
}

epm_prepare_deprivation_for_site <- function(annual) {
  if (!is.data.frame(annual) || nrow(annual) == 0L) {
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  annual <- annual[
    annual$indicator_id %in% c("nbi_rate", "extreme_nbi_rate", "tpm_rate", "tpem_rate"),
    ,
    drop = FALSE
  ]

  if (nrow(annual) == 0L) {
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  domain <- epm_site_deprivation_domain(annual$domain, annual$domain_value)
  quality_flag <- as.character(epm_site_output_col(annual, "quality_flag", NA_character_))
  missing_quality <- is.na(quality_flag) | !nzchar(quality_flag)
  quality_flag[missing_quality] <- as.character(
    epm_site_output_col(annual, "precision_flag", NA_character_)
  )[missing_quality]

  data.frame(
    period = as.character(annual$period),
    survey_type = as.character(annual$survey_type),
    domain = domain,
    domain_value = domain,
    indicator_id = as.character(annual$indicator_id),
    indicator_label = as.character(annual$indicator_label),
    indicator_family = as.character(annual$indicator_family),
    estimate = as.numeric(annual$estimate),
    display_estimate = as.numeric(annual$display_estimate),
    display_unit = as.character(annual$display_unit),
    weighted_n = as.numeric(annual$weighted_n),
    unweighted_n = as.integer(annual$n),
    analysis_unit = as.character(annual$analysis_unit),
    universe = as.character(annual$universe),
    source = as.character(annual$source),
    method_status = as.character(annual$method_status),
    benchmark_status = as.character(annual$benchmark_status),
    benchmark_estimate = as.numeric(annual$benchmark_estimate),
    benchmark_difference_pp = as.numeric(annual$benchmark_difference_pp),
    quality_flag = quality_flag,
    public_note = as.character(annual$public_note),
    source_layer = as.character(annual$source_layer),
    official_alignment = as.character(annual$official_alignment),
    method_note = as.character(annual$method_note),
    stringsAsFactors = FALSE
  )
}

epm_build_site_deprivation_multidimensional_kpis <- function(config) {
  income_path <- epm_output_path("annual", "annual_income_poverty", config$paths)
  deprivation_path <- epm_output_path(
    "annual",
    "annual_deprivation_multidimensional_poverty",
    config$paths
  )

  if (!file.exists(income_path) && !file.exists(deprivation_path)) {
    message("Annual poverty/deprivation outputs not found; writing empty site_deprivation_multidimensional_kpis schema.")
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  income <- if (file.exists(income_path)) {
    epm_prepare_income_for_deprivation_site(epm_read_output(income_path, required = TRUE))
  } else {
    epm_empty_site_deprivation_multidimensional_kpis()
  }

  deprivation <- if (file.exists(deprivation_path)) {
    epm_prepare_deprivation_for_site(epm_read_output(deprivation_path, required = TRUE))
  } else {
    epm_empty_site_deprivation_multidimensional_kpis()
  }

  out <- epm_bind_rows_fill(list(income, deprivation))

  if (nrow(out) == 0L) {
    return(epm_empty_site_deprivation_multidimensional_kpis())
  }

  out$site_section <- "deprivation_multidimensional_poverty"
  out$display_priority <- mapply(
    epm_site_deprivation_priority,
    out$indicator_id,
    out$domain,
    USE.NAMES = FALSE
  )

  keep <- names(epm_empty_site_deprivation_multidimensional_kpis())
  out <- out[keep]
  out <- out[order(out$display_priority, out$indicator_id, out$domain), , drop = FALSE]
  row.names(out) <- NULL

  required_indicators <- c(
    "poverty_rate",
    "extreme_poverty_rate",
    "nbi_rate",
    "extreme_nbi_rate",
    "tpm_rate",
    "tpem_rate"
  )
  missing_indicators <- setdiff(required_indicators, unique(out$indicator_id))

  if (length(missing_indicators) > 0L) {
    .epm_abort(sprintf(
      "site_deprivation_multidimensional_kpis is missing indicator(s): %s",
      paste(missing_indicators, collapse = ", ")
    ))
  }

  forbidden <- epm_detect_forbidden_paths(out, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("site_deprivation_multidimensional_kpis contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(out),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "site_deprivation_multidimensional_kpis contains identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if ("build_timestamp" %in% names(out)) {
    .epm_abort("site_deprivation_multidimensional_kpis must not expose build_timestamp.")
  }

  out
}

epm_build_site_territorial_province_income_poverty <- function(config) {
  annual_path <- epm_output_path("annual", "annual_income_poverty_province", config$paths)

  if (!file.exists(annual_path)) {
    message("Annual provincial income poverty output not found; writing empty site_territorial_province_income_poverty schema.")
    return(epm_empty_site_territorial_province_income_poverty())
  }

  annual <- epm_read_output(annual_path, required = TRUE)

  if (!is.data.frame(annual)) {
    .epm_abort("Annual provincial income poverty output must be a data frame before building the site output.")
  }

  keep <- c(
    "period",
    "survey_type",
    "domain",
    "domain_value",
    "province_code",
    "province_name",
    "indicator_id",
    "indicator_label",
    "indicator_family",
    "estimate",
    "estimate_type",
    "unit",
    "display_estimate",
    "display_unit",
    "weighted_n",
    "unweighted_n",
    "estimated_poor_count",
    "se",
    "cv",
    "df",
    "analysis_unit",
    "universe",
    "source",
    "method_status",
    "benchmark_status",
    "quality_flag",
    "suppression_flag",
    "ranking_metric",
    "rank_by_estimated_poor_count",
    "rank_by_poverty_rate",
    "public_note",
    "source_layer",
    "official_alignment",
    "method_note"
  )

  missing <- setdiff(keep, names(annual))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Annual provincial income poverty output is missing site column(s): %s",
      paste(missing, collapse = ", ")
    ))
  }

  out <- annual[keep]
  out$site_section <- "territorial_province_income_poverty"
  out$display_priority <- mapply(
    epm_site_province_priority,
    out$indicator_id,
    out$province_code,
    USE.NAMES = FALSE
  )

  out <- out[names(epm_empty_site_territorial_province_income_poverty())]
  out <- out[order(out$display_priority, out$indicator_id, out$province_code), , drop = FALSE]
  row.names(out) <- NULL

  if (!identical(unique(out$domain), "province")) {
    .epm_abort("site_territorial_province_income_poverty `domain` must be `province`.")
  }

  forbidden <- epm_detect_forbidden_paths(out, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("site_territorial_province_income_poverty contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(out),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar", "upm", "estrato", "fexp")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "site_territorial_province_income_poverty contains identifier or design column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if ("build_timestamp" %in% names(out)) {
    .epm_abort("site_territorial_province_income_poverty must not expose build_timestamp.")
  }

  out
}

epm_site_profile_priority <- function(indicator_id, profile_dimension, profile_value) {
  dimension_rank <- match(profile_dimension, c("sex", "age_group", "education_level_adult"))
  indicator_rank <- match(indicator_id, c("poverty_rate", "extreme_poverty_rate"))

  value_order <- list(
    sex = c("female", "male"),
    age_group = c("age_0_14", "age_15_24", "age_25_44", "age_45_64", "age_65_plus"),
    education_level_adult = c(
      "no_formal_or_literacy",
      "primary_or_basic",
      "secondary_or_bachillerato",
      "higher"
    )
  )

  value_rank <- match(profile_value, value_order[[profile_dimension]])

  if (is.na(dimension_rank)) {
    dimension_rank <- 99L
  }

  if (is.na(indicator_rank)) {
    indicator_rank <- 99L
  }

  if (is.na(value_rank)) {
    value_rank <- 99L
  }

  as.integer((dimension_rank - 1L) * 100L + (indicator_rank - 1L) * 20L + value_rank)
}

epm_build_site_income_poverty_profiles <- function(config) {
  annual_path <- epm_output_path("annual", "annual_income_poverty_profiles", config$paths)

  if (!file.exists(annual_path)) {
    message("Annual income poverty profile output not found; writing empty site_income_poverty_profiles schema.")
    return(epm_empty_site_income_poverty_profiles())
  }

  annual <- epm_read_output(annual_path, required = TRUE)

  if (!is.data.frame(annual)) {
    .epm_abort("Annual income poverty profile output must be a data frame before building site profiles.")
  }

  keep <- c(
    "period",
    "survey_type",
    "indicator_id",
    "indicator_label",
    "indicator_family",
    "domain",
    "domain_value",
    "profile_dimension",
    "profile_dimension_label",
    "profile_value",
    "profile_label",
    "estimate",
    "estimate_type",
    "unit",
    "display_estimate",
    "display_unit",
    "se",
    "cv",
    "n",
    "df",
    "weighted_n",
    "precision_flag",
    "universe",
    "weight",
    "method_status",
    "profile_status",
    "benchmark_check",
    "benchmark_estimate",
    "benchmark_difference_pp",
    "benchmark_status",
    "official_alignment",
    "source_layer",
    "source_note",
    "method_note",
    "source_reference"
  )

  missing <- setdiff(keep, names(annual))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty profile output is missing site profile column(s): %s",
      paste(missing, collapse = ", ")
    ))
  }

  out <- annual[keep]
  out$site_section <- "income_poverty_profiles"
  out$display_priority <- mapply(
    epm_site_profile_priority,
    out$indicator_id,
    out$profile_dimension,
    out$profile_value,
    USE.NAMES = FALSE
  )

  out <- out[c("site_section", "display_priority", keep)]
  out <- out[order(out$display_priority, out$indicator_id, out$profile_dimension, out$profile_value), , drop = FALSE]
  row.names(out) <- NULL

  forbidden <- epm_detect_forbidden_paths(out, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("site_income_poverty_profiles contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(out),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "site_income_poverty_profiles contains identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if ("build_timestamp" %in% names(out) && any(!is.na(out$build_timestamp))) {
    .epm_abort("site_income_poverty_profiles must not contain dynamic build timestamps.")
  }

  out
}

epm_save_site_metadata <- function(output_name, data, config) {
  path <- epm_output_path("site", output_name, config$paths)
  epm_make_dir(dirname(path))

  dynamic_outputs <- c(
    "site_kpis",
    "site_income_poverty_profiles",
    "site_territorial_province_income_poverty",
    "site_deprivation_multidimensional_kpis"
  )

  if (!output_name %in% dynamic_outputs && file.exists(path)) {
    return(normalizePath(path, winslash = "/", mustWork = TRUE))
  }

  if (file.exists(path)) {
    existing <- readRDS(path)

    if (identical(existing, data)) {
      return(normalizePath(path, winslash = "/", mustWork = TRUE))
    }
  }

  saveRDS(data, path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

required_outputs <- epm_required_site_outputs(config)
invisible(epm_make_dir(epm_layer_derived_dir("site", config$paths)))

metadata <- list(
  site_kpis = epm_build_site_kpis(config),
  site_income_poverty_profiles = epm_build_site_income_poverty_profiles(config),
  site_territorial_province_income_poverty = epm_build_site_territorial_province_income_poverty(config),
  site_deprivation_multidimensional_kpis = epm_build_site_deprivation_multidimensional_kpis(config),
  site_periods = epm_build_site_periods(config),
  site_sources = epm_build_site_sources(config),
  site_quality_flags = epm_build_site_quality_flags(config)
)

written_paths <- vapply(required_outputs, function(output_name) {
  epm_save_site_metadata(output_name, metadata[[output_name]], config)
}, character(1))

message("Site metadata builder complete.")
message("Operational assumption: site KPI metadata is curated from aggregated annual outputs only.")
message("Available site metadata outputs:")
for (output_name in names(written_paths)) {
  message(sprintf("- %s: %s", output_name, written_paths[[output_name]]))
}
message("No microdata were read and no analytical indicators were recalculated.")
