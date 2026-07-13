if (!requireNamespace("roxygen2", quietly = TRUE)) {
  stop("Install 'roxygen2' before rebuilding the manual.", call. = FALSE)
}

roxygen2::roxygenise()
dir.create(file.path("output", "pdf"), recursive = TRUE, showWarnings = FALSE)

r <- file.path(R.home("bin"), "R")
args <- c(
  "CMD", "Rd2pdf", ".",
  "--output=output/pdf/vnmap.pdf",
  "--force",
  "--no-preview"
)

status <- system2(r, args)
if (!identical(status, 0L)) {
  stop("PDF manual generation failed.", call. = FALSE)
}

message("Created output/pdf/vnmap.pdf")
