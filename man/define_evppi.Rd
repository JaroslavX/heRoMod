% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/evppi_define.R
\name{define_evppi}
\alias{define_evppi}
\alias{define_evppi_}
\title{Define an Expected Value of Partial Perfect Information (EVPPI) Analysis}
\usage{
define_evppi(...)

define_evppi_(par_names)
}
\arguments{
\item{par_names}{String of parameter name or names}
}
\value{
An \code{evppi} object.
}
\description{
Define the parameter for EVPPI analysis of Markov models using a
linear regression metmodeling approach
}
\details{
The parameter name should be a string
}
\examples{
evppi.p1 <- define_evppi(
  prob1
)
evppi.p1
}
\references{
\enumerate{
\item Jalal H, Alarid-Escudero F. A Gaussian Approximation Approach for Value of Information Analysis. Med Decis Making 2018; 38(2): 174-188.
}
}
