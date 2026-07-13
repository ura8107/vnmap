\name{province_info}
\alias{province_info}
\title{Retrieve Vietnamese provincial metadata}
\usage{province_info(x = NULL, geography = c("provinces", "provinces_63"))}
\arguments{
  \item{x}{Optional names or codes; omitted to return every unit.}
  \item{geography}{Current 34-unit or historical 63-unit geography.}
}
\value{A data frame with codes and Vietnamese and English names.}
\description{Provides metadata suitable for joining statistical data to maps.}
\examples{
head(province_info())
province_info(c("01", "HCMC"))
}
