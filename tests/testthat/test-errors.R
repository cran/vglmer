context("Test vglmer robustness to certain situations")

if (isTRUE(as.logical(Sys.getenv("CI")))){
  # If on CI
  NITER <- 2
  env_test <- "CI"
}else if (!identical(Sys.getenv("NOT_CRAN"), "true")){
  # If on CRAN
  NITER <- 2
  env_test <- "CRAN"
  set.seed(131)
}else{
  # If on local machine
  NITER <- 2000
  env_test <- 'local'
}

test_that("vglmer can run with objects in environment", {
  N <- 100
  G <- 5
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)

  y <- rbinom(n = N, size = 1, prob = plogis(-1 + x + alpha[match(g, G_names)]))

  test_nodata <- tryCatch(suppressMessages(vglmer(y ~ x + (1 | g),
    data = NULL,
    control = vglmer_control(
      init = "zero",
      iterations = 1, print_prog = 10
    ),
    family = "binomial"
  )),
  error = function(e) {
    NULL
  }
  )
  expect_false(is.null(test_nodata))

  dta <- data.frame(Y = y, X = x, G = g)
  # Inject missingness into
  dta$Y[38] <- NA
  dta$X[39] <- NA
  dta$G[84] <- NA
  dta[3, ] <- NA
  test_missing <- tryCatch(suppressMessages(vglmer(Y ~ X + (1 | G),
    data = dta,
    control = vglmer_control(
      init = "zero", return_data = T,
      iterations = 1, print_prog = 10
    ),
    family = "binomial"
  )),
  error = function(e) {
    NULL
  }
  )
  # Confirm runs
  expect_false(is.null(test_missing))
  # Confirms deletion "works"
  expect_equivalent(dta$X[-c(3, 38, 39, 84)], test_missing$data$X[, 2])
  expect_equivalent(dta$Y[-c(3, 38, 39, 84)], test_missing$data$y)
})

test_that('vglmer runs with timing and "quiet=F"', {
  N <- 25
  G <- 2
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)

  y <- rbinom(n = N, size = 1, prob = plogis(-1 + x + alpha[match(g, G_names)]))
  
  if (all(y == 0)){
    y[1] <- 1
  }
  if (all(y == 1)){
    y[1] <- 0
  }
  
  est_simple <- suppressMessages(vglmer(y ~ x + (1 | g),
    data = NULL,
    control = vglmer_control(do_timing = T, quiet = F, iteration = 5),
    family = "binomial"
  ))
  expect_true(inherits(est_simple$timing, "data.frame"))
  expect_gte(min(diff(est_simple$ELBO_trajectory$ELBO)), 0)
})

test_that('vglmer parses environment correctly', {
  rm(list=ls())  
  N <- 25
  G <- 2
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  
  dta <- data.frame(x = rnorm(N), g = sample(G_names, N, replace = T))
  alpha <- rnorm(G)
  
  dta$y <- rbinom(n = N, size = 1, prob = plogis(-1 + dta$x + alpha[match(dta$g, G_names)]))
  dta$size <- rpois(n = N, lambda = 2) + 1
  dta$y_b <- rbinom(n = N, size = dta$size, prob = plogis(-1 + dta$x + alpha[match(dta$g, G_names)]))
  #runs with clean environment
  est_simple <- suppressMessages(vglmer(y ~ x + (1 | g), data = dta, 
    control = vglmer_control(iterations = 5),
    family = 'binomial'))
  expect_true(inherits(est_simple, 'vglmer'))
  
  est_simple <- suppressMessages(vglmer(cbind(y_b, size) ~ x + (1 | g), 
    control = vglmer_control(iterations = 5),                                        
    data = dta, family = 'binomial'))
  expect_true(inherits(est_simple, 'vglmer'))
})

test_that("vglmer can run with 'debug' settings", {
  N <- 20
  G <- 5
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)
  
  y <- rbinom(n = N, size = 1, prob = plogis(-1 + x + alpha[match(g, G_names)]))
  
  # Avoid perfect separation
  if (all(y == 0)){
    y[1] <- 1
  }
  if (all(y == 1)){
    y[1] <- 0
  }
  
  # Debug to collect parameters
  est_vglmer <- vglmer(y ~ x + (1 | g), data = data.frame(y = y, x = x, g = g),
         family = 'binomial',
         control = vglmer_control(debug_param = TRUE, iterations = 5))  
  
  expect_true(all(c('beta', 'alpha') %in% names(est_vglmer$parameter_trajectory)))

  est_vglmer <- vglmer(y ~ x + (1 | g), 
      data = data.frame(y = y, x = x, g = g),
      family = 'binomial',
      control = vglmer_control(debug_ELBO = TRUE))
  expect_true(!is.null(est_vglmer$ELBO_trajectory$step))
  
})

test_that("vglmer can run with exactly balanced classes", {
  N <- 50
  G <- 5
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)
  
  y <- c(rep(0, N/2), rep(1, N/2))
  
  # Debug to collect parameters
  est_vglmer <- vglmer(y ~ x + (1 | g), data = data.frame(y = y, x = x, g = g),
      family = 'binomial',
      control = vglmer_control(iterations = 1))  
  
  expect_s3_class(est_vglmer, 'vglmer')
})

test_that("Run without FE for corresponding random slope", {

  N <- 25
  G <- 2
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)
  
  y <- rbinom(n = N, size = 1, prob = plogis(-1 + x + alpha[match(g, G_names)]))
  
  fit_noFE_for_RE <- vglmer(
    formula = y ~ 1 + (1 + x | g),
    family = 'linear', control = vglmer_control(iterations = 4),
    data = NULL)
  expect_s3_class(fit_noFE_for_RE, 'vglmer')
  
})

test_that("predict works with N=1", {
  
  N <- 25
  G <- 2
  G_names <- paste(sample(letters, G, replace = T), 1:G)
  x <- rnorm(N)
  g <- sample(G_names, N, replace = T)
  alpha <- rnorm(G)
  
  y <- rbinom(n = N, size = 1, prob = plogis(-1 + x + alpha[match(g, G_names)]))
  
  est_simple <- suppressMessages(vglmer(y ~ x + (1 | g),
      data = NULL,
      control = vglmer_control(iterations = 1),
      family = "linear"
  ))
  pred_single <- predict(est_simple, newdata = data.frame(x = x[1], g = 'NEW'), 
     allow_missing_levels = TRUE)
  term_single <- predict(est_simple, newdata = data.frame(x = x[1], g = 'NEW'),
     type = 'terms', allow_missing_levels = TRUE)
  expect_equal(pred_single, sum(coef(est_simple) * c(1, x[1])))
  expect_equivalent(c(pred_single, 0), term_single)
  
  est_spline <- suppressMessages(vglmer(y ~ v_s(x) + (1 | g),
      data = NULL,
      control = vglmer_control(iterations = 1),
      family = "linear"
  ))
  pred_spline <- predict(est_spline, 
    newdata = data.frame(x = x[1], g = 'NEW'), 
    allow_missing_levels = TRUE)
  term_spline <- predict(est_spline, type = 'terms',
    newdata = data.frame(x = x[1], g = 'NEW'), 
    allow_missing_levels = TRUE)
  expect_equal(pred_spline, rowSums(term_spline))
  expect_equivalent(term_spline[, 'FE'], sum(c(1, x[1]) * coef(est_spline)))
  
})
