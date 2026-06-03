required_packages <- c("yaml")

missing_packages <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  quietly = TRUE,
  FUN.VALUE = logical(1)
)]

if (length(missing_packages) == 0L) {
  message("EPM pipeline requirements are already installed.")
  quit(status = 0L)
}

message(
  "Installing missing EPM pipeline requirement(s): ",
  paste(missing_packages, collapse = ", ")
)

install.packages(missing_packages, repos = "https://cloud.r-project.org")

still_missing <- required_packages[!vapply(
  required_packages,
  requireNamespace,
  quietly = TRUE,
  FUN.VALUE = logical(1)
)]

if (length(still_missing) > 0L) {
  stop(
    "Failed to install required package(s): ",
    paste(still_missing, collapse = ", "),
    ". Check your R library permissions or configure `.libPaths()` before rerunning.",
    call. = FALSE
  )
}

message("EPM pipeline requirements installed successfully.")
