\name{province_code}
\alias{province_code}
\title{Look up Vietnamese provincial administrative codes}
\usage{province_code(x, geography = c("provinces", "provinces_63"))}
\arguments{
  \item{x}{Character vector of names or codes.}
  \item{geography}{Current 34-unit or historical 63-unit geography.}
}
\value{A character vector of two-digit administrative codes.}
\description{Accepts names with or without Vietnamese diacritics and common aliases.}
\examples{
province_code(c("Da Nang", "Danang", "Đà Nẵng"))
province_code("Bac Giang", geography = "provinces_63")
}
