#**************************************************************************
#* 
#* Original work Copyright (C) 2016  Antoine Pierucci
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


#' Define a Sensitivity Analysis
#' 
#' Define parameter variations for a Markov model 
#' sensitivity analysis.
#' 
#' @param ... A list of parameter names and min/max values 
#'   of the form \code{var1, min(var1), max(var1), var2,
#'   min(var2), max(var2), ...}.
#' @param par_names String vector of parameter names.
#' @param low_dots,high_dots Used to work around
#'   non-standard evaluation.
#'   
#' @return A `sensitivity` object.
#' @export
#' 
#' @examples
#' 
#' define_dsa(
#'   a, 10, 45,
#'   b, .5, 1.5
#' )
#' 
define_dsa <- function(...) {
  .dots <- lazyeval::lazy_dots(...)
  
  if (! length(.dots) %% 3 == 0) {
    stop("Incorrect number of elements in sensitivity definition, the correct form is A, min(A), max(A)...")
  }
  
  par_names <- character()
  low_dots <- lazyeval::lazy_dots()
  high_dots <- lazyeval::lazy_dots()
  
  for (i in seq_along(.dots)) {
    if (i %% 3 == 1) {
      par_names <- c(par_names, deparse(.dots[[i]]$expr))
    } else if (i %% 3 == 2) {
      low_dots <- c(low_dots, list(.dots[[i]]))
    } else {
      high_dots <- c(high_dots, list(.dots[[i]]))
    }
  }
  
  names(low_dots) <- par_names
  names(high_dots) <- par_names
  
  define_dsa_(par_names = par_names,
              low_dots = low_dots, high_dots = high_dots)
}

#' @rdname define_dsa
define_dsa_ <- function(par_names, low_dots, high_dots) {
  
  check_names(par_names)
  
  stopifnot(
    all(par_names == names(low_dots)),
    all(par_names == names(high_dots))
  )
  dots <- interleave(low_dots, high_dots)
  
  if (any(duplicated(par_names))) {
    stop("Some names are duplicated.")
  }
  
  tab <- tibble::tibble()
  for (i in seq_along(dots)) {
    suppressWarnings({ # tofix https://github.com/tidyverse/dplyr/issues/2688
      tab <- bind_rows(
        tab,
        stats::setNames(tibble::tibble(a = list(dots[[i]])), names(dots)[i])
      )
    })
  }
  
  clean_null <- function(x) {
    Map(
      function(el) if (is.null(el)) NA else el,
      x
    )
  }
  
  structure(
    list(
      dsa = tab %>% 
        mutate_all(list(clean_null)),
      variables = par_names,
      low_dots = low_dots,
      high_dots = high_dots
    ),
    class = c("sensitivity", class(tab))
  )
}

#' @export
print.sensitivity <- function(x, ...) {
  tab <- cbind(to_text_dots(x$low_dots, name = FALSE),
               to_text_dots(x$high_dots, name = FALSE))
  
  rownames(tab) <- x$variables
  colnames(tab) <- c("Low", "High")
  
  print(
    tab,
    na.print = "-",
    quote = FALSE
  )
}
