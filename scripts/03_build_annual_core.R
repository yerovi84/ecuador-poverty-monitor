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

epm_province_lookup <- function() {
  c(
    "01" = "Azuay",
    "02" = "Bolivar",
    "03" = "Canar",
    "04" = "Carchi",
    "05" = "Cotopaxi",
    "06" = "Chimborazo",
    "07" = "El Oro",
    "08" = "Esmeraldas",
    "09" = "Guayas",
    "10" = "Imbabura",
    "11" = "Loja",
    "12" = "Los Rios",
    "13" = "Manabi",
    "14" = "Morona Santiago",
    "15" = "Napo",
    "16" = "Pastaza",
    "17" = "Pichincha",
    "18" = "Tungurahua",
    "19" = "Zamora Chinchipe",
    "20" = "Galapagos",
    "21" = "Sucumbios",
    "22" = "Orellana",
    "23" = "Santo Domingo de los Tsachilas",
    "24" = "Santa Elena"
  )
}

epm_province_code <- function(values) {
  values_num <- suppressWarnings(as.integer(as.numeric(as.character(values))))
  out <- ifelse(!is.na(values_num), sprintf("%02d", values_num), NA_character_)
  out[!out %in% names(epm_province_lookup())] <- NA_character_
  out
}

epm_build_income_poverty_province_estimates <- function(data, reference) {
  if (!"prov" %in% names(data)) {
    .epm_abort("Annual person data must contain ENEMDU province variable `prov`.")
  }

  data[[".epm_province_code"]] <- epm_province_code(data[["prov"]])

  if (all(is.na(data[[".epm_province_code"]]))) {
    .epm_abort("Could not map annual `prov` values to two-digit province codes.")
  }

  estimates <- enemduR::enemdu_kpi_income_poverty(
    data = data,
    group_vars = ".epm_province_code",
    period = reference$period,
    mode = "manual",
    poverty_line = reference$poverty_line,
    extreme_poverty_line = reference$extreme_poverty_line,
    line_source = reference$line_source,
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    domain_level = "provincia_24",
    domain_var = "prov",
    official_validation_status = "not_officially_validated",
    official_validation_note = paste(
      "Survey-weighted analytical provincial output;",
      "not directly benchmarked against public annual tabulations."
    )
  )

  estimates[["domain"]] <- "province"
  estimates[["domain_value"]] <- estimates[[".epm_province_code"]]
  estimates
}

epm_as_numeric_profile_code <- function(x) {
  if (is.factor(x)) {
    x <- as.character(x)
  }

  suppressWarnings(as.numeric(x))
}

epm_profile_age_group <- function(age) {
  age <- epm_as_numeric_profile_code(age)
  out <- rep(NA_character_, length(age))

  out[!is.na(age) & age >= 0 & age <= 14] <- "age_0_14"
  out[!is.na(age) & age >= 15 & age <= 24] <- "age_15_24"
  out[!is.na(age) & age >= 25 & age <= 44] <- "age_25_44"
  out[!is.na(age) & age >= 45 & age <= 64] <- "age_45_64"
  out[!is.na(age) & age >= 65] <- "age_65_plus"

  out
}

epm_profile_sex <- function(sex) {
  sex <- epm_as_numeric_profile_code(sex)
  out <- rep(NA_character_, length(sex))

  out[sex == 1] <- "male"
  out[sex == 2] <- "female"

  out
}

epm_profile_education_adult <- function(age, education_level) {
  age <- epm_as_numeric_profile_code(age)
  education_level <- epm_as_numeric_profile_code(education_level)
  out <- rep(NA_character_, length(age))
  adults <- !is.na(age) & age >= 25

  out[adults & education_level %in% c(1, 2)] <- "no_formal_or_literacy"
  out[adults & education_level %in% c(3, 4)] <- "primary_or_basic"
  out[adults & education_level %in% c(5, 6)] <- "secondary_or_bachillerato"
  out[adults & education_level %in% c(7, 8, 9)] <- "higher"

  out
}

epm_prepare_income_poverty_profile_data <- function(data) {
  required <- c("p02", "p03", "p10a")
  missing <- setdiff(required, names(data))

  if (length(missing) > 0L) {
    .epm_abort(sprintf(
      "Annual profile build requires ENEMDU variable(s): %s",
      paste(missing, collapse = ", ")
    ))
  }

  data[[".epm_profile_sex"]] <- epm_profile_sex(data[["p02"]])
  data[[".epm_profile_age_group"]] <- epm_profile_age_group(data[["p03"]])
  data[[".epm_profile_education_adult"]] <- epm_profile_education_adult(
    age = data[["p03"]],
    education_level = data[["p10a"]]
  )

  data
}

epm_income_poverty_profile_definitions <- function() {
  list(
    sex = list(
      variable = ".epm_profile_sex",
      label = "Sex",
      universe = "All persons with valid sex code",
      values = c(
        female = "Female",
        male = "Male"
      )
    ),
    age_group = list(
      variable = ".epm_profile_age_group",
      label = "Age group",
      universe = "All persons with valid age",
      values = c(
        age_0_14 = "0-14",
        age_15_24 = "15-24",
        age_25_44 = "25-44",
        age_45_64 = "45-64",
        age_65_plus = "65+"
      )
    ),
    education_level_adult = list(
      variable = ".epm_profile_education_adult",
      label = "Adult education level",
      universe = "Adults 25+ with valid education level",
      values = c(
        no_formal_or_literacy = "No formal education or literacy center",
        primary_or_basic = "Primary or basic education",
        secondary_or_bachillerato = "Secondary or bachillerato",
        higher = "Higher education"
      )
    )
  )
}

epm_profile_label <- function(value, definition) {
  labels <- definition$values

  if (!is.null(labels) && value %in% names(labels)) {
    return(unname(labels[[value]]))
  }

  as.character(value)
}

epm_estimate_income_poverty_profile <- function(data,
                                                profile_dimension,
                                                definition,
                                                reference) {
  profile_var <- definition$variable

  if (!profile_var %in% names(data)) {
    .epm_abort(sprintf("Profile variable `%s` is missing.", profile_var))
  }

  profile_values <- as.character(data[[profile_var]])
  keep <- !is.na(profile_values) & nzchar(profile_values)
  work <- data[keep, , drop = FALSE]

  if (nrow(work) == 0L) {
    .epm_abort(sprintf("Profile `%s` has no valid observations.", profile_dimension))
  }

  estimates <- enemduR::enemdu_kpi_income_poverty(
    data = work,
    group_vars = profile_var,
    period = reference$period,
    mode = "manual",
    poverty_line = reference$poverty_line,
    extreme_poverty_line = reference$extreme_poverty_line,
    line_source = reference$line_source,
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    domain_level = "subpoblacion_sociodemografica",
    domain_var = profile_var,
    official_validation_status = "not_officially_validated",
    official_validation_note = "Analytical profile; benchmarked headline estimates are separate from non-benchmarked profile estimates."
  )

  estimates[["profile_dimension"]] <- profile_dimension
  estimates[["profile_dimension_label"]] <- definition$label
  estimates[["profile_value"]] <- as.character(estimates[[profile_var]])
  estimates[["profile_label"]] <- vapply(
    estimates[["profile_value"]],
    epm_profile_label,
    character(1),
    definition = definition
  )
  estimates[["profile_universe"]] <- definition$universe
  estimates[setdiff(names(estimates), profile_var)]
}

epm_build_income_poverty_profile_estimates <- function(data, reference) {
  data <- epm_prepare_income_poverty_profile_data(data)
  definitions <- epm_income_poverty_profile_definitions()

  pieces <- lapply(names(definitions), function(profile_dimension) {
    epm_estimate_income_poverty_profile(
      data = data,
      profile_dimension = profile_dimension,
      definition = definitions[[profile_dimension]],
      reference = reference
    )
  })

  out <- do.call(rbind, pieces)
  row.names(out) <- NULL
  out
}

epm_to_monitor_income_poverty_profile_output <- function(estimates,
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
  estimates <- estimates[!is.na(estimates$monitor_indicator_id), , drop = FALSE]

  out <- data.frame(
    indicator_id = estimates$monitor_indicator_id,
    indicator_label = unname(label_map[estimates$monitor_indicator_id]),
    indicator_family = "income_poverty",
    period = annual_period,
    survey_type = "anual",
    domain = as.character(estimates$profile_dimension),
    domain_value = as.character(estimates$profile_value),
    profile_dimension = as.character(estimates$profile_dimension),
    profile_dimension_label = as.character(estimates$profile_dimension_label),
    profile_value = as.character(estimates$profile_value),
    profile_label = as.character(estimates$profile_label),
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
    universe = as.character(estimates$profile_universe),
    weight = as.character(estimates$estimation_weight),
    method_status = as.character(estimates$decision),
    profile_status = "survey_weighted_profile",
    benchmark_check = "not_directly_benchmarked",
    official_alignment = "official-source alignment documentation; no official institutional validation",
    benchmark_estimate = NA_real_,
    benchmark_unit = "percent",
    benchmark_difference_pp = NA_real_,
    benchmark_reference = NA_character_,
    benchmark_source_file = NA_character_,
    benchmark_status = "not_directly_benchmarked",
    source_note = reference$line_source,
    method_note = paste(
      "Survey-design-aware analytical income-poverty profile from ENEMDU annual microdata via enemduR v0.1.1.",
      "Profiles are weighted analytical subpopulation estimates and are not directly benchmarked against public annual tabulations.",
      "This is official-source alignment documentation; no official institutional validation."
    ),
    source_file = source_file,
    source_reference = "ENEMDU annual 2025 analytical poverty profile build contract",
    stringsAsFactors = FALSE
  )

  out <- out[order(
    out$profile_dimension,
    out$indicator_id,
    out$profile_value
  ), , drop = FALSE]
  row.names(out) <- NULL
  out
}

epm_validate_annual_income_poverty_profile_output <- function(output) {
  epm_validate_output_schema(output, config$indicators, strict = FALSE)

  required_profiles <- c("sex", "age_group", "education_level_adult")
  missing_profiles <- setdiff(required_profiles, unique(output$profile_dimension))

  if (length(missing_profiles) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty profile output is missing profile dimension(s): %s",
      paste(missing_profiles, collapse = ", ")
    ))
  }

  required_indicators <- c("poverty_rate", "extreme_poverty_rate")
  missing_indicators <- setdiff(required_indicators, unique(output$indicator_id))

  if (length(missing_indicators) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty profile output is missing indicator(s): %s",
      paste(missing_indicators, collapse = ", ")
    ))
  }

  forbidden <- epm_detect_forbidden_paths(output, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("Annual income poverty profile output contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(output),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "Annual income poverty profile output contains microdata identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if (!identical(unique(output$unit), "proportion")) {
    .epm_abort("Annual income poverty profile output `unit` must be `proportion`.")
  }

  if (!identical(unique(output$display_unit), "percent")) {
    .epm_abort("Annual income poverty profile output `display_unit` must be `percent`.")
  }

  if ("build_timestamp" %in% names(output) && any(!is.na(output$build_timestamp))) {
    .epm_abort("Annual income poverty profile output must not contain dynamic build timestamps.")
  }

  invisible(TRUE)
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
    "This is official-source alignment documentation; no official institutional validation."
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
      "This is official-source alignment documentation; no official institutional validation."
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

epm_province_suppression_flag <- function(quality_flag) {
  quality_flag <- as.character(quality_flag)
  ifelse(
    !is.na(quality_flag) & quality_flag == "design_domain_reliable",
    "not_suppressed",
    "review_required"
  )
}

epm_rank_desc <- function(values) {
  out <- rep(NA_integer_, length(values))
  keep <- !is.na(values)

  if (any(keep)) {
    out[keep] <- as.integer(rank(-values[keep], ties.method = "min"))
  }

  out
}

epm_to_monitor_income_poverty_province_output <- function(estimates,
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
  estimates <- estimates[!is.na(estimates$monitor_indicator_id), , drop = FALSE]

  province_code <- as.character(estimates[[".epm_province_code"]])
  province_lookup <- epm_province_lookup()
  province_name <- unname(province_lookup[province_code])
  quality_flag <- epm_estimate_quality_flag(estimates)
  suppression_flag <- epm_province_suppression_flag(quality_flag)
  estimated_poor_count <- ifelse(
    estimates$monitor_indicator_id == "poverty_rate",
    as.numeric(estimates$estimate) * as.numeric(estimates$weighted_n),
    NA_real_
  )

  out <- data.frame(
    period = annual_period,
    survey_type = "anual",
    domain = "province",
    domain_value = province_code,
    province_code = province_code,
    province_name = province_name,
    indicator_id = estimates$monitor_indicator_id,
    indicator_label = unname(label_map[estimates$monitor_indicator_id]),
    indicator_family = "income_poverty",
    estimate = as.numeric(estimates$estimate),
    estimate_type = "proportion",
    unit = "proportion",
    display_estimate = as.numeric(estimates$estimate) * 100,
    display_unit = "percent",
    build_timestamp = NA_character_,
    weighted_n = as.numeric(estimates$weighted_n),
    unweighted_n = as.integer(estimates$unweighted_n),
    estimated_poor_count = estimated_poor_count,
    se = as.numeric(estimates$standard_error),
    cv = as.numeric(estimates$cv),
    df = as.numeric(estimates$degrees_freedom),
    analysis_unit = "people in households",
    universe = as.character(estimates$universe),
    source = "Public ENEMDU annual 2025 microdata",
    method_status = as.character(estimates$decision),
    benchmark_status = "not_directly_benchmarked_against_public_annual_tabulations",
    quality_flag = quality_flag,
    suppression_flag = suppression_flag,
    ranking_metric = ifelse(
      estimates$monitor_indicator_id == "poverty_rate",
      "estimated_poor_count_preferred_for_executive_table",
      "not_ranked_for_executive_top_5"
    ),
    rank_by_estimated_poor_count = NA_integer_,
    rank_by_poverty_rate = NA_integer_,
    public_note = paste(
      "Survey-weighted analytical provincial estimates;",
      "subject to precision and representativeness review before publication as rankings."
    ),
    source_layer = "annual",
    official_alignment = "official-source alignment documentation; no official institutional validation",
    method_note = paste(
      "Income poverty and extreme income poverty are estimated by province from ENEMDU annual person records.",
      "The calculation uses the same survey design contract as national and area outputs: ids upm, strata estrato, and weight fexp.",
      "Provincial estimates are not directly benchmarked against public annual tabulations."
    ),
    source_reference = reference$source_reference,
    source_file = source_file,
    stringsAsFactors = FALSE
  )

  rank_rows <- out$indicator_id == "poverty_rate" & out$suppression_flag == "not_suppressed"
  out$rank_by_estimated_poor_count[rank_rows] <- epm_rank_desc(out$estimated_poor_count[rank_rows])
  out$rank_by_poverty_rate[rank_rows] <- epm_rank_desc(out$estimate[rank_rows])

  out <- out[order(out$indicator_id, out$province_code), , drop = FALSE]
  row.names(out) <- NULL
  out
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

epm_validate_annual_income_poverty_province_output <- function(output) {
  epm_validate_output_schema(output, config$indicators, strict = FALSE)

  required_indicators <- c("poverty_rate", "extreme_poverty_rate")
  missing_indicators <- setdiff(required_indicators, unique(output$indicator_id))

  if (length(missing_indicators) > 0L) {
    .epm_abort(sprintf(
      "Annual provincial income poverty output is missing indicator(s): %s",
      paste(missing_indicators, collapse = ", ")
    ))
  }

  if (!identical(unique(output$domain), "province")) {
    .epm_abort("Annual provincial income poverty output `domain` must be `province`.")
  }

  province_lookup <- epm_province_lookup()

  for (indicator_id in required_indicators) {
    indicator_codes <- output$province_code[output$indicator_id == indicator_id]

    if (!setequal(indicator_codes, names(province_lookup))) {
      .epm_abort(sprintf(
        "Annual provincial income poverty output must contain 24 province codes for `%s`.",
        indicator_id
      ))
    }
  }

  if (any(is.na(output$province_name) | !nzchar(output$province_name))) {
    .epm_abort("Annual provincial income poverty output contains missing province names.")
  }

  forbidden <- epm_detect_forbidden_paths(output, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("Annual provincial income poverty output contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(output),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar", "upm", "estrato", "fexp")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "Annual provincial income poverty output contains microdata identifier or design column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if (!identical(unique(output$unit), "proportion")) {
    .epm_abort("Annual provincial income poverty output `unit` must be `proportion`.")
  }

  if (!identical(unique(output$display_unit), "percent")) {
    .epm_abort("Annual provincial income poverty output `display_unit` must be `percent`.")
  }

  if ("build_timestamp" %in% names(output) && any(!is.na(output$build_timestamp))) {
    .epm_abort("Annual provincial income poverty output must not contain dynamic build timestamps.")
  }

  invisible(TRUE)
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

epm_col_or_default <- function(data, col, default) {
  if (col %in% names(data)) {
    return(data[[col]])
  }

  rep(default, nrow(data))
}

epm_estimate_quality_flag <- function(estimates) {
  if ("representativity_flag" %in% names(estimates)) {
    return(as.character(estimates$representativity_flag))
  }

  if ("quality_flag" %in% names(estimates)) {
    return(as.character(estimates$quality_flag))
  }

  if ("decision" %in% names(estimates)) {
    return(as.character(estimates$decision))
  }

  rep(NA_character_, nrow(estimates))
}

epm_build_nbi_estimates <- function(data, household_data) {
  joined <- enemduR::enemdu_join_nbi_sources(
    person_data = data,
    household_data = household_data,
    household_id = "id_hogar",
    overwrite = TRUE,
    strict = TRUE
  )

  joined <- enemduR::enemdu_build_nbi_components(
    data = joined,
    household_id = "id_hogar",
    person_id = "p01",
    overwrite = TRUE,
    strict = TRUE
  )

  national <- enemduR::enemdu_kpi_nbi(
    data = joined,
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    household_id = "id_hogar",
    hsize = "hsize",
    official_validation_status = "not_officially_validated",
    official_validation_note = paste(
      "Survey-weighted analytical NBI estimates built with enemduR.",
      "They are not directly benchmarked against public annual tabulations."
    )
  )
  national[["domain"]] <- "national"
  national[["domain_value"]] <- "national"

  joined[[".epm_area_domain"]] <- epm_area_domain(joined[["area"]])

  if (all(is.na(joined[[".epm_area_domain"]]))) {
    .epm_abort("Could not map annual `area` values to urban/rural domains for NBI.")
  }

  area <- enemduR::enemdu_kpi_nbi(
    data = joined,
    group_vars = ".epm_area_domain",
    survey_type = "anual",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    domain_level = "urbano_rural",
    domain_var = "area",
    household_id = "id_hogar",
    hsize = "hsize",
    official_validation_status = "not_officially_validated",
    official_validation_note = paste(
      "Survey-weighted analytical NBI estimates built with enemduR.",
      "They are not directly benchmarked against public annual tabulations."
    )
  )
  area[["domain"]] <- "area"
  area[["domain_value"]] <- area[[".epm_area_domain"]]

  epm_bind_rows_fill(list(
    national,
    area[setdiff(names(area), ".epm_area_domain")]
  ))
}

epm_to_monitor_nbi_output <- function(estimates, annual_period) {
  id_map <- c(
    pobreza_nbi = "nbi_rate",
    pobreza_extrema_nbi = "extreme_nbi_rate"
  )

  label_map <- c(
    nbi_rate = "Unsatisfied Basic Needs poverty",
    extreme_nbi_rate = "Extreme Unsatisfied Basic Needs poverty"
  )

  estimates[["monitor_indicator_id"]] <- unname(id_map[as.character(estimates$indicator_id)])
  estimates <- estimates[!is.na(estimates$monitor_indicator_id), , drop = FALSE]

  out <- data.frame(
    indicator_id = estimates$monitor_indicator_id,
    indicator_label = unname(label_map[estimates$monitor_indicator_id]),
    indicator_family = "basic_needs_deprivation",
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
    se = as.numeric(epm_col_or_default(estimates, "standard_error", NA_real_)),
    cv = as.numeric(epm_col_or_default(estimates, "cv", NA_real_)),
    n = as.integer(epm_col_or_default(estimates, "unweighted_n", NA_integer_)),
    df = as.numeric(epm_col_or_default(estimates, "degrees_freedom", NA_real_)),
    weighted_n = as.numeric(epm_col_or_default(estimates, "weighted_n", NA_real_)),
    precision_flag = epm_estimate_quality_flag(estimates),
    quality_flag = as.character(epm_col_or_default(estimates, "quality_flag", NA_character_)),
    analysis_unit = "people in households",
    universe = as.character(epm_col_or_default(estimates, "universe", "personas_en_base_enemdu")),
    weight = as.character(epm_col_or_default(estimates, "estimation_weight", "fexp")),
    method_status = as.character(epm_col_or_default(estimates, "decision", "survey_weighted_estimate")),
    official_alignment = "official-source alignment documentation; no official institutional validation",
    benchmark_estimate = NA_real_,
    benchmark_unit = "percent",
    benchmark_difference_pp = NA_real_,
    benchmark_reference = NA_character_,
    benchmark_source_file = NA_character_,
    benchmark_status = "not_directly_benchmarked_against_public_annual_tabulations",
    source = "Public ENEMDU annual 2025 microdata",
    source_note = "Survey-weighted analytical NBI estimates built with enemduR from person and dwelling records.",
    method_note = paste(
      "NBI and extreme NBI use enemduR component variables comp1-comp5 and output flags nbi/xnbi.",
      "No public annual NBI benchmark table was available in the enemduR benchmark registry for this build.",
      "This is official-source alignment documentation; no official institutional validation."
    ),
    public_note = "NBI and extreme NBI are survey-weighted analytical estimates; benchmark comparison is not directly available for this output.",
    source_reference = "ENEMDU annual 2025 deprivation analytical build contract",
    stringsAsFactors = FALSE
  )

  out[order(out$indicator_id, out$domain, out$domain_value), , drop = FALSE]
}

epm_build_ipm_reproducibility <- function(data, household_data, reference) {
  enemduR::enemdu_run_ipm_reproducibility(
    data = data,
    period = "2025-12",
    survey_type = "anual",
    by = "area",
    ids = "upm",
    strata = "estrato",
    weight = "fexp",
    build_components = TRUE,
    build_flags = TRUE,
    strict = FALSE,
    missing_component_policy = "complete_case",
    sample_n_min = 60,
    household_data = household_data,
    household_id = "id_hogar",
    person_id = "p01",
    extreme_poverty_income_var = "ingtot_pc",
    extreme_poverty_line = reference$extreme_poverty_line,
    higher_education_economic_reason_codes = 3
  )
}

epm_to_monitor_ipm_output <- function(ipm_result, annual_period) {
  estimates <- ipm_result$estimates
  estimates <- estimates[
    estimates$indicator_id %in% c("tpm", "tpem"),
    ,
    drop = FALSE
  ]

  id_map <- c(
    tpm = "tpm_rate",
    tpem = "tpem_rate"
  )

  label_map <- c(
    tpm_rate = "Multidimensional poverty",
    tpem_rate = "Extreme multidimensional poverty"
  )

  estimates[["monitor_indicator_id"]] <- unname(id_map[as.character(estimates$indicator_id)])
  estimates[["monitor_domain"]] <- ifelse(
    as.character(estimates$domain_value) == "national",
    "national",
    "area"
  )

  comparison <- ipm_result$comparison
  comparison <- comparison[comparison$indicator_id %in% c("tpm", "tpem"), , drop = FALSE]
  comparison_key <- paste(comparison$indicator_id, comparison$domain_value, sep = "\r")
  estimate_key <- paste(estimates$indicator_id, estimates$domain_value, sep = "\r")
  matched <- match(estimate_key, comparison_key)

  out <- data.frame(
    indicator_id = estimates$monitor_indicator_id,
    indicator_label = unname(label_map[estimates$monitor_indicator_id]),
    indicator_family = "multidimensional_poverty",
    period = annual_period,
    survey_type = "anual",
    domain = as.character(estimates$monitor_domain),
    domain_value = as.character(estimates$domain_value),
    estimate = as.numeric(estimates$estimate),
    estimate_type = "proportion",
    unit = "proportion",
    display_estimate = as.numeric(estimates$estimate) * 100,
    display_unit = "percent",
    source_layer = "annual",
    build_timestamp = NA_character_,
    se = as.numeric(epm_col_or_default(estimates, "standard_error", NA_real_)),
    cv = as.numeric(epm_col_or_default(estimates, "cv", NA_real_)),
    n = as.integer(epm_col_or_default(estimates, "unweighted_n", NA_integer_)),
    df = as.numeric(epm_col_or_default(estimates, "degrees_freedom", NA_real_)),
    weighted_n = as.numeric(epm_col_or_default(estimates, "weighted_n", NA_real_)),
    precision_flag = epm_estimate_quality_flag(estimates),
    quality_flag = as.character(epm_col_or_default(estimates, "quality_flag", NA_character_)),
    analysis_unit = "people with complete IPM evidence",
    universe = "persons in complete-case IPM analytical universe",
    weight = "fexp",
    method_status = as.character(epm_col_or_default(estimates, "decision", "survey_weighted_estimate")),
    official_alignment = "official-source alignment documentation; no official institutional validation",
    benchmark_estimate = NA_real_,
    benchmark_unit = "percent",
    benchmark_difference_pp = NA_real_,
    benchmark_reference = "enemduR public IPM benchmark registry for December 2025",
    benchmark_source_file = NA_character_,
    benchmark_status = "annual_ipm_benchmark_not_matched",
    source = "Public ENEMDU annual 2025 microdata",
    source_note = "Survey-weighted analytical TPM/TPEM estimates built with enemduR IPM component and flag contracts.",
    method_note = paste(
      "TPM uses the enemduR row-level tpm flag and TPEM uses the tpem flag.",
      "IPM components are built from the registered 12-component contract with complete-case handling for incomplete evidence.",
      "This is official-source alignment documentation; no official institutional validation."
    ),
    public_note = "TPM/TPEM estimates are survey-weighted analytical estimates; public IPM benchmark comparison is documented separately.",
    complete_case_rows_excluded = as.integer(ipm_result$complete_case_diagnostics$rows_excluded[[1]]),
    complete_case_weighted_share_excluded = as.numeric(ipm_result$complete_case_diagnostics$share_weighted_excluded[[1]]),
    stringsAsFactors = FALSE
  )

  has_match <- !is.na(matched)
  out$benchmark_estimate[has_match] <- comparison$official_estimate[matched[has_match]] * 100
  out$benchmark_difference_pp[has_match] <- comparison$difference_pp[matched[has_match]]
  out$benchmark_status[has_match] <- comparison$comparison_status[matched[has_match]]

  out[order(out$indicator_id, out$domain, out$domain_value), , drop = FALSE]
}

epm_build_deprivation_multidimensional_output <- function(data,
                                                          household_data,
                                                          reference,
                                                          annual_period) {
  nbi_estimates <- epm_build_nbi_estimates(
    data = data,
    household_data = household_data
  )
  nbi_output <- epm_to_monitor_nbi_output(
    estimates = nbi_estimates,
    annual_period = annual_period
  )

  ipm_result <- epm_build_ipm_reproducibility(
    data = data,
    household_data = household_data,
    reference = reference
  )
  ipm_output <- epm_to_monitor_ipm_output(
    ipm_result = ipm_result,
    annual_period = annual_period
  )

  out <- epm_bind_rows_fill(list(nbi_output, ipm_output))
  out <- out[order(out$indicator_id, out$domain, out$domain_value), , drop = FALSE]
  row.names(out) <- NULL
  out
}

epm_validate_annual_deprivation_multidimensional_output <- function(output) {
  epm_validate_output_schema(output, config$indicators, strict = FALSE)

  required_indicators <- c("nbi_rate", "extreme_nbi_rate", "tpm_rate", "tpem_rate")
  missing_indicators <- setdiff(required_indicators, unique(output$indicator_id))

  if (length(missing_indicators) > 0L) {
    .epm_abort(sprintf(
      "Annual deprivation/multidimensional output is missing indicator(s): %s",
      paste(missing_indicators, collapse = ", ")
    ))
  }

  required_domains <- c("national", "area")
  missing_domains <- setdiff(required_domains, unique(output$domain))

  if (length(missing_domains) > 0L) {
    .epm_abort(sprintf(
      "Annual deprivation/multidimensional output is missing domain(s): %s",
      paste(missing_domains, collapse = ", ")
    ))
  }

  forbidden <- epm_detect_forbidden_paths(output, config$paths$validation$forbidden_patterns)

  if (length(forbidden) > 0L) {
    .epm_abort("Annual deprivation/multidimensional output contains private path-like values.")
  }

  identifier_columns <- intersect(
    names(output),
    c("p01", "id_persona", "id_hogar", "idhogar", "id_persona_hogar")
  )

  if (length(identifier_columns) > 0L) {
    .epm_abort(sprintf(
      "Annual deprivation/multidimensional output contains microdata identifier column(s): %s",
      paste(identifier_columns, collapse = ", ")
    ))
  }

  if (!identical(unique(output$unit), "proportion")) {
    .epm_abort("Annual deprivation/multidimensional output `unit` must be `proportion`.")
  }

  if (!identical(unique(output$display_unit), "percent")) {
    .epm_abort("Annual deprivation/multidimensional output `display_unit` must be `percent`.")
  }

  if ("build_timestamp" %in% names(output) && any(!is.na(output$build_timestamp))) {
    .epm_abort("Annual deprivation/multidimensional output must not contain dynamic build timestamps.")
  }

  invisible(TRUE)
}

epm_require_enemduR()

output_path <- epm_output_path("annual", "annual_income_poverty", config$paths)
profile_output_path <- epm_output_path("annual", "annual_income_poverty_profiles", config$paths)
province_output_path <- epm_output_path("annual", "annual_income_poverty_province", config$paths)
deprivation_output_path <- epm_output_path(
  "annual",
  "annual_deprivation_multidimensional_poverty",
  config$paths
)
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

  vivienda <- enemduR::enemdu_read_data(
    path = annual_inputs$vivienda$path,
    survey_type = "anual",
    period = annual_period,
    inform_scope = FALSE
  )

  estimates <- epm_build_income_poverty_estimates(persona, line_reference)
  comparisons <- epm_compare_income_poverty_benchmarks(estimates, benchmark_reference)

  output <- epm_to_monitor_income_poverty_output(
    estimates = estimates,
    comparisons = comparisons,
    annual_period = annual_period,
    reference = line_reference,
    source_file = annual_inputs$persona$basename
  )

  province_estimates <- epm_build_income_poverty_province_estimates(persona, line_reference)
  province_output <- epm_to_monitor_income_poverty_province_output(
    estimates = province_estimates,
    annual_period = annual_period,
    reference = line_reference,
    source_file = annual_inputs$persona$basename
  )

  profile_estimates <- epm_build_income_poverty_profile_estimates(persona, line_reference)
  profile_output <- epm_to_monitor_income_poverty_profile_output(
    estimates = profile_estimates,
    annual_period = annual_period,
    reference = line_reference,
    source_file = annual_inputs$persona$basename
  )

  deprivation_output <- epm_build_deprivation_multidimensional_output(
    data = persona,
    household_data = vivienda,
    reference = line_reference,
    annual_period = annual_period
  )
} else {
  comparisons <- epm_compare_monitor_output_benchmarks(existing_output, benchmark_reference)
  output <- epm_refresh_monitor_income_poverty_output(existing_output, comparisons, line_reference)
  province_output <- NULL
  profile_output <- NULL
  deprivation_output <- NULL
}

epm_validate_annual_income_poverty_output(output)

epm_save_output(output, output_path)

if (is.data.frame(province_output)) {
  epm_validate_annual_income_poverty_province_output(province_output)
  epm_save_output(province_output, province_output_path)
}

if (is.data.frame(profile_output)) {
  epm_validate_annual_income_poverty_profile_output(profile_output)
  epm_save_output(profile_output, profile_output_path)
}

if (is.data.frame(deprivation_output)) {
  epm_validate_annual_deprivation_multidimensional_output(deprivation_output)
  epm_save_output(deprivation_output, deprivation_output_path)
}

message("Annual income poverty output complete.")
message(sprintf("Resolved annual inputs: %s", paste(annual_basenames, collapse = ", ")))
message(sprintf("Annual benchmark reference: %s", benchmark_reference$status))
message("Wrote data/derived/annual/annual_income_poverty.rds")
if (is.data.frame(profile_output)) {
  message("Wrote data/derived/annual/annual_income_poverty_profiles.rds")
} else {
  message("Annual profile output skipped because raw annual inputs were unavailable.")
}
if (is.data.frame(province_output)) {
  message("Wrote data/derived/annual/annual_income_poverty_province.rds")
} else {
  message("Annual provincial income poverty output skipped because raw annual inputs were unavailable.")
}
if (is.data.frame(deprivation_output)) {
  message("Wrote data/derived/annual/annual_deprivation_multidimensional_poverty.rds")
} else if (file.exists(deprivation_output_path)) {
  message("Annual deprivation/multidimensional output retained from existing aggregate file.")
} else {
  message("Annual deprivation/multidimensional output skipped because raw annual inputs were unavailable.")
}
message("No raw microdata were written, copied, or staged.")
