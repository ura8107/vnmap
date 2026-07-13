\name{plot_vnmap}
\alias{plot_vnmap}
\title{Plot a map of Viet Nam}
\usage{plot_vnmap(geography = c("provinces", "provinces_63"), data = NULL,
  values = NULL, id = "code", include = NULL, labels = FALSE, ...)}
\arguments{
  \item{geography}{Current 34-unit or historical 63-unit geography.}
  \item{data}{Optional data frame containing identifiers and values.}
  \item{values}{Column in \code{data} mapped to fill.}
  \item{id}{Column in \code{data} containing province names or codes.}
  \item{include}{Optional unit names or codes to display.}
  \item{labels}{Whether to add Vietnamese unit labels.}
  \item{...}{Arguments passed to \code{ggplot2::geom_sf()}.}
}
\value{A \code{ggplot} object.}
\description{Creates a choropleth or outline map from bundled boundary data.}
\examples{
plot_vnmap(color = "white", linewidth = 0.2)

values <- transform(province_info(), value = seq_len(34))
plot_vnmap(values = "value", data = values, color = "white", linewidth = 0.2)
}
