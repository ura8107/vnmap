\name{vn_map}
\alias{vn_map}
\title{Obtain Viet Nam map data}
\usage{vn_map(geography = c("provinces", "provinces_63"), include = NULL,
  crs = vnmap_crs())}
\arguments{
  \item{geography}{Current 34-unit or historical 63-unit geography.}
  \item{include}{Optional names or codes to retain.}
  \item{crs}{A coordinate reference system understood by \code{sf}.}
}
\value{An \code{sf} object.}
\description{Returns bundled provincial boundary data for Viet Nam.}
\examples{
map <- vn_map()
nrow(map)

north <- vn_map(include = c("Ha Noi", "Bac Ninh"))
nrow(north)
}
