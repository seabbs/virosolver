#' @export
generate_viable_start_pars <- function(parTab,
                                       obs_dat,
                                       CREATE_POSTERIOR_FUNC,
                                       INCIDENCE_FUNC,
                                       PRIOR_FUNC,
                                       use_pos=FALSE,
                                       ...){
  f <- CREATE_POSTERIOR_FUNC(parTab, obs_dat,
                             INCIDENCE_FUNC=INCIDENCE_FUNC,
                             PRIOR_FUNC=PRIOR_FUNC,
                             use_pos=use_pos,
                             ...)
  startTab <- generate_start_tab(parTab)
  lik <- f(startTab$values)
  while(!is.finite(lik)){
    startTab <- generate_start_tab(startTab)
    lik <- f(startTab$values)
  }
  startTab
}
