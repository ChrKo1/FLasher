% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/test_helper_functions.R
\name{random_FLCatch_generator}
\alias{random_FLCatch_generator}
\title{Generate randomly sized and filled FLCatch objects}
\usage{
random_FLCatch_generator(sd = 100, ...)
}
\arguments{
\item{sd}{The standard deviation of the random numbers. Passed to rnorm() Default is 100.}

\item{...}{Other arguments passed to random_FLQuant_generator().}
}
\value{
An FLCatch
}
\description{
Generate an FLCatch of random size and filled with normally distributed random numbers with a mean of 0.
Used for automatic testing, particularly of the FLCatch class in CPP.
}
\examples{
flc <- random_FLCatch_generator()
summary(flc)
}
