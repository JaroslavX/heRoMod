#**************************************************************************
#* 
#* Original work Copyright (C) 2015  Antoine Pierucci
#* Original work Copyright (C) 2016  Matt Wiener
#*
#* This program is free software: you can redistribute it and/or modify
#* it under the terms of the GNU General Public License as published by
#* the Free Software Foundation, either version 3 of the License, or
#* (at your option) any later version.
#*
#* This program is distributed in the hope that it will be useful,
#* but WITHOUT ANY WARRANTY; without even the implied warranty of
#* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#* GNU General Public License for more details.
#*
#* You should have received a copy of the GNU General Public License
#* along with this program.  If not, see <http://www.gnu.org/licenses/>.
#**************************************************************************


#' Probability Density Functions for Probabilistic 
#' Uncertainty Analysis
#' 
#' Define a distribution for PSA parameters.
#' 
#' These functions are not exported, but only used
#' in [define_psa()]. To specify a user-made 
#' function use [define_distribution()].
#' 
#' [use_distribution()] uses gaussian kernel 
#' smoothing with a bandwith parameter calculated 
#' by [stats::density()]. Values for unobserved
#' quantiles are calculated by linear
#' interpolation.
#' 
#' [define_distribution()] takes as argument a 
#' function with a single argument, `x`, 
#' corresponding to a vector of quantiles. It 
#' returns the distribution values for the given 
#' quantiles. See examples.
#' 
#' @name distributions
#' @param mean Distribution mean.
#' @param sd Distribution standard deviation.
#' @param ... Dirichlet distribution parameters.
#' @param prob Proportion.
#' @param size Size of sample used to estimate 
#'   proportion.
#' @param meanlog Mean on the log scale.
#' @param sdlog SD on the log scale.
#' @param mu Mean on the logit scale.
#' @param sigma SD on the logit scale.
#' @param shape1 for beta distribution
#' @param shape2 for beta distribution
#' @param lower lower bound of triangular 
#'   distribution.
#' @param upper upper bound of triangular 
#'   distribution.
#' @param peak peak of triangular distribution.
#' @param x A distribution function, see details.
#' @param distribution A numeric vector of 
#'   observations defining a distribution, usually
#'   the output from an MCMC fit.
#' @param smooth Use gaussian kernel smoothing?
#'   
#' @examples 
#' define_distribution(
#'   function(x) stats::qexp(p = x, rate = 0.5)
#' )
#' 
#' # a mixture of 2 gaussians
#' x <- c(rnorm(100), rnorm(100, 6))
#' plot(density(x))
#' 
#' use_distribution(x)
normal <- function(mean, sd) {
  list(r_normal(mean, sd))
}
r_normal <- function(mean, sd) {
  function(x) stats::qnorm(p = x, mean = mean, sd = sd)
}

#' @rdname distributions
lognormal <- function(mean, sd, meanlog, sdlog) {
  if (missing(sdlog)) sdlog <- sqrt(log(1 + sd^2/mean^2))
  if (missing(meanlog)) meanlog <- log(mean) - sdlog^2/2
  
  list(r_lognormal(meanlog, sdlog))
}
r_lognormal <- function(meanlog, sdlog) {
  function(x) stats::qlnorm(p = x, meanlog = meanlog, sdlog = sdlog)
}

#' @rdname distributions
gamma <- function(mean, sd) {
  list(r_gamma(mean^2/sd^2, sd^2/mean))
}
make_gamma <- function(...) {
  warning("'make_gamma()' is deprecated, use 'gamma()' instead.")
  gamma(...)
}
r_gamma <- function(shape, scale) {
  function(x) stats::qgamma(p = x, shape = shape, scale = scale)
}

#' @rdname distributions
binomial <- function(prob, size) {
  list(r_binomial(prob, size))
}
prop <- function(...) {
  warning("'prop() is deprecated, use 'binomial()' instead.")
  binomial(...)
}
r_binomial <- function(prob, size) {
  function(x) stats::qbinom(p = x, size = size, prob = prob) / size
}

#' @rdname distributions
multinomial <- function(...) {
  list_param <- list(...)
  
  structure(
    lapply(list_param, function(x) r_multinomial(x)),
    class = "multinom_param"
  )
}
multinom <- function(...) {
  warning("'multinom()' is deprecated, use 'multinomial()' instead.")
  multinomial(...)
}
r_multinomial <- function(n) {
  function(x) stats::qgamma(x, shape = n, scale = 1)
}

#' @rdname distributions
logitnormal <- function(mu, sigma) {
  if (! requireNamespace("logitnorm")) {
    stop("'logitnorm' package required for logitnormal distributions.")
  }
  
  list(r_logitnormal(mu, sigma))
}
r_logitnormal <- function(mu, sigma) {
  function(x) logitnorm::qlogitnorm(p = x, mu = mu, sigma = sigma)
}

#' @rdname distributions
beta <- function(shape1, shape2){
  list(r_beta(shape1, shape2))
}
r_beta <- function(shape1, shape2){
  function(x){stats::qbeta(p = x, shape1 = shape1, shape2 = shape2)}
}

#' @rdname distributions
poisson <- function(mean) {
  list(r_poisson(mean))
}
r_poisson <- function(mean) {
  function(x) stats::qpois(p = x, lambda = mean)
}

#' @rdname distributions
#' @export
define_distribution <- function(x) {
  list(x)
}

#' @rdname distributions
beta <- function(shape1, shape2){
  list(r_beta(shape1, shape2))
}
r_beta <- function(shape1, shape2){
  function(x){stats::qbeta(p = x, shape1 = shape1, shape2 = shape2)}
}

#' @rdname distributions
triangle <- function(lower, upper, peak = (lower + upper)/2) {
  if (! requireNamespace("triangle")) {
    stop("'triangle' package required for triangle distributions.")
  }
  list(r_triangle(lower, upper, peak))
}
r_triangle <- function(lower, upper, peak) {
  function(x) {
    stopifnot(peak >= lower,
              upper >= peak,
              upper > lower
    )
    triangle::qtriangle(p = x, a = lower, b = upper, c = peak)
  }
}

#' @rdname distributions
#' @export
use_distribution <- function(distribution, smooth = TRUE) {
  distribution <- sort(distribution)
  
  define_distribution(
    function(x) {
      if (smooth) {
        noise <- stats::rnorm(
          n = length(x),
          mean = 0,
          sd = stats::density(distribution)$bw
        )
      } else {
        noise <- 0
      }
      
      stats::approxfun(
        x = seq(0, 1, length = length(distribution)),
        y = distribution)(x) + noise
    }
  )
}
