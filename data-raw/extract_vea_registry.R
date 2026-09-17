# Extract the dated public environmental-agency register. Download the source
# URL below into tmp/vea-industrial.html first. Never include research-only data.
library(rvest)
tabs <- html_table(read_html("tmp/vea-industrial.html"), fill = TRUE)
stopifnot(length(tabs) == 9L, all(vapply(tabs, ncol, 1L) == 5L))
x <- do.call(rbind, lapply(tabs, function(t) {
  names(t) <- c("source_id", "province_vi", "name_vi", "developer", "address")
  t
}))
x[] <- lapply(x, function(y) trimws(gsub("[[:space:]\u00a0]+", " ", y)))
x <- x[grepl("^[0-9]+$", x$source_id), ]
stopifnot(nrow(x) == 303L, !anyDuplicated(x$source_id))
x$source_url <- "https://vea.mae.gov.vn/khu-cong-nghiep/5867/danh-sach-cac-khu-cong-nghiep"
x$source_date <- "2023-02-24"
x$retrieved_on <- "2026-09-10"
write.csv(x, "data-raw/source/industrial-park-evidence/vea-registry-2023.csv", row.names = FALSE)
