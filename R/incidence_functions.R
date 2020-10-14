#' @export
solveSEIRModel_rlsoda_wrapper <- function(pars, times){
  seir_pars <- c(pars["R0"]*(1/pars["infectious"]),1/pars["incubation"],1/pars["infectious"])
  init <- c(1-pars["I0"],0,pars["I0"],0,0)
  inc <- c(rep(0, pars["t0"]),0,diff(rlsoda::rlsoda(init, times, C_SEIR_model_rlsoda, parms=seir_pars, dllname="virosolver",
                 deSolve_compatible = FALSE,return_time=TRUE,return_initial=TRUE,atol=1e-6,rtol=1e-6)[6,]))[1:length(times)]
  inc <- pmax(0, inc)
  inc
}

#' @export
solveSEEIRRModel_rlsoda_wrapper <- function(pars, times){
  seir_pars <- c(pars["R0"]*(1/pars["infectious"]),1/pars["latent"],1/pars["incubation"],1/pars["infectious"],1/pars["recovery"])
  init <- c(1-pars["I0"],0,0,pars["I0"],0,0,0)
  inc <- c(rep(0, pars["t0"]),0,diff(rlsoda::rlsoda(init, times, C_SEEIRR_model_rlsoda, parms=seir_pars, dllname="virosolver",
                                                    deSolve_compatible = FALSE,return_time=TRUE,return_initial=TRUE,atol=1e-6,rtol=1e-6)[8,]))[1:length(times)]
  inc <- pmax(0, inc)
  inc
}

#' @export
detectable_SEEIRRModel <- function(pars, times){
  seir_pars <- c(pars["R0"]*(1/pars["infectious"]),1/pars["latent"],1/pars["incubation"],1/pars["infectious"],1/pars["recovery"])
  init <- c(1-pars["I0"],0,0,pars["I0"],0,0,0)
  y <- rlsoda::rlsoda(init, times, C_SEEIRR_model_rlsoda, parms=seir_pars, dllname="virosolver",
                      deSolve_compatible = FALSE,return_time=TRUE,return_initial=TRUE,atol=1e-6,rtol=1e-6)
  detectable_prev <- colSums(y[c(4,5,6),])
  detectable_prev <- c(rep(0, pars["t0"]),detectable_prev)
  pmax(0, detectable_prev)
}


#' @export
exponential_growth_model <- function(pars, times){
  overall_prob <- pars["overall_prob"]
  beta <- pars["beta"]

  y <- exp(beta*times)
  scale <- sum(y)/overall_prob
  prob_infection_tmp <- y/scale
  prob_infection_tmp
}

#' @export
gaussian_process_model <- function(pars, times){
  #browser()
  par_names <- names(pars)
  use_names <- c("prob",paste0("prob.",1:length(times)))
  overall_prob <- pars["overall_prob"]
  k <- pars[which(par_names%in%use_names)]

  mat <- matrix(rep(times, each=length(times)),ncol=length(times))
  t_dist <- abs(apply(mat, 2, function(x) x-times))

  mus <- rep(0, length(times))

  nu <- pars["nu"]
  rho <- pars["rho"]
  K <- nu^2 * exp(-rho^2 * t_dist^2)
  diag(K) <- diag(K) + 0.01
  L_K <- chol(K)
  k1 <- (L_K %*% k)[,1]

  ps <- 1/(1+exp(-k1))
  ps <- ps/sum(ps)
  prob_infection_tmp <- ps*overall_prob
  prob_infection_tmp
}


#' @export
solveSEIRModel_rlsoda <- function(ts, init, pars,compatible=FALSE){
  pars <- pars[c("beta","sigma","gamma")]
  rlsoda::rlsoda(init, ts, C_SEIR_model_rlsoda, parms=pars, dllname="virosolver",
                 deSolve_compatible = compatible,return_time=TRUE,return_initial=TRUE,atol=1e-6,rtol=1e-6)
}
#' @export
solveSEEIRRModel_rlsoda <- function(ts, init, pars,compatible=FALSE){
  pars <- pars[c("beta","sigma","alpha","gamma","omega")]
  rlsoda::rlsoda(init, ts, C_SEEIRR_model_rlsoda, parms=pars, dllname="virosolver",
                 deSolve_compatible = compatible,return_time=TRUE,return_initial=TRUE,atol=1e-6,rtol=1e-6)
}