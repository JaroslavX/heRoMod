#**************************************************************************
#* 
#* Original work Copyright (C) 2017  Jordan Amdahl
#* Modified work Copyright (C) 2017  Antoine Pierucci
#* Modified work Copyright (C) 2017  Matt Wiener
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


#' Check Cycle and Time Inputs
#' 
#' Performs checks on the cycle and time inputs to
#' [eval_surv()].
#' 
#' @param cycle The `model_time` or `state_time` for which
#'   to predict.
#' @param cycle_length The length of a Markov cycle in 
#'   absolute time units.
#'   
#' @keywords internal
#'   
check_cycle_inputs <- function(cycle, cycle_length) {
  
  stopifnot(
    #all(round(cycle, 0) == cycle),
    length(cycle) >= 1,
    !any(cycle < 0),
    length(unique(cycle_length)) == 1,
    !any(is.infinite(cycle_length)),
    !any(is.na(cycle))
  )
} 
check_time_inputs <- function(time) {
  
  stopifnot(
    length(time) >= 1,
    !any(time < 0),
    !any(is.infinite(time)),
    !any(is.na(time))
  )
}

#' Extract Evaluated Parameters
#' 
#' Extracts the covariate-adjusted parameters from a
#' [flexsurv::flexsurvreg()] object.
#' 
#' @param obj A [flexsurv::flexsurvreg()] object.
#' @param data An optional dataset of covariate values to
#'   generate parameters for. Defaults to the original data
#'   to which the model was fit.
#'   
#' @return A tidy data frame of curve parameters for each
#'   covariate level.
#'   
#' @keywords internal
#'   
extract_params <- function(obj, data = NULL) {
  
  # Use data from object if not given
  if (is.null(data)) {
    data <- obj$data$m %>%
      select(-1, - ncol(obj$data$m))
  } else {
    # Apply factor levels of original data
    for(i in colnames(data)) {
      if (is.character(data[[i]]) | is.factor(data[[i]])) {
        data[[i]] <- factor(data[[i]], levels = unique(levels(as.factor(obj$data$m[[i]]))))
      }
    }
  }
  
  # Grab parameter estimates
  coef_obj <- obj$coefficients
  n_coef <- length(coef_obj)
  
  if (obj$ncovs == 0) {
    # Null model, extract parameter estimates
    out_params <- obj$res %>%
      as.data.frame() %>%
      t() %>%
      as.data.frame() %>%
      head(1)
    rownames(out_params) <- NULL
    
  } else {
    # Get parameters of distribution
    par_names <- obj$dlist$pars
    names(par_names) <- par_names
    n_pars <- length(par_names)
    # Replicate matrix of coefficents, row = obs, col = param
    n_obs <- nrow(data)
    coef_mat <- coef_obj %>% 
      rep(n_obs) %>%
      matrix(ncol = n_coef, nrow = n_obs, byrow = TRUE)
    names(coef_mat) <- par_names
    # Preallocate a matrix to hold calculated parameters
    par_mat <- matrix(ncol = n_pars, nrow = n_obs)
    
    # Loop to compute covariate-adjusted parmaeters
    for (i in seq_len(n_pars)) {
      # Extract inverse transformation
      inv_trans <- obj$dlist$inv.transforms[[i]]
      # Subset coefficients relevant to parameter
      coef_selector <- c(i, obj$mx[[par_names[i]]] + n_pars)
      n_par_coefs <- length(coef_selector)
      par_coef_mat <- coef_mat[ , coef_selector]
      if (n_par_coefs > 1) {
        # Assemble model matrix
        form <- obj$all.formulae[[par_names[i]]] %>%
          formula.tools::rhs() %>%
          deparse %>%
          paste0("~", .) %>%
          as.formula
        mm <- stats::model.matrix(form, data = data)
        par_mat[ , i] <- (mm * par_coef_mat) %>%
          rowSums() %>%
          inv_trans()
      } else {
        
        par_mat[ , i] <- par_coef_mat %>% inv_trans()
      }
    }
    
    out_params <- par_mat  %>%
      as.data.frame()
    colnames(out_params) <- par_names
  }
  
  return(out_params)
}

#' Extract Product-Limit Table for a Stratum
#' 
#' Extracts the product-limit table from a survfit object 
#' for a given stratum. Only [survival::survfit()] and
#' unstratified [survival::survfit.coxph()] objects are
#' supported.
#' 
#' @param sf A survit object.
#' @param index The index number of the strata to extract.
#'   
#' @return A data frame of the product-limit table for the 
#'   given stratum.
#'   
#' @keywords internal
extract_stratum <- function(sf, index) {
  if(is.null(sf$strata)) {
    # If there is no stratification, get the full table
    selector <- seq_len(length(sf$time))
    values <- list()
  } else {
    
    # If there are strata, create a selector which selects only the rows
    # corresponding to the given index
    end_index <- sum(sf$strata[seq_len(index)])
    start_index <- 1 + end_index - sf$strata[index]
    selector <- seq(from = start_index, to = end_index)
    
    # Extract the variable names and values corresponding to the stratum
    split_strata <- strsplit(names(sf$strata[index]),"(=|, )")[[1]]
    len <- length(split_strata) / 2
    keys <- split_strata[seq_len(len) * 2 - 1]
    values <- split_strata[seq_len(len) * 2]
    names(values) <- keys
  }
  
  # Return the stratum's product-limit table
  arg_list <- as.list(values) %>% append(
    list(
      time = c(0, sf$time[selector]),
      n = sum(sf$n.censor[selector] +
                sf$n.event[selector]),
      nrisk = c(sum(sf$n.censor[selector] +
                      sf$n.event[selector]), sf$n.risk[selector]),
      ncensor = c(0, sf$n.censor[selector]),
      nevent = c(0, sf$n.event[selector]),
      surv = c(1, sf$surv[selector]),
      lower = c(1, sf$lower[selector]),
      upper = c(1, sf$upper[selector])
    )
  )
  
  return(do.call(tibble, arg_list))
}

#' Extract Product-Limit Tables
#' 
#' Extracts the product-limit table from a survfit object
#' for all strata. Only `survfit` and unstratified
#' `survfit.coxph` objects are supported.
#' 
#' @param sf A survit object.
#'   
#' @return A tidy data.frame of the product-limit tables for
#'   all strata.
#'   
#' @keywords internal
#'   
extract_strata <- function(sf) {
  if (is.null(sf$strata)) {
    extract_stratum(sf, 1)
  } else {
    plyr::ldply(
      seq_len(length(sf$strata)),
      function(i) extract_stratum(sf, i)
    )
  }
}

#' Calculate Probability of Event
#' 
#' Calculates the per-cycle event probabilities from a
#' vector of survival probabilities.
#' 
#' @param x A vector of conditional event probabilities.
#'   
#' @return The per-cycle event probabilities.
#'   
#' @keywords internal
calc_prob_from_surv <- function(x) {
  - diff(x) / x[-length(x)]
}

#' Calculate Probability of Survival
#' 
#' Calculates the probability of survival from a vector of
#' event probabilities
#' 
#' @param x A vector of per-cycle event probabilities.
#'   
#' @return The survival probabilities.
#'   
#' @keywords internal
#' 
calc_surv_from_prob <- function(x) {
  cumprod(x[1] - x[-1])
}

#' @inherit compute_surv
#' @name eval_surv
#' @keywords internal
eval_surv <- function(x, time, ...) {
  UseMethod("eval_surv")
}

#' @inherit compute_surv
#' @name eval_surv
#' @keywords internal
compute_surv_ <- function(x, time, 
                          cycle_length = 1, 
                          type = c("prob", "survival"), ...){
  type <- match.arg(type)
  
  time_ <- time
  
  check_cycle_inputs(time_, cycle_length)
  cycle_length <- cycle_length[1]
  
  ret <- eval_surv(x, cycle_length * time_, ...)
  if (type == "prob") {
    prev_cycle <- eval_surv(x, (cycle_length * time_) - cycle_length, ...)
    # Calculate per-cycle failure prob
    ret <- (prev_cycle - ret) / prev_cycle
  }
  ret
}

#' @inherit surv_prob
#' @name eval_surv
#' @keywords internal
surv_prob_ <- function(x, time, ...){
  check_time_inputs(time)
  eval_surv(x, time, ...)
}

#' Evaluate Survival Probabilities
#' 
#' Generate survival probabilities from a survival
#' distribution.
#' 
#' The results of `surv_prob()` are memoised for 
#' `options("heRomod.memotime")` (default: 1 hour) to 
#' increase resampling performance.
#' 
#' @param x A survival distribution object
#' @param time The times for which to predict.
#' @param ... arguments passed to methods.
#'   
#' @return Returns either the survival probalities or
#'   conditional probabilities of event for each cycle.
#' @export
surv_prob <- memoise::memoise(
  surv_prob_,
  ~ memoise::timeout(options()$heRomod.memotime)
)

#' @inherit event_prob
#' @name eval_surv
#' @keywords internal
event_prob_ <- function(x, start, end, ...){
  check_time_inputs(start)
  check_time_inputs(end)
  surv_start <- eval_surv(x, start, ...)
  surv_end <- eval_surv(x, end, ...)
  e_prob <- (surv_start - surv_end) / surv_start
  e_prob[surv_start == 0] <- 1
  e_prob
}

#' Evaluate Event Probabilities
#' 
#' Generate event probabilities from a survival
#' distribution.
#' 
#' The results of `event_prob()` are memoised for 
#' `options("heRomod.memotime")` (default: 1 hour) to 
#' increase resampling performance.
#' 
#' @param x A survival distribution object
#' @param start The start time of the interval.
#' @param start The end time of the interval.
#' @param ... arguments passed to methods.
#'   
#' @return Returns either the survival probalities or
#'   conditional probabilities of event for each cycle.
#' @export
event_prob <- memoise::memoise(
  event_prob_,
  ~ memoise::timeout(options()$heRomod.memotime)
)

#' Evaluate Survival Distributions
#' 
#' Generate either survival probabilities or conditional
#' probabilities of event for each model cycle.
#' 
#' The results of `compute_surv()` are memoised for 
#' `options("heRomod.memotime")` (default: 1 hour) to 
#' increase resampling performance.
#' 
#' @param x A survival distribution object
#' @param time The `model_time` or `state_time` for which
#'   to predict.
#' @param cycle_length The value of a Markov cycle in 
#'   absolute time units.
#' @param type Either `prob`, for transition probabilities,
#'   or `surv`, for survival.
#' @param ... arguments passed to methods.
#'   
#' @return Returns either the survival probalities or
#'   conditional probabilities of event for each cycle.
#' @export
compute_surv <- memoise::memoise(
  compute_surv_,
  ~ memoise::timeout(options()$heRomod.memotime)
)

#' @rdname eval_surv
#' @export
eval_surv.default <- function(x, time,  ...) {
  the_class <- class(x)
  class_statement <- switch(
    the_class[1],
    "numeric" = "a number",
    "character" = "a string",
    "data.frame" = "a table",
    "tbl_df" = "a table",
    paste0("an object of class '", the_class, "'")
  )
  msg <- paste0(
    'Function expected a survival distribution but instead was passed ',
    class_statement,
    '.'
  )
  stop(msg, call. = F)
}

#' @rdname eval_surv
#' @export
eval_surv.survfit <- function(x, time,  ...) {
  
  dots <- list(...)
  
  pl_table <- extract_strata(x)
  
  # Identify the terms which separate groups (if any)
  terms <- setdiff(
    colnames(pl_table),
    c("time", "n", "nrisk", "ncensor",
      "nevent", "surv", "lower", "upper")
  )
  
  # Generate predicted survival for each group
  surv_df <- plyr::ddply(
    pl_table,
    terms,
    function(d) {
      maxtime <- max(d$time)
      selector <- (time > maxtime)
      # Use stepfun to look up survival probabilities
      value <- stats::stepfun(d$time[-1], d$surv)(time)
      # Use NA when time > max time
      value[selector] <- as.numeric(NA)
      tibble(
        t = time, 
        value = value,
        n = d$n[1])
    }
  )
  
  if (is.null(dots$covar)) {
    if (length(terms) > 0) {
      message("No covariates provided, returning aggregate survial across all subjects.")
    }
    # If covariates are not provided, do weighted average for each time.
    agg_df <- surv_df %>%
      tibble::as_tibble() %>% 
      group_by(t) %>%
      summarize(value = sum(value * n) / sum(n))
  } else {
    
    # If covariates are provided, join the predictions to them and then
    # do simple average for each time.
    
    agg_df <- clean_factors(dots$covar) %>% 
      left_join(surv_df, by = terms) %>%
      group_by(t) %>%
      summarize(value = mean(value))
  }
  
  # Get the vector of predictions
  ret <- agg_df$value
  return(ret)
}

#' @rdname eval_surv
#' @export
eval_surv.flexsurvreg <- function(x, time,  ...) {
  
  dots <- list(...)
  
  time_surv <- time
  # Extract parameter estimates
  coef_obj <- x$coefficients
  
  n_coef <- length(coef_obj)
  n_time <- length(time_surv)
  
  if(x$ncovs > 0 && is.null(dots$covar)) {
    message("No covariates provided, returning aggregate survial across all subjects.")
  }
  
  # For efficiency, survival probabilities are only calculated
  # for each distinct set of covariates, then merged back onto
  # the full dataset (data_full).
  if (is.null(dots$covar)) {
    # if covar is not provided, use the
    # original model.frame
    data_full <- x$data$m %>%
      select(-1, -ncol(x$data$m))
    data <- distinct(data_full)
  } else {
    # Use covar if provided
    data_full <- dots$covar
    data <- distinct(dots$covar)
  }
  
  # If there is no data, make an empty df
  if (ncol(data) == 0) {
    data <- data.frame(value = numeric(n_time))
  }
  
  # Get a data frame of parameter values for each observation
  param_df <- extract_params(x, data = data)
  n_obs <- nrow(param_df)
  
  # Repeat rows of parameter df to match number of time points
  param_df <- param_df %>%
    slice(rep(seq_len(n_obs), each = n_time))
  
  # Assumble arguments to p<dist> function
  fncall <- list(rep(time_surv, n_obs), lower.tail = FALSE) %>%
    append(x$aux) %>%
    append(param_df)
  
  # Calculate survival probabilities for each distinct level/time,
  surv_df <- data %>%
    slice(rep(seq_len(n_obs), each = n_time))
  surv_df$t <- rep(time_surv, n_obs)
  surv_df$value <- do.call(x$dfns$p, fncall)
  
  # Join to the full data, then summarize over times.
  if(x$ncovs > 0) {
    surv_df <- surv_df %>%
      left_join(data_full, by = colnames(data)) %>%
      group_by(t) %>%
      summarize(value = mean(value))
  }
  
  
  # Just get the results column
  ret <- surv_df$value
  
  return(ret)
}

#' @rdname eval_surv
#' @export
eval_surv.surv_model <- function(x, time,  ...) {
  eval_surv(
    x$dist,
    time = time,
    covar = x$covar,
    ...
  )
  
}

#' @rdname eval_surv
#' @export
eval_surv.surv_projection <- function(x, time, ...) {
  ret <- numeric(length(time))
  
  surv1 <- eval_surv(
    x$dist1,
    time = time,
    ...
  )
  surv2 <- eval_surv(
    x$dist2,
    time = time,
    ...
  )
  
  ind_s1 <- time < x$at
  ind_s2 <- time >= x$at
  
  surv1_p_at <- eval_surv(
    x$dist1,
    time = x$at,
    ...
  )
  surv2_p_at <- eval_surv(
    x$dist2,
    time = x$at,
    ...,
    .internal = TRUE)
  
  ret[ind_s1] <- surv1[ind_s1]
  if (surv2_p_at == 0) {
    ret[ind_s2] <- 0
  } else {
    ret[ind_s2] <- (surv2 * surv1_p_at / surv2_p_at)[ind_s2]
  }
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_pooled <- function(x, time, ...) {
  
  # Determine dimensions of matrix and initialize
  n_cycle <- length(time)
  n_dist <- length(x$dists)
  surv_mat <- matrix(nrow = n_cycle, ncol = n_dist)
  
  # Evaluate and weight component distributions into columns
  # of matrix
  for (i in seq_len(n_dist)) {
    surv_mat[ ,i] <- x$weights[i] / sum(x$weights) *
      eval_surv(
        x$dists[[i]],
        time = time,
        type = "surv",
        ...
      )
  }
  
  # Calculate weighted average as the row sums
  ret <- rowSums(surv_mat)
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_ph <- function(x, time, ...) {
  
  ret <- eval_surv(
    x$dist,
    time = time,
    ...
  ) ^ x$hr
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_shift <- function(x, time, ...) {
  
  time_ <- time
  time_ <- time_ - x$shift
  ret <- rep(1, length(time_))
  keep_me <- time_ >= 0
  if(any(keep_me)){
    time_ <- time_[keep_me]
    ##check_cycle_inputs(time_, cycle_length)
    ret[keep_me] <- eval_surv(
      x$dist,
      time = time_,
      ...
    ) 
  }
  
  ret
}


#' @rdname eval_surv
#' @export
eval_surv.surv_aft <- function(x, time, ...) {
  
  ret <- eval_surv(
    x$dist,
    time = time / x$af 
  )
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_po <- function(x, time, ...) {
  
  dots <- list(...)
  
  p <- eval_surv(
    x$dist,
    time = time,
    ...
  )
  
  ret <- 1 / ((((1 - p) / p) * x$or) + 1)
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_add_haz <- function(x, time, ...) {
  
  # Determine dimensions of matrix and initialize
  n_cycle <- length(time)
  n_dist <- length(x$dists)
  surv_mat <- matrix(nrow = n_cycle, ncol = n_dist)
  
  # Evaluate and weight component distributions into columns
  # of matrix
  for (i in seq_len(n_dist)) {
    surv_mat[ ,i] <- eval_surv(
      x$dists[[i]],
      time = time,
      ...
    )
  }
  
  # Apply independent risks
  ret <- apply(surv_mat, 1, function(z) prod(z))
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_dist <- function(x, time, ...) {
  if (! requireNamespace("flexsurv")) {
    stop("'flexsurv' package required.")
  }
  
  pf <- get(paste0("p", x$distribution),
            envir = asNamespace("flexsurv"))
  
  args <- x[- match("distribution", names(x))]
  args <- lapply(args, function(x) x[1])
  args[["q"]] <- time
  args[["lower.tail"]] <- FALSE
  ret <- do.call(pf, args)
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_dist_cure <- function(x, time, ...) {
  if (! requireNamespace("flexsurv")) {
    stop("'flexsurv' package required.")
  }
  if (! requireNamespace("flexsurvcure")) {
    stop("'flexsurvcure' package required.")
  }
  
  pf <- get(paste0("p", x$distribution),
            envir = asNamespace("flexsurv"))
  if (x$mixture) {
    cure_f <- flexsurvcure::pmixsurv
  } else {
    cure_f <- flexsurvcure::pnmixsurv
  }
  
  args <- x[- match(c("distribution", "mixture"), names(x))]
  args <- lapply(args, function(x) x[1])
  args[["pfun"]] <- pf
  args[["q"]] <- time
  args[["lower.tail"]] <- FALSE
  ret <- do.call(cure_f, args)
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_dist_spline <- function(x, time, ...) {
  if (! requireNamespace("flexsurv")) {
    stop("'flexsurv' package required.")
  }
  
  pf <- get(paste0("p", x$distribution),
            envir = asNamespace("flexsurv"))
  
  
  n_param <- (length(x) - 2)
  pf <- flexsurv::unroll.function(
    pf,
    gamma = seq_len(n_param/2),
    knots = seq_len(n_param/2)
  )
  
  args <- x[- match("distribution", names(x))]
  args <- lapply(args, function(x) x[1])
  args[["q"]] <- time
  args[["lower.tail"]] <- FALSE
  ret <- do.call(pf, args)
  
  ret
}

#' @rdname eval_surv
#' @export
eval_surv.surv_table <- function(x, time, ...){
  look_up(data = x, time = time, bin = "time", value = "survival")
}



#' @rdname eval_surv
#' @export
eval_surv.surv_lifetable <- function(x, time, ...){
  attr(x, "surv_func")(time)
}

eval_surv.lazy <- function(x, ...){
  dots <- list(...)
  use_data <- list()
  if("extra_env" %in% names(dots))
    use_data <- as.list.environment(dots$extra_env)
  eval_surv(lazyeval::lazy_eval(x, data = use_data), ...)
}
