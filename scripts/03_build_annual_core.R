source("scripts/00_setup.R")

epm_require_enemduR <- function() {
  if (!requireNamespace("enemduR", quietly = TRUE)) {
    .epm_abort("Package `enemduR` is required before building annual income poverty outputs.")
  }

  version <- as.character(utils::packageVersion("enemduR"))

  if (!identical(version, "0.1.1")) {
    .epm_abort(sprintf("Expected enemduR version 0.1.1; found %s.", version))
  }

  invisible(version)
}

epm_extract_annual_period_from_inputs <- function(input_basenames) {
  years <- regmatches(input_basenames, regexpr("20[0-9]{2}", input_basenames))
  years <- unique(years[nzchar(years)])

  if (length(years) != 1L) {
    .epm_abort("Annual input basenames must contain one shared four-digit year.")
  }

  years[[1]]
}

epm_get_annual_poverty_line_reference <- function(annual_period) {
  list(
    period = annual_period,
    poverty_line = 92.40,
    extreme_poverty_line = 52.07,
    line_source = paste(
      "Explicit income poverty line values used by the annual 2025 analytical build contract;",
      "official-source alignment documentation only, no official institutional validation."
    ),
    source_reference = "ENEMDU annual 2025 analytical poverty build contract"
  )
}

epm_normalize_text <- function(x) {
  x <- enc2utf8(as.character(x))
  x <- iconv(x, from = "", to = "ASCII//TRANSLIT", sub = "")
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(x)
}

epm_first_existing_col <- function(data, candidates) {
  normalized_names <- epm_normalize_text(names(data))
  normalized_candidates <- epm_normalize_text(candidates)
  matched <- which(normalized_names %in% normalized_candidates)

  if (length(matched) > 0L) {
    return(names(data)[[matched[[1]]]])
  }

  NA_character_
}

epm_parse_percent_value <- function(x) {
  raw <- trimws(as.character(x))
  has_percent <- grepl("%", raw, fixed = TRUE)
  raw <- gsub("%", "", raw, fixed = TRUE)
  raw <- gsub("[[:space:]]+", "", raw)
  raw <- gsub("\\.", "", raw)
  raw <- gsub(",", ".", raw, fixed = TRUE)
  value <- suppressWarnings(as.numeric(raw))

  if (!has_percent && !is.na(value) && value <= 1) {
    value <- value * 100
  }

  value
}

epm_read_delimited_from_zip <- function(zip_path, member) {
  members <- utils::unzip(zip_path, list = TRUE)
  member_names <- as.character(members$Name)
  matched_member <- member_names[member_names == member]

  if (length(matched_member) == 0L) {
    matched_member <- member_names[
      basename(member_names) == basename(member) &
        grepl("Pobreza_Desigualdad", member_names, fixed = TRUE)
    ]
  }

  if (length(matched_member) != 1L) {
    .epm_abort("Could not uniquely locate the annual poverty benchmark CSV inside the zip.")
  }

  extraction_dir <- tempfile("epm_annual_benchmark_")
  dir.create(extraction_dir, recursive = TRUE, showWarnings = FALSE)

  extracted <- utils::unzip(
    zipfile = zip_path,
    files = matched_member[[1]],
    exdir = extraction_dir,
    junkpaths = FALSE,
    overwrite = TRUE
  )

  if (length(extracted) != 1L || !file.exists(extracted[[1]])) {
    .epm_abort("Could not extract the annual poverty benchmark CSV from the zip.")
  }

  data <- utils::read.csv(
    file = extracted[[1]],
    sep = ";",
    header = FALSE,
    fileEncoding = "Latin1",
    stringsAsFactors = FALSE,
    check.names = FALSE,
    fill = TRUE,
    colClasses = "character"
  )

  if (!is.data.frame(data) || nrow(data) == 0L) {
    .epm_abort("Annual poverty benchmark CSV is empty.")
  }

  attr(data, "zip_member") <- matched_member[[1]]
  data
}

epm_find_domain_column <- function(data, domain_label, secondary_label = NULL) {
  normalized_names <- epm_normalize_text(names(data))
  normalized_domain <- epm_normalize_text(domain_label)
  normalized_secondary <- epm_normalize_text(secondary_label)

  if (.epm_is_scalar_character(normalized_secondary)) {
    matched <- which(
      grepl(normalized_domain, normalized_names, fixed = TRUE) &
        grepl(normalized_secondary, normalized_names, fixed = TRUE)
    )

    if (length(matched) > 0L) {
      return(names(data)[[matched[[1]]]])
    }
  }

  matched <- which(normalized_names == normalized_domain)

  if (length(matched) > 0L) {
    return(names(data)[[matched[[1]]]])
  }

  matched <- which(grepl(normalized_domain, normalized_names, fixed = TRUE))

  if (length(matched) > 0L) {
    return(names(data)[[matched[[1]]]])
  }

  NA_character_
}

epm_fill_header_groups <- function(values) {
  out <- trimws(as.character(values))
  current <- ""

  for (i in seq_along(out)) {
    if (nzchar(out[[i]])) {
      current <- out[[i]]
    } else {
      out[[i]] <- current
    }
  }

  out
}

epm_find_two_level_column <- function(header_map, primary, secondary) {
  primary_norm <- epm_normalize_text(primary)
  secondary_norm <- epm_normalize_text(secondary)

  matched <- which(
    header_map$primary_norm == primary_norm &
      header_map$secondary_norm == secondary_norm
  )

  if (length(matched) != 1L) {
    .epm_abort(sprintf(
      "Could not uniquely map annual benchmark column `%s / %s`.",
      primary,
      secondary
    ))
  }

  header_map$name[[matched[[1]]]]
}

epm_tabulation_has_header_tokens <- function(row) {
  text <- epm_normalize_text(unlist(row, use.names = FALSE))
  all(c("periodo", "indicador", "estimador") %in% text)
}

epm_compact_header_value <- function(primary, secondary) {
  primary <- trimws(as.character(primary))
  secondary <- trimws(as.character(secondary))

  if (!nzchar(primary)) {
    return(secondary)
  }

  if (!nzchar(secondary) || identical(epm_normalize_text(primary), epm_normalize_text(secondary))) {
    return(primary)
  }

  paste(primary, secondary, sep = "__")
}

epm_promote_annual_tabulation_header <- function(raw) {
  header_rows <- which(vapply(
    seq_len(nrow(raw)),
    function(i) epm_tabulation_has_header_tokens(raw[i, , drop = FALSE]),
    logical(1)
  ))

  if (length(header_rows) < 1L) {
    .epm_abort("Could not identify the annual benchmark header row.")
  }

  header_row <- header_rows[[1]]
  secondary_row <- header_row + 1L
  primary <- as.character(unlist(raw[header_row, , drop = TRUE], use.names = FALSE))
  secondary <- if (secondary_row <= nrow(raw)) {
    as.character(unlist(raw[secondary_row, , drop = TRUE], use.names = FALSE))
  } else {
    rep("", length(primary))
  }

  primary_grouped <- epm_fill_header_groups(primary)
  secondary_tokens <- epm_normalize_text(secondary)
  has_secondary_header <- any(secondary_tokens %in% c("total", "urbano", "rural"))

  names_out <- if (has_secondary_header) {
    mapply(epm_compact_header_value, primary_grouped, secondary, USE.NAMES = FALSE)
  } else {
    primary
  }

  names_out[!nzchar(trimws(names_out))] <- paste0("col_", which(!nzchar(trimws(names_out))))
  names_out <- make.unique(names_out, sep = "__")

  start_row <- header_row + if (has_secondary_header) 2L else 1L
  out <- raw[start_row:nrow(raw), , drop = FALSE]
  names(out) <- names_out
  attr(out, "header_map") <- data.frame(
    name = names_out,
    primary = primary_grouped,
    secondary = secondary,
    primary_norm = epm_normalize_text(primary_grouped),
    secondary_norm = epm_normalize_text(secondary),
    stringsAsFactors = FALSE
  )
  row.names(out) <- NULL
  out
}

epm_row_contains <- function(row, pattern) {
  text <- paste(epm_normalize_text(unlist(row, use.names = FALSE)), collapse = " ")
  grepl(pattern, text, fixed = TRUE)
}

epm_extract_annual_poverty_benchmarks <- function(zip_path, member, zip_basename) {
  raw_csv <- epm_read_delimited_from_zip(zip_path, member)
  zip_member <- attr(raw_csv, "zip_member")
  raw <- epm_promote_annual_tabulation_header(raw_csv)
  period_col <- epm_first_existing_col(raw, c("Periodo"))
  indicator_col <- epm_first_existing_col(raw, c("Indicador"))
  estimator_col <- epm_first_existing_col(raw, c("Estimador"))

  if (!.epm_is_scalar_character(period_col) ||
      !.epm_is_scalar_character(indicator_col) ||
      !.epm_is_scalar_character(estimator_col)) {
    .epm_abort("Annual benchmark table must contain `Periodo`, `Indicador`, and `Estimador` columns.")
  }

  domain_cols <- c(
    national = epm_find_two_level_column(attr(raw, "header_map"), "Nacional", "Total"),
    urban = epm_find_two_level_column(attr(raw, "header_map"), "Area", "Urbano"),
    rural = epm_find_two_level_column(attr(raw, "header_map"), "Area", "Rural")
  )

  if (any(!vapply(domain_cols, .epm_is_scalar_character, logical(1)))) {
    .epm_abort("Annual benchmark table must contain Nacional/Total, Area/Urbano, and Area/Rural columns.")
  }

  period_rows <- trimws(as.character(raw[[period_col]])) == "2025"
  estimator_rows <- epm_normalize_text(raw[[estimator_col]]) == "indicador"
  indicator_values <- epm_normalize_text(raw[[indicator_col]])
  poverty_rows <- which(
    period_rows &
      estimator_rows &
      indicator_values == "pobreza por ingresos"
  )
  extreme_rows <- which(
    period_rows &
      estimator_rows &
      indicator_values == "pobreza extrema por ingresos"
  )

  if (length(poverty_rows) != 1L || length(extreme_rows) != 1L) {
    .epm_abort("Could not uniquely identify annual poverty and extreme-poverty indicator rows.")
  }

  rows <- list(
    poverty_rate = poverty_rows[[1]],
    extreme_poverty_rate = extreme_rows[[1]]
  )

  pieces <- list()
  i <- 1L

  for (indicator_id in names(rows)) {
    row_id <- rows[[indicator_id]]

    for (domain_value in names(domain_cols)) {
      domain <- if (identical(domain_value, "national")) "national" else "area"
      pieces[[i]] <- data.frame(
        indicator_id = indicator_id,
        domain = domain,
        domain_value = domain_value,
        benchmark_estimate = epm_parse_percent_value(raw[[domain_cols[[domain_value]]]][[row_id]]),
        benchmark_unit = "percent",
        benchmark_reference = "ENEMDU annual 2025 public poverty and inequality tabulation",
        benchmark_source_file = paste(zip_basename, basename(zip_member), sep = "::"),
        stringsAsFactors = FALSE
      )
      i <- i + 1L
    }
  }

  out <- do.call(rbind, pieces)
  row.names(out) <- NULL
  out
}

epm_load_annual_benchmark_reference <- function(paths_config) {
  benchmark_file <- epm_resolve_annual_benchmark_file(paths_config, required = FALSE)
  member <- epm_expected_input_member("annual", "official_tables", paths_config)

  if (!isTRUE(benchmark_file$exists)) {
    return(list(
      available = FALSE,
      basename = benchmark_file$basename,
      benchmarks = data.frame(),
      status = "annual_reference_missing"
    ))
  }

  if (!.epm_is_scalar_character(member)) {
    .epm_abort("Annual official_tables contract must define the CSV member inside the zip.")
  }

  benchmarks <- epm_extract_annual_poverty_benchmarks(
    zip_path = benchmark_file$path,
    member = member,
    zip_basename = benchmark_file$basename
  )

  list(
    available = TRUE,
    basename = benchmark_file$basename,
    benchmarks = benchmarks,
    status = "annual_reference_loaded"
  )
}

epm_area_domain <- function(values) {
  values_chr <- tolower(trimws(as.character(values)))
  out <- rep(NA_character_, length(values_chr))

  out[values_chr %in% c("1", "urban", "urbano", "area urbana")] <- "urban"
  out[values_chr %in% c("2", "rural", "area rural")] <- "rural"

  out
}

epm_build_income_poverty_estimates <- function(data, reference) {
  data[[".epm_area_domain"]] <- epm_area_domain(data[["area"]])

  if (all(is.na(data[[".epm_area_domain"]]))) {
    .epm_abort("Could not map annual `area` values to urban/rural domains.")
  }

  national <- enemduR::enemdu_kpi_income_poverty(
    data = data,
    period = reference$period,
    mode = "manual",
    poverty_line = reference$poverty_line,
    extreme_poverty_line = reference$extreme_poverty_line,
    line_source = reference$line_source,
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    official_validation_status = "not_officially_validated",
    official_validation_note = "Analytical output; official-source alignment documentation only, no official institutional validation."
  )
  national[["domain"]] <- "national"
  national[["domain_value"]] <- "national"

  area <- enemduR::enemdu_kpi_income_poverty(
    data = data,
    group_vars = ".epm_area_domain",
    period = reference$period,
    mode = "manual",
    poverty_line = reference$poverty_line,
    extreme_poverty_line = reference$extreme_poverty_line,
    line_source = reference$line_source,
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    domain_level = "urbano_rural",
    domain_var = "area",
    official_validation_status = "not_officially_validated",
    official_validation_note = "Analytical output; official-source alignment documentation only, no official institutional validation."
  )
  area[["domain"]] <- "area"
  area[["domain_value"]] <- area[[".epm_area_domain"]]

  out <- rbind(
    national,
    area[setdiff(names(area), ".epm_area_domain")]
  )
  row.names(out) <- NULL
  out
}

epm_compare_income_poverty_benchmarks <- function(estimates, reference) {
  if (!isTRUE(reference$available) || !is.data.frame(reference$benchmarks) || nrow(reference$benchmarks) == 0L) {
    return(data.frame(
      indicator_id = character(),
      domain = character(),
      domain_value = character(),
      benchmark_estimate = numeric(),
      benchmark_unit = character(),
      benchmark_difference_pp = numeric(),
      benchmark_reference = character(),
      benchmark_source_file = character(),
      benchmark_status = character(),
      stringsAsFactors = FALSE
    ))
  }

  id_map <- c(
    pobreza_ingresos = "poverty_rate",
    pobreza_extrema_ingresos = "extreme_poverty_rate"
  )

  estimate_work <- data.frame(
    indicator_id = unname(id_map[as.character(estimates$indicator_id)]),
    domain = as.character(estimates$domain),
    domain_value = as.character(estimates$domain_value),
    display_estimate = as.numeric(estimates$estimate) * 100,
    stringsAsFactors = FALSE
  )
  estimate_work <- estimate_work[!is.na(estimate_work$indicator_id), , drop = FALSE]

  comparison <- merge(
    reference$benchmarks,
    estimate_work,
    by = c("indicator_id", "domain", "domain_value"),
    all.x = TRUE,
    sort = FALSE
  )

  comparison$benchmark_difference_pp <- comparison$display_estimate - comparison$benchmark_estimate
  tolerance_pp <- 0.5
  comparison$benchmark_status <- ifelse(
    is.na(comparison$display_estimate) | is.na(comparison$benchmark_estimate),
    "annual_reference_missing_estimate",
    ifelse(
      abs(comparison$benchmark_difference_pp) <= tolerance_pp,
      "annual_published_table_close_match",
      "annual_published_table_difference_requires_review"
    )
  )

  comparison
}

epm_compare_monitor_output_benchmarks <- function(output, reference) {
  if (!isTRUE(reference$available) || !is.data.frame(reference$benchmarks) || nrow(reference$benchmarks) == 0L) {
    return(data.frame(
      indicator_id = character(),
      domain = character(),
      domain_value = character(),
      benchmark_estimate = numeric(),
      benchmark_unit = character(),
      benchmark_difference_pp = numeric(),
      benchmark_reference = character(),
      benchmark_source_file = character(),
      benchmark_status = character(),
      stringsAsFactors = FALSE
    ))
  }

  display_estimate <- if ("display_estimate" %in% names(output)) {
    as.numeric(output$display_estimate)
  } else {
    as.numeric(output$estimate) * 100
  }

  estimate_work <- data.frame(
    indicator_id = as.character(output$indicator_id),
    domain = as.character(output$domain),
    domain_value = as.character(output$domain_value),
    display_estimate = display_estimate,
    stringsAsFactors = FALSE
  )

  comparison <- merge(
    reference$benchmarks,
    estimate_work,
    by = c("indicator_id", "domain", "domain_value"),
    all.x = TRUE,
    sort = FALSE
  )

  comparison$benchmark_difference_pp <- comparison$display_estimate - comparison$benchmark_estimate
  tolerance_pp <- 0.5
  comparison$benchmark_status <- ifelse(
    is.na(comparison$display_estimate) | is.na(comparison$benchmark_estimate),
    "annual_reference_missing_estimate",
    ifelse(
      abs(comparison$benchmark_difference_pp) <= tolerance_pp,
      "annual_published_table_close_match",
      "annual_published_table_difference_requires_review"
    )
  )

  comparison
}

epm_refresh_monitor_income_poverty_output <- function(output, comparisons, reference) {
  if (!is.data.frame(output)) {
    .epm_abort("Existing annual income poverty output must be a data frame.")
  }

  output$estimate <- as.numeric(output$estimate)
  output$estimate_type <- "proportion"
  output$unit <- "proportion"
  output$display_estimate <- output$estimate * 100
  output$display_unit <- "percent"

  output$benchmark_estimate <- NA_real_
  output$benchmark_unit <- "percent"
  output$benchmark_difference_pp <- NA_real_
  output$benchmark_reference <- NA_character_
  output$benchmark_source_file <- NA_character_
  output$benchmark_status <- "annual_reference_missing"

  output$source_note <- reference$line_source
  output$source_reference <- reference$source_reference
  output$method_note <- paste(
    "Survey-design-aware income poverty estimate from ENEMDU microdata via enemduR v0.1.1.",
    "Poverty and extreme poverty use explicit auditable line values.",
    "Benchmark comparison uses the annual 2025 public tabulation when available.",
    "This is not INEC validation, certification, approval, or endorsement."
  )

  if (is.data.frame(comparisons) && nrow(comparisons) > 0L) {
    key <- paste(output$indicator_id, output$domain, output$domain_value, sep = "\r")
    comparison_key <- paste(
      comparisons$indicator_id,
      comparisons$domain,
      comparisons$domain_value,
      sep = "\r"
    )
    matched <- match(key, comparison_key)
    has_match <- !is.na(matched)
    output$benchmark_estimate[has_match] <- comparisons$benchmark_estimate[matched[has_match]]
    output$benchmark_unit[has_match] <- comparisons$benchmark_unit[matched[has_match]]
    output$benchmark_difference_pp[has_match] <- comparisons$benchmark_difference_pp[matched[has_match]]
    output$benchmark_reference[has_match] <- comparisons$benchmark_reference[matched[has_match]]
    output$benchmark_source_file[has_match] <- comparisons$benchmark_source_file[matched[has_match]]
    output$benchmark_status[has_match] <- comparisons$benchmark_status[matched[has_match]]
  }

  output
}

epm_to_monitor_income_poverty_output <- function(estimates,
                                                 comparisons,
                                                 annual_period,
                                                 reference,
                                                 source_file) {
  id_map <- c(
    pobreza_ingresos = "poverty_rate",
    pobreza_extrema_ingresos = "extreme_poverty_rate"
  )

  label_map <- c(
    poverty_rate = "Income poverty",
    extreme_poverty_rate = "Extreme income poverty"
  )

  estimates[["monitor_indicator_id"]] <- unname(id_map[as.character(estimates$indicator_id)])

  estimates <- estimates[
    !is.na(estimates$monitor_indicator_id) &
      estimates$domain %in% c("national", "area"),
    ,
    drop = FALSE
  ]

  out <- data.frame(
    indicator_id = estimates$monitor_indicator_id,
    indicator_label = unname(label_map[estimates$monitor_indicator_id]),
    indicator_family = "income_poverty",
    period = annual_period,
    survey_type = "anual",
    domain = as.character(estimates$domain),
    domain_value = as.character(estimates$domain_value),
    estimate = as.numeric(estimates$estimate),
    estimate_type = "proportion",
    unit = "proportion",
    display_estimate = as.numeric(estimates$estimate) * 100,
    display_unit = "percent",
    source_layer = "annual",
    build_timestamp = NA_character_,
    se = as.numeric(estimates$standard_error),
    cv = as.numeric(estimates$cv),
    n = as.integer(estimates$unweighted_n),
    df = as.numeric(estimates$degrees_freedom),
    weighted_n = as.numeric(estimates$weighted_n),
    precision_flag = as.character(estimates$representativity_flag),
    universe = as.character(estimates$universe),
    weight = as.character(estimates$estimation_weight),
    method_status = as.character(estimates$decision),
    official_alignment = "official-source alignment documentation; no official institutional validation",
    benchmark_estimate = NA_real_,
    benchmark_unit = "percent",
    benchmark_difference_pp = NA_real_,
    benchmark_reference = NA_character_,
    benchmark_source_file = NA_character_,
    benchmark_status = "annual_reference_missing",
    source_note = as.character(estimates$poverty_line_source_note),
    method_note = paste(
      "Survey-design-aware income poverty estimate from ENEMDU microdata via enemduR v0.1.1.",
      "Poverty and extreme poverty use explicit auditable line values.",
      "This is not INEC validation, certification, approval, or endorsement."
    ),
    source_file = source_file,
    source_reference = reference$source_reference,
    stringsAsFactors = FALSE
  )

  if (is.data.frame(comparisons) && nrow(comparisons) > 0L) {
    key <- paste(out$indicator_id, out$domain, out$domain_value, sep = "\r")
    comparison_key <- paste(
      comparisons$indicator_id,
      comparisons$domain,
      comparisons$domain_value,
      sep = "\r"
    )
    matched <- match(key, comparison_key)
    has_match <- !is.na(matched)
    out$benchmark_estimate[has_match] <- comparisons$benchmark_estimate[matched[has_match]]
    out$benchmark_unit[has_match] <- comparisons$benchmark_unit[matched[has_match]]
    out$benchmark_difference_pp[has_match] <- comparisons$benchmark_difference_pp[matched[has_match]]
    out$benchmark_reference[has_match] <- comparisons$benchmark_reference[matched[has_match]]
    out$benchmark_source_file[has_match] <- comparisons$benchmark_source_file[matched[has_match]]
    out$benchmark_status[has_match] <- comparisons$benchmark_status[matched[has_match]]
  }

  out[order(out$indicator_id, out$domain, out$domain_value), , drop = FALSE]
}

epm_validate_annual_income_poverty_output <- function(output) {
  epm_validate_output_schema(output, config$indicators, strict = FALSE)

  required_indicators <- c("poverty_rate", "extreme_poverty_rate")
  missing_indicators <- setdiff(required_indicators, unique(output$indicator_id))

  if (length(missing_indicators) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty output is missing indicator(s): %s",
      paste(missing_indicators, collapse = ", ")
    ))
  }

  required_domains <- c("national", "area")
  missing_domains <- setdiff(required_domains, unique(output$domain))

  if (length(missing_domains) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty output is missing domain(s): %s",
      paste(missing_domains, collapse = ", ")
    ))
  }

  forbidden <- epm_detect_forbidden_paths(output, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("Annual income poverty output contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(output),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty output contains microdata identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if (!identical(unique(output$unit), "proportion")) {
    .epm_abort("Annual income poverty output `unit` must be `proportion`.")
  }

  if (!identical(unique(output$display_unit), "percent")) {
    .epm_abort("Annual income poverty output `display_unit` must be `percent`.")
  }

  invisible(TRUE)
}

epm_require_enemduR()

output_path <- epm_output_path("annual", "annual_income_poverty", config$paths)
annual_inputs <- epm_resolve_annual_input_files(config$paths, required = FALSE)
annual_inputs_ready <- all(vapply(annual_inputs, function(input) isTRUE(input$exists), logical(1)))

if (isTRUE(annual_inputs_ready)) {
  annual_basenames <- epm_input_basenames(annual_inputs)
  annual_period <- epm_extract_annual_period_from_inputs(annual_basenames)
} else if (file.exists(output_path)) {
  existing_output <- epm_read_output(output_path, required = TRUE)
  annual_period <- unique(as.character(existing_output$period))

  if (length(annual_period) != 1L || is.na(annual_period) || !nzchar(annual_period)) {
    .epm_abort("Existing annual income poverty output must contain one non-missing period.")
  }

  annual_basenames <- "existing_aggregate_output"
} else {
  .epm_abort("Annual raw inputs are unavailable and no existing aggregate output can be refreshed.")
}

line_reference <- epm_get_annual_poverty_line_reference(annual_period)
benchmark_reference <- epm_load_annual_benchmark_reference(config$paths)

if (isTRUE(annual_inputs_ready)) {
  persona <- enemduR::enemdu_read_data(
    path = annual_inputs$persona$path,
    survey_type = "anual",
    period = annual_period,
    inform_scope = FALSE
  )

  persona <- enemduR::enemdu_build_variables(persona)

  estimates <- epm_build_income_poverty_estimates(persona, line_reference)
  comparisons <- epm_compare_income_poverty_benchmarks(estimates, benchmark_reference)

  output <- epm_to_monitor_income_poverty_output(
    estimates = estimates,
    comparisons = comparisons,
    annual_period = annual_period,
    reference = line_reference,
    source_file = annual_inputs$persona$basename
  )
} else {
  comparisons <- epm_compare_monitor_output_benchmarks(existing_output, benchmark_reference)
  output <- epm_refresh_monitor_income_poverty_output(existing_output, comparisons, line_reference)
}

epm_validate_annual_income_poverty_output(output)

epm_save_output(output, output_path)

message("Annual income poverty output complete.")
message(sprintf("Resolved annual inputs: %s", paste(annual_basenames, collapse = ", ")))
message(sprintf("Annual benchmark reference: %s", benchmark_reference$status))
message("Wrote data/derived/annual/annual_income_poverty.rds")
message("No raw microdata were written, copied, or staged.")
