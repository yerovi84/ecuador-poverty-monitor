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

  required <- c("site_periods", "site_sources", "site_quality_flags")
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

epm_save_site_metadata <- function(output_name, data, config) {
  path <- epm_output_path("site", output_name, config$paths)
  epm_make_dir(dirname(path))
  saveRDS(data, path)
  normalizePath(path, winslash = "/", mustWork = TRUE)
}

required_outputs <- epm_required_site_outputs(config)
invisible(epm_make_dir(epm_layer_derived_dir("site", config$paths)))

metadata <- list(
  site_periods = epm_build_site_periods(config),
  site_sources = epm_build_site_sources(config),
  site_quality_flags = epm_build_site_quality_flags(config)
)

written_paths <- vapply(required_outputs, function(output_name) {
  epm_save_site_metadata(output_name, metadata[[output_name]], config)
}, character(1))

message("Site metadata builder complete.")
message("Operational assumption: minimal site metadata maps to existing `site_periods`, `site_sources`, and `site_quality_flags` contracts.")
message("Written site metadata outputs:")
for (output_name in names(written_paths)) {
  message(sprintf("- %s: %s", output_name, written_paths[[output_name]]))
}
message("No microdata were read and no analytical indicators were calculated.")
