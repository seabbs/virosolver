#' @export
plot_prob_infection <- function(chain,
                                nsamps,
                                INCIDENCE_FUNC,
                                solve_times,
                                obs_dat=NULL,
                                true_prob_infection=NULL,
                                tshift=0){
  samps <- sample(unique(chain$sampno),nsamps)
  all_res <- NULL
  for(i in seq_along(samps)){
    samp <- samps[i]
    tmp_pars <- lazymcmc::get_index_pars(chain, samp)
    prob_infection_tmp <- INCIDENCE_FUNC(tmp_pars, solve_times)
    all_res[[i]] <- tibble(t=solve_times+tshift,prob_infection=prob_infection_tmp,sampno=i)
  }
  posterior_dat <- do.call("bind_rows",all_res)
  best_pars <- get_best_pars(chain)
  best_prob_infection <- INCIDENCE_FUNC(best_pars, solve_times)
  best_prob_dat <- tibble(t=solve_times+tshift,prob_infection=best_prob_infection,sampno="MAP")

  p1 <- ggplot(posterior_dat) +
    geom_line(aes(x=t,y=prob_infection,group=sampno,col="Posterior draw"),size=0.1) +
    geom_line(data=best_prob_dat,aes(x=t,y=prob_infection,col="MAP"),size=0.5) +
    scale_y_continuous(expand=c(0,0))+
    xlab("Time") +
    ylab("Probability of infection") +
    theme_classic()

  if(!is.null(true_prob_infection)){
    p1 <- p1 +
      geom_line(data=true_prob_infection,aes(x=t,y=prob_infection,col="Ground truth"),
                linetype="dashed",size=0.5)
  }

  if(!is.null(obs_dat)){
    p1 <- p1 +
      geom_vline(data=data.frame(x=unique(obs_dat$t)),
                 aes(xintercept=x,linetype="Sample date"),
                 col="red",size=0.25)
  }
  p1 <- p1 +
    scale_color_manual(values=c("Posterior draw"="gray50","MAP"="green","Ground truth"="blue")) +
    scale_linetype_manual(values=c("Sample date"="dashed")) +
    guides(col=guide_legend(title=NULL),linetype=guide_legend(title=NULL)) +
    theme(legend.position="bottom")
  return(list(predictions=posterior_dat, map_prediction=best_prob_dat,plot=p1))
}

#' @export
predicted_distribution_fits <- function(chain, obs_dat,MODEL_FUNC, nsamps=100){
  best_pars <- get_best_pars(chain)
  best_dat <- MODEL_FUNC(best_pars)

  ## Generate posterior draws for Ct distribution prediction
  samps <- sample(unique(chain$sampno),nsamps)
  all_res <- NULL
  for(i in seq_along(samps)){
    samp <- samps[i]
    tmp_pars <- lazymcmc::get_index_pars(chain, samp)
    all_res[[i]] <- MODEL_FUNC(tmp_pars) %>% mutate(sampno=i)
  }
  posterior_dat <- do.call("bind_rows",all_res)
  posterior_dat
}

#' @export
plot_distribution_fits <- function(chain, obs_dat,MODEL_FUNC, nsamps=100,pos_only=TRUE){

  best_pars <- get_best_pars(chain)
  best_dat <- MODEL_FUNC(best_pars)

  ## Generate posterior draws for Ct distribution prediction
  samps <- sample(unique(chain$sampno),nsamps)
  all_res <- NULL
  for(i in seq_along(samps)){
    samp <- samps[i]
    tmp_pars <- lazymcmc::get_index_pars(chain, samp)
    all_res[[i]] <- MODEL_FUNC(tmp_pars) %>% mutate(sampno=i)
  }
  posterior_dat <- do.call("bind_rows",all_res)

  ## Make sure only plotting detectable, and get label
  obs_dat1 <- obs_dat %>%
    filter(ct < best_pars["intercept"]) %>%
    mutate(obs_t=paste0("Sample day: ", t))

  ## Get number of observations per time point
  obs_tally <- obs_dat1 %>% group_by(t) %>% tally()

  ## Re-scale densities to only detectable Ct distribution densities
  total_density <- posterior_dat %>%
    filter(ct < best_pars["intercept"]) %>%
    group_by(t,sampno) %>%
    summarize(total_dens=sum(density)) %>%
    left_join(obs_tally)

  ## Get expected number of observations for each Ct,
  ## also simulate observations
  summary_posterior_dat <- posterior_dat %>%
    filter(ct < best_pars["intercept"]) %>%
    left_join(total_density) %>%
    group_by(t, sampno) %>%
    mutate(density=density/total_dens) %>%
    ungroup() %>%
    mutate(expectation=density*n) %>%
    ungroup() %>%
    mutate(sim_obs=rbinom(n(),n,density)) %>%
    group_by(ct, t)

  summary_expectation <- summary_posterior_dat %>%
    group_by(ct, t) %>%
    ## Quantiles on expectations
    summarize(lower_expec=quantile(expectation,0.025),
              median_expec=quantile(expectation,0.5),
              upper_expec=quantile(expectation,0.975))

  ## Quantiles on observations
  summary_obs <- summary_posterior_dat %>%
    group_by(ct, t) %>%
    summarize(lower_obs=quantile(sim_obs,0.025),
              median_obs=quantile(sim_obs,0.5),
              upper_obs=quantile(sim_obs,0.975))


  p1 <- ggplot(obs_dat1) +
    geom_histogram(aes(x=ct,y=..count..),binwidth=1,fill="grey70",col="grey20",boundary=0) +
    geom_ribbon(data=summary_obs,aes(x=ct+0.5,ymin=lower_obs,ymax=upper_obs),fill="blue",alpha=0.25)+
    geom_ribbon(data=summary_expectation,aes(x=ct+0.5,ymin=lower_expec,ymax=upper_expec),fill="blue",alpha=0.5)+
    geom_line(data=summary_expectation,aes(x=ct+0.5,y=median_expec),col="blue") +
    #geom_line(data=best_dat%>%group_by(t) %>%filter(ct < best_pars["intercept"]), aes(x=ct+0.5,y=density),col="green") +
    scale_x_continuous(trans="reverse",expand=c(0,0),limits=c(41,5),breaks=seq(0,40,by=5)) +
    #scale_y_continuous(expand=c(0,0),limits=c(0,10),breaks=seq(0,10,by=2)) +
    coord_cartesian(xlim=c(0,39)) +
    coord_flip() +
    xlab("Ct value") +
    ylab("Count") +
    facet_wrap(~t,nrow=1,scales="free_x") +
    theme_classic() +
    theme(panel.grid.major = element_line(color="grey80",size=0.25),
          panel.grid.minor = element_line(color="grey80",size=0.25),
          panel.spacing = unit(0.5, "lines")) +
    ggtitle("Fit to detectable Ct distribution")

  ## Get predictions for prob undetectable
  summary_prop_detectable <- posterior_dat %>% filter(ct == best_pars["intercept"]) %>%
    group_by(t) %>%
    mutate(density=1-density) %>%
    summarize(lower=quantile(density,0.025),
              median=quantile(density,0.5),
              upper=quantile(density,0.975))

  p2 <-  ggplot(obs_dat %>%
                  group_by(t) %>%
                  mutate(is_detectable=ct < best_pars["intercept"]) %>%
                  summarize(prop_detectable=sum(is_detectable)/n()))
  if(!pos_only){
  p2 <- p2 +
    geom_point(aes(y=prop_detectable,x=0.25,col="Data"),size=3,shape=18)
  }
  p2 <- p2 +
    geom_point(data=summary_prop_detectable,aes(x=0.75,y=median,col="Posterior median & 95% CI"),size=1) +
    geom_errorbar(data=summary_prop_detectable,aes(x=0.75,ymin=lower,ymax=upper),
                  width=0.1, col="blue") +
    #geom_point(data=best_dat %>%filter(ct==best_pars["intercept"]) %>%mutate(density = 1-density),aes(x=0.5,y=density,col="MAP"),size=1) +
    scale_y_continuous(limits=c(0,1)) +
    scale_x_continuous(limits=c(0,1)) +
    scale_color_manual(values=c("Data"="grey40",
                                "Posterior median & 95% CI"="blue",
                                "MAP"="green")) +
    guides(color=guide_legend(title=NULL)) +
    facet_wrap(~t,nrow=1) +
    ylab("Proportion detectable") +
    xlab("Sample time") +
    theme_classic() +
    theme(panel.grid.major = element_line(color="grey80",size=0.25),
          panel.grid.minor = element_line(color="grey80",size=0.25),
          panel.grid.minor.x = element_blank(),
          panel.grid.major.x = element_blank(),
          panel.spacing = unit(0.5, "lines"),
          axis.text.x=element_blank(),
          legend.position="none",
          axis.ticks.x=element_blank()) +
    ggtitle("Fit to proportion detectable")
    p1  /p2
}
#' @export
plot_posterior_density <- function(chain, var_name, parTab, prior_mean, prior_sd, real_data=FALSE){
  p <- ggplot(chain) +
    geom_density(aes_string(var_name),fill="red",alpha=0.25) +
    stat_function(data=data.frame(x=c(parTab[parTab$names == var_name,"lower_bound"],
                                      parTab[parTab$names == var_name,"upper_bound"])),
                  aes(x),col="blue",
                  fun = dnorm, n = 101, args = list(mean = prior_mean, sd = prior_sd)) +
    scale_y_continuous(expand=c(0,0)) +
    ylab("Density") +
    theme_classic()
  if(!real_data){
   p <- p +
     geom_vline(xintercept=parTab[parTab$names == var_name,"values"], linetype="dashed")
  }
  p
}

