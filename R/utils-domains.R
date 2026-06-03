epm_domain_registry <- function(domains_config) {
  registry <- domains_config$domains

  if (!is.list(registry) || length(registry) == 0L) {
    .epm_abort("`domains_config$domains` must be a non-empty named list.")
  }

  registry
}

epm_valid_domains <- function(domains_config) {
  names(epm_domain_registry(domains_config))
}

epm_domain_valid_for <- function(domain, survey_type, domains_config) {
  registry <- epm_domain_registry(domains_config)
  domain_config <- registry[[domain]]

  if (is.null(domain_config)) {
    return(FALSE)
  }

  valid_for <- domain_config$valid_for

  if (is.null(valid_for)) {
    valid_for <- character()
  }

  if (identical(survey_type, "all")) {
    return(length(intersect(valid_for, epm_valid_survey_types())) > 0L)
  }

  survey_type %in% valid_for
}

epm_validate_domain_period <- function(domain, survey_type, domains_config) {
  if (!.epm_is_scalar_character(domain)) {
    .epm_abort("`domain` must be a non-empty character string.")
  }

  if (!survey_type %in% c(epm_valid_survey_types(), "all")) {
    .epm_abort(sprintf("Invalid survey type for domain validation: %s", survey_type))
  }

  if (!domain %in% epm_valid_domains(domains_config)) {
    .epm_abort(sprintf("Unknown domain: %s", domain))
  }

  if (!epm_domain_valid_for(domain, survey_type, domains_config)) {
    .epm_abort(sprintf(
      "Domain `%s` is not valid for survey type `%s`.",
      domain,
      survey_type
    ))
  }

  invisible(TRUE)
}

epm_validate_indicator_domains <- function(indicators_config, domains_config) {
  indicators <- indicators_config$indicators

  if (!is.list(indicators) || length(indicators) == 0L) {
    .epm_abort("`indicators_config$indicators` must be a non-empty named list.")
  }

  for (indicator_id in names(indicators)) {
    indicator <- indicators[[indicator_id]]

    if (!isTRUE(indicator$enabled)) {
      next
    }

    survey_type <- indicator$survey_type
    allowed_domains <- indicator$allowed_domains

    if (!.epm_is_scalar_character(survey_type)) {
      .epm_abort(sprintf("Indicator `%s` must define `survey_type`.", indicator_id))
    }

    if (!survey_type %in% c(epm_valid_survey_types(), "all")) {
      .epm_abort(sprintf("Indicator `%s` has invalid survey type `%s`.", indicator_id, survey_type))
    }

    if (!is.character(allowed_domains) || length(allowed_domains) == 0L) {
      .epm_abort(sprintf("Indicator `%s` must define non-empty `allowed_domains`.", indicator_id))
    }

    for (domain in allowed_domains) {
      epm_validate_domain_period(domain, survey_type, domains_config)
    }
  }

  invisible(TRUE)
}

epm_domain_label <- function(domain, domains_config, lang = "en") {
  domain_config <- epm_domain_registry(domains_config)[[domain]]

  if (is.null(domain_config)) {
    .epm_abort(sprintf("Unknown domain: %s", domain))
  }

  field <- switch(
    lang,
    en = "label_en",
    es = "label_es",
    .epm_abort("`lang` must be either `en` or `es`.")
  )

  label <- domain_config[[field]]

  if (is.null(label)) {
    return(domain)
  }

  label
}
