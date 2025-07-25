# install.packages("doBy")
# install.packages("astsa")
# install.packages("ggplot2")
# install.packages("sweep")
# install.packages("forecast")
# install.packages("timetk")
# install.packages("recipes")
# install.packages("fs")
# install.packages("here")
# install.packages("svglite")
# install.packages("gridExtra")
# install.packages("stringr")

library(dplyr)
library(ggplot2)
library(fs)
library(zoo)
library(svglite)
library(here)

library(doBy)
library(astsa)
library(sweep)
library(forecast)
library(timetk)

library(gridExtra)
library(stringr)

sessionInfo()

#For running locally
#setwd("C:/Users/k1754142/OneDrive/PhD Project/OpenSAFELY NEIAA/inflammatory_rheum/")
#setwd("C:/Users/Mark/OneDrive/PhD Project/OpenSAFELY NEIAA/inflammatory_rheum/")

## Create directories if needed
dir_create(here::here("output/figures"), showWarnings = FALSE, recurse = TRUE)
dir_create(here::here("output/tables"), showWarnings = FALSE, recurse = TRUE)

sink("logs/sarima_log.txt")

# Incidence data
df <-read.csv("output/tables/incidence_rates_rounded.csv")

#Rename variables in the datafile (hashed line only needed if running locally)
names(df)[names(df) == "numerator"] <- "count"
df<- df %>% select(disease, year, mo_year_diagn, incidence, count) 
df$month <- substr(df$mo_year_diagn, 1, 3)
df$mo_year_diagn <- gsub("-", " ", df$mo_year_diagn)
#df$mo_year_diagn <- sub("(\\d{2})$", "20\\1", df$mo_year_diagn)
df$mon_year <- df$mo_year_diagn
df$mo_year_diagn <- as.Date(paste0("01 ", df$mo_year_diagn), format = "%d %b %Y")
month_lab <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")

disease_list <- unique(df$disease)

# Define the variables to loop over
#variables <- c("incidence", "count")
#y_labels <- c("Incidence per 100,000 population", "Number of diagnoses per month")
variables <- c("incidence")

# Initialize index for axis labelling
index_axis <- 1

# Loop through diseases
for (j in 1:length(disease_list)) {
  
  dis <- disease_list[j]
  df_dis <- df[df$disease == dis, ]
  df_dis <- df_dis %>%  mutate(index=1:n()) #create an index variable 1,2,3...
  
  # Manually set titles based on the disease
  if (dis == "Rheumatoid") {
    dis_title <- "Rheumatoid arthritis"
  } else if (dis == "Psa") {
    dis_title <- "Psoriatic arthritis"
  } else if (dis == "Axialspa") {
    dis_title <- "Axial spondyloarthritis"
  } else if (dis == "Undiffia") {
    dis_title <- "Undifferentiated IA"
  } else if (dis == "Gca") {
    dis_title <- "Giant cell arteritis"
  } else if (dis == "Sjogren") {
    dis_title <- "Sjogren's disease"
  } else if (dis == "Ssc") {
    dis_title <- "Systemic sclerosis"
  } else if (dis == "Sle") {
    dis_title <- "SLE"
  } else if (dis == "Anca") {
    dis_title <- "ANCA vasculitis"
  } else if (dis == "Eia") {
    dis_title <- "Early inflammatory arthritis"
  } else if (dis == "Ctd") {
    dis_title <- "Connective tissue disease"
  } else if (dis == "Vasc") {
    dis_title <- "Vasculitis"
  } else if (dis == "Ctdvasc") {
    dis_title <- "CTD/Vasculitis"
  } else {
    dis_title <- str_to_title(str_replace_all(dis, "_", " "))
  }

  print(index_axis)
  
  y_label <- "Monthly incidence"
  
  # Label y-axis
  if (index_axis %in% c(1, 6, 11, 16)) {
    y_label <- "Monthly incidence"
  } else {
    y_label <- ""
  }
  
  x_label <- "Year"
  
  # Label x-axis
  if (index_axis %in% c(16, 17, 18, 19)) {
    x_label <- "Year"
  } else {
    x_label <- ""
  }

  max_index <- max(df_dis$index)
  
  # Keep data from before March 2020
  df_obs <- df_dis[which(df_dis$index<48),]
  
  # Loop through incidence (+/- counts if needed)
  for (i in 1:length(variables)) {
    var <- variables[i]
    #y_label <- y_labels[i]

    # Convert to time series object 
    df_obs_rate <- ts(df_obs[[var]], frequency=12, start=c(2016,4))
    assign(paste0("ts_", var), df_obs_rate)
  
    # Plot time series - 1) raw data; 2) 1st order difference (yt- yt-1); 3) 1st order seasonal difference (yt-yt-1)-(yt-12-yt-12-1); checking for stationarity (i.e. remove trends over time by differencing)
    svg(filename = paste0("output/figures/raw_pre_covid_", var, "_", dis, ".svg"), width = 8, height = 6)
    plot(df_obs_rate, ylim=c(), type='l', col="blue", xlab="Year", ylab=y_label)
    dev.off()
    svg(filename = paste0("output/figures/differenced_pre_covid_", var, "_", dis, ".svg"), width = 8, height = 6)
    plot(diff(df_obs_rate),type = "l");abline(h=0,col = "red") #1st order difference data
    dev.off()
    svg(filename = paste0("output/figures/seasonal_pre_covid_", var, "_", dis, ".svg"), width = 8, height = 6)
    plot(diff(diff(df_obs_rate),12),type = "l");abline(h=0,col = "red") #seasonal difference of 1st order difference data 
    dev.off()
    
    # View ACF/PACF plots of undifferenced data (noting the extent of autocorrelation between time points)
    svg(filename = paste0("output/figures/raw_acf_", var, "_", dis, ".svg"), width = 8, height = 6)
    acf2(df_obs_rate, max.lag=46) 
    dev.off()
    
    # View ACF/PACF plots of differenced data (checking for autocorrelation after differencing)
    svg(filename = paste0("output/figures/differenced_acf_", var, "_", dis, ".svg"), width = 8, height = 6)
    acf2(diff(df_obs_rate), max.lag=33)
    dev.off()
    
    # View ACF/PACF plots of differenced/seasonally differenced data (checking for autocorrelation after differencing)
    svg(filename = paste0("output/figures/seasonal_acf_", var, "_", dis, ".svg"), width = 8, height = 6)
    acf2(diff(diff(df_obs_rate,12)), max.lag=33)
    dev.off()
    
    # Use auto.arima to fit SARIMA model (identifying terms that optimise BIC/AIC); Nb. for models with poor fit on visual inspection/diagnostics, have explored different models
    if (dis == "pmr") {
      suggested.rate<- arima(df_obs_rate, order=c(0,1,1),  seasonal=list(order=c(2,1,0), period=12)) 
    #} else if (dis == "asthma") {
    #  suggested.rate<- arima(df_obs_rate, order=c(0,0,0),  seasonal=list(order=c(0,1,1), period=12))
    #} else if (dis == "ulcerative_colitis") {      
    # suggested.rate<- arima(df_obs_rate, order=c(0,0,0),  seasonal=list(order=c(0,1,1), period=12))
    #} else if (dis == "crohns_disease") {
    #    suggested.rate<- arima(df_obs_rate, order=c(0,1,2), seasonal=list(order=c(1,1,0), period=12))
    } else {
      suggested.rate<- auto.arima(df_obs_rate, max.p = 5, max.q = 5,  max.P = 2,  max.Q = 2, stepwise=FALSE, trace=TRUE)
    }
    print(suggested.rate)
    aic_value <- AIC(suggested.rate)
    print(paste("AIC:", aic_value))
    bic_value <- BIC(suggested.rate)
    print(paste("BIC:", bic_value))
    m1.rate <-suggested.rate
    m1.rate
    
    #Monthly prediction intervals from the model
    confint(m1.rate)
    
    # Check residuals
    svg(filename = paste0("output/figures/auto_residuals_", var, "_", dis, ".svg"), width = 8, height = 6)
    checkresiduals(suggested.rate)
    dev.off()
    Box.test(suggested.rate$residuals, lag = max_index - 48 + 1, type = "Ljung-Box")
  
    # Forecast from March 2020 and convert to time series object (Nb. h = max_index - pre-March 2020)
    fc.rate  <- forecast(m1.rate, h = max_index - 48)
  
    # Forecasted rates 
    fc.ratemean <- ts(as.numeric(fc.rate$mean), start=c(2020,3), frequency=12)
    fc.ratelower <- ts(as.numeric(fc.rate$lower[,2]), start=c(2020,3), frequency=12) #lower 95% prediction interval
    fc.rateupper <- ts(as.numeric(fc.rate$upper[,2]), start=c(2020,3), frequency=12) #upper 95% prediction interval
    
    # Flatten the matrix into a vector
    fc_rate<- data.frame(
      YearMonth = as.character(as.yearmon(time(fc.rate$mean))), # Year and month
      mean = as.numeric(as.matrix(fc.rate$mean)),
      lower = as.numeric(as.matrix(fc.rate$lower[, 2])),
      upper = as.numeric(as.matrix(fc.rate$upper[, 2]))
    )
  
    df_new <- df_dis %>% left_join(fc_rate, by = c("mon_year" = "YearMonth"))
    df_new$mean <- ifelse(is.na(df_new$mean), df_new[[var]], df_new$mean) #If NA (i.e. pre-forecast), replace as = observed incidence
    df_new$lower <- ifelse(is.na(df_new$lower), df_new[[var]], df_new$lower) #If NA (i.e. pre-forecast), replace as = observed incidence
    df_new$upper <- ifelse(is.na(df_new$upper), df_new[[var]], df_new$upper) #If NA (i.e. pre-forecast), replace as = observed incidence
    
    df_new <- df_new %>%
      arrange(index) %>%
      mutate(moving_average = rollmean(get(var), k = 3, fill = NA, align = "center"))
    
    df_new <- df_new %>%
      arrange(index) %>%
      mutate(mean_ma = rollmean(mean, k = 3, fill = NA, align = "center"))
    
    # Save a table of values
    write.csv(df_new, file = paste0("output/tables/values_", var, "_", dis, ".csv"), row.names = FALSE)
  
    # Plot observed and expected graphs
    c1<- 
      ggplot(data = df_new,aes(x = mo_year_diagn))+
      geom_point(aes(y = .data[[var]]), color="#5E716A", alpha = 0.25, size=1.5)+
      geom_line(aes(y = moving_average), color = "#5E716A", linetype = "solid", size=0.70)+
      geom_point(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(y = mean), color="orange", alpha = 0.25, size=1.5)+
      geom_line(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(y = mean_ma), color = "orange", linetype = "solid", size=0.65)+
      #geom_ribbon(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(ymin = lower, ymax = upper), alpha = 0.3, fill = "grey")+
      geom_segment(x = as.Date("2020-03-01"), 
                       xend = as.Date("2020-03-01"), 
                       y = min(df_new[[var]], na.rm = TRUE) * 0.85, 
                       yend = max(df_new[[var]], na.rm = TRUE) * 1.15,
                       linetype = "dashed", 
                       color = "grey")+
      scale_x_date(breaks = seq(as.Date("2016-01-01"), as.Date("2026-01-01"), by = "2 years"),
      date_labels = "%Y")+
      scale_y_continuous(limits = c(min(df_new[[var]], na.rm = TRUE) * 0.85, 
                                    max(df_new[[var]], na.rm = TRUE) * 1.15),
                         breaks = pretty(df_new[[var]], n = 4),
                         expand = expansion(mult = c(0.05, 0.05)))+
      theme_minimal()+
      xlab(x_label)+
      ylab(y_label)+
      theme(
        legend.title = element_blank(),
        panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        axis.line = element_line(color = "grey"),
        axis.ticks = element_line(color = "grey"),
        axis.text = element_text(size = 10, color = "black"),
        axis.title.x = element_text(size = 12, margin = margin(t = 5)),
        axis.title.y = element_text(size = 12, margin = margin(r = 5)), 
        plot.title = element_text(size = 14, hjust = 0.5, face = "plain") 
      ) +
      ggtitle(dis_title)
    
    saveRDS(c1, file = paste0("output/figures/obs_pred_", var, "_", dis, ".rds"))
    ggsave(filename = paste0("output/figures/obs_pred_", var, "_", dis, ".svg"), plot = c1, width = 8, height = 6, device = "svg")
    #ggsave(filename = paste0("output/figures/obs_pred_", var, "_", dis, ".png"), plot = c1, width = 8, height = 6, device = "png")
    
    print(c1)
    
    # Calculate absolute and relative differences between observed and expected values
    a<- c(47, 59, 71, 83, 47)
    b<- c(59, 71, 83, max_index, max_index)
    
    results_list <- list()
    
    for (i in 1:5) {
      
      observed_val <- df_new %>%
        filter(index > a[i] & index <= b[i]) %>%
        summarise(observed = sum(get(var))) %>%
        select(observed)
      
      predicted_val <- df_new %>%
        filter(index > a[i] & index <= b[i]) %>%
        mutate(se = (upper - lower) / (2 * 1.96)) %>%
        summarise(sum_pred_rate = sum(mean), total_var = sum(se^2)) %>%
        mutate(
          sum_pred_rate_l = (sum_pred_rate - (1.96 * sqrt(total_var))),
          sum_pred_rate_u = (sum_pred_rate + (1.96 * sqrt(total_var)))
        ) %>%
        select(sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u)
      
      observed_predicted_rate <- merge(observed_val, predicted_val)
      
      observed_predicted_rate <- observed_predicted_rate %>%
        mutate(change_rate = observed - sum_pred_rate,
               change_ratelow = observed - sum_pred_rate_l,
               change_ratehigh = observed - sum_pred_rate_u, 
               change_rate_per = (observed - sum_pred_rate) * 100 / sum_pred_rate,
               change_rate_per_low = (observed - sum_pred_rate_l) * 100 / sum_pred_rate_l, 
               change_rate_per_high = (observed - sum_pred_rate_u) * 100 / sum_pred_rate_u
        )
      
      # Store the result for this iteration in the list
      results_list[[i]] <- observed_predicted_rate %>%
        mutate(
          observed = round(observed, 3),
          sum_pred_rate = round(sum_pred_rate, 3),
          sum_pred_rate_l = round(sum_pred_rate_l, 3),
          sum_pred_rate_u = round(sum_pred_rate_u, 3),
          change_rate = round(change_rate, 3),
          change_ratelow = round(change_ratelow, 3),
          change_ratehigh = round(change_ratehigh, 3),
          change_rate_per = round(change_rate_per, 3),
          change_rate_per_low = round(change_rate_per_low, 3),
          change_rate_per_high = round(change_rate_per_high, 3)
        )
      
      if (i == 1) {
        rates.summary <- results_list[[i]] %>%
          select(observed, sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u, 
                 change_rate, change_ratelow, change_ratehigh,
                 change_rate_per, change_rate_per_low, change_rate_per_high)
        colnames(rates.summary)[1:10] <- paste0(colnames(rates.summary)[1:10], ".2020")
      } else if (i == 2) {
        current_summary <- results_list[[i]] %>%
          select(observed, sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u, 
                 change_rate, change_ratelow, change_ratehigh,
                 change_rate_per, change_rate_per_low, change_rate_per_high)
        colnames(current_summary)[1:10] <- paste0(colnames(current_summary)[1:10], ".2021")
        rates.summary <- merge(rates.summary, current_summary, by = "row.names", all = TRUE) %>%
          select(-Row.names)
      } else if (i == 3) {
        current_summary <- results_list[[i]] %>%
          select(observed, sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u, 
                 change_rate, change_ratelow, change_ratehigh,
                 change_rate_per, change_rate_per_low, change_rate_per_high)
        colnames(current_summary)[1:10] <- paste0(colnames(current_summary)[1:10], ".2022")
        rates.summary <- merge(rates.summary, current_summary, by = "row.names", all = TRUE) %>%
          select(-Row.names)
      } else if (i == 4) {
        current_summary <- results_list[[i]] %>%
          select(observed, sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u, 
                 change_rate, change_ratelow, change_ratehigh,
                 change_rate_per, change_rate_per_low, change_rate_per_high)
        colnames(current_summary)[1:10] <- paste0(colnames(current_summary)[1:10], ".202324")
        rates.summary <- merge(rates.summary, current_summary, by = "row.names", all = TRUE) %>%
          select(-Row.names)
      } else if (i == 5) {
        current_summary <- results_list[[i]] %>%
          select(observed, sum_pred_rate, sum_pred_rate_l, sum_pred_rate_u, 
                 change_rate, change_ratelow, change_ratehigh,
                 change_rate_per, change_rate_per_low, change_rate_per_high)
        colnames(current_summary)[1:10] <- paste0(colnames(current_summary)[1:10], ".total")
        rates.summary <- merge(rates.summary, current_summary, by = "row.names", all = TRUE) %>%
          select(-Row.names)
      }
    }
    
    rates.summary <- rates.summary %>%
      mutate(disease = dis_title) %>% 
      mutate(measure = var) %>% 
      select(measure, everything()) %>% 
      select(disease, everything()) 
    
    # Print summary table
    print(rates.summary)
    
    # Output to csv
    new_row <- rates.summary
    file_name <- "output/tables/change_incidence_byyear.csv"
    
    # Check if the file exists
    if (file.exists(file_name)) {
      existing_data <- read.csv(file_name)
      updated_data <- rbind(existing_data, new_row)
      write.csv(updated_data, file_name, row.names = FALSE)
    } else {
      write.csv(new_row, file_name, row.names = FALSE)
    }
  }
  
  # Increment index (for labelling)
  index_axis <- index_axis + 1
}    

# List and read all RDS files that match the pattern
rds_files <- list.files(path = "output/figures/", pattern = "^obs_pred_incidence.*_.*\\.rds$", full.names = TRUE)
plot_list <- lapply(rds_files, readRDS)

# Combine all plots
png("output/figures/sarima_combined.png", width = 12830, height = 8680, res = 720)
do.call(grid.arrange, c(plot_list, ncol=5))

dev.off()
graphics.off()
sink()

  ###### OUTPUT FILE
  write.csv(df,"output/tables/df_output.csv",row.names = FALSE)
  
# # Manual checks for diseases with poor fitting on visual inspection####################
#   
#   # Incidence data - use age and sex-standardised rates for incidence rates and unadjusted for counts
#   df <-read.csv("output/tables/arima_standardised.csv")
#   
#   #Rename variables in the datafile 
#   names(df)[names(df) == "numerator"] <- "count"
#   df<- df %>% select(disease, year, mo_year_diagn, incidence, count) 
#   df$month <- substr(df$mo_year_diagn, 1, 3)
#   df$mo_year_diagn <- gsub("-", " ", df$mo_year_diagn)
#   df$mon_year <- df$mo_year_diagn
#   df$mo_year_diagn <- as.Date(paste0("01 ", df$mo_year_diagn), format = "%d %b %Y")
#   month_lab <- c("Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec")
#   
#   disease_list <- unique(df$disease[df$disease == "crohns_disease"])
#   
#   # Define the variables to loop over
#   variables <- c("incidence")
#   y_labels <- c("Incidence per 100,000 population")
#   
#   # Loop through diseases
#   for (j in 1:length(disease_list)) {
#     
#     dis <- disease_list[j]
#     df_dis <- df[df$disease == dis, ]
#     df_dis <- df_dis %>%  mutate(index=1:n()) #create an index variable 1,2,3...
#     
#     # Manually set titles based on the disease
#     if (dis == "rheumatoid") {
#       dis_title <- "Rheumatoid Arthritis"
#     } else if (dis == "copd") {
#       dis_title <- "COPD"
#     } else if (dis == "crohns_disease") {
#       dis_title <- "Crohn's Disease"
#     } else if (dis == "dm_type2") {
#       dis_title <- "Diabetes Mellitus Type 2"
#     } else if (dis == "chd") {
#       dis_title <- "Coronary Heart Disease"
#     } else if (dis == "ckd") {
#       dis_title <- "Chronic Kidney Disease"
#     } else if (dis == "coeliac") {
#       dis_title <- "Coeliac Disease"
#     } else if (dis == "pmr") {
#       dis_title <- "Polymyalgia Rheumatica"
#     } else {
#       dis_title <- str_to_title(str_replace_all(dis, "_", " "))
#     }
#     
#     max_index <- max(df_dis$index)
#     
#     #Keep only data from before March 2020 and save to separate df
#     df_obs <- df_dis[which(df_dis$index<48),]
#     
#     # Loop through incidence and count
#     for (i in 1:length(variables)) {
#       var <- variables[i]
#       y_label <- y_labels[i]
#       
#       #Convert to time series object 
#       df_obs_rate <- ts(df_obs[[var]], frequency=12, start=c(2016,4))
#       assign(paste0("ts_", var), df_obs_rate)
#       
#       #Use auto.arima to fit SARIMA model - will identify p/q parameters that optimise AIC - for models with poor fit on visual inspection, explore different models
#       if (dis == "crohns_disease") {
#         #suggested.rate<- auto.arima(df_obs_rate, max.p = 5, max.q = 5,  max.P = 2,  max.Q = 2, stepwise=FALSE, trace=TRUE) 
#         #suggested.rate<- auto.arima(df_obs_rate, d=1, D=1, max.p = 5, max.q = 5,  max.P = 2,  max.Q = 2, stepwise=FALSE, trace=TRUE) 
#         suggested.rate<- arima(df_obs_rate, order=c(0,1,2), seasonal=list(order=c(1,1,0),period=12))
#         } else {
#         suggested.rate<- auto.arima(df_obs_rate, max.p = 5, max.q = 5,  max.P = 2,  max.Q = 2, stepwise=FALSE, trace=TRUE)
#       }
#       print(suggested.rate)
#       aic_value <- AIC(suggested.rate)
#       print(paste("AIC:", aic_value))
#       bic_value <- BIC(suggested.rate)
#       print(paste("BIC:", bic_value))
#       m1.rate <-suggested.rate
#       m1.rate
#       
#       #Monthly prediction intervals from the model
#       confint(m1.rate)
#       
#       #check residuals
#       svg(filename = paste0("output/figures/auto_residuals_", var, "_", dis, ".svg"), width = 8, height = 6)
#       checkresiduals(suggested.rate)
#       dev.off()
#       Box.test(suggested.rate$residuals, lag = 58, type = "Ljung-Box")
# 
#       #Forecast from March 2020 and convert to time series object - could change h to max_index - pre-March 2020
#       fc.rate  <- forecast(m1.rate, h=57)
#       
#       #Forecasted rates 
#       fc.ratemean <- ts(as.numeric(fc.rate$mean), start=c(2020,3), frequency=12)
#       fc.ratelower <- ts(as.numeric(fc.rate$lower[,2]), start=c(2020,3), frequency=12) #lower 95% CI
#       fc.rateupper <- ts(as.numeric(fc.rate$upper[,2]), start=c(2020,3), frequency=12) #upper 95% CI
#       
#       fc_rate<- data.frame(
#         YearMonth = as.character(as.yearmon(time(fc.rate$mean))), # Year and month
#         mean = as.numeric(as.matrix(fc.rate$mean)),
#         lower = as.numeric(as.matrix(fc.rate$lower[, 2])),
#         upper = as.numeric(as.matrix(fc.rate$upper[, 2]))
#         # Flatten the matrix into a vector
#       )
#       
#       df_new <- df_dis %>% left_join(fc_rate, by = c("mon_year" = "YearMonth"))
#       df_new$mean <- ifelse(is.na(df_new$mean), df_new[[var]], df_new$mean) #If NA (i.e. pre-forecast), replace as = observed incidence
#       df_new$lower <- ifelse(is.na(df_new$lower), df_new[[var]], df_new$lower) #If NA (i.e. pre-forecast), replace as = observed incidence
#       df_new$upper <- ifelse(is.na(df_new$upper), df_new[[var]], df_new$upper) #If NA (i.e. pre-forecast), replace as = observed incidence
#       
#       df_new <- df_new %>%
#         arrange(index) %>%
#         mutate(moving_average = rollmean(get(var), k = 3, fill = NA, align = "center"))
#       
#       df_new <- df_new %>%
#         arrange(index) %>%
#         mutate(mean_ma = rollmean(mean, k = 3, fill = NA, align = "center"))
#       
#       #observed and predicted graphs to check model predictions against observed values
#       c1<- 
#         ggplot(data = df_new,aes(x = mo_year_diagn))+
#         geom_point(aes(y = .data[[var]]), color="#5E716A", alpha = 0.25, size=1.5)+
#         geom_line(aes(y = moving_average), color = "#5E716A", linetype = "solid", size=0.70)+
#         geom_point(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(y = mean), color="orange", alpha = 0.25, size=1.5)+
#         geom_line(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(y = mean_ma), color = "orange", linetype = "solid", size=0.65)+
#         #geom_ribbon(data = df_new %>% filter(mo_year_diagn > as.Date("2020-02-01")), aes(ymin = lower, ymax = upper), alpha = 0.3, fill = "grey")+
#         geom_segment(x = as.Date("2020-03-01"), 
#                      xend = as.Date("2020-03-01"), 
#                      y = min(df_new[[var]], na.rm = TRUE) * 0.85, 
#                      yend = max(df_new[[var]], na.rm = TRUE) * 1.15,
#                      linetype = "dashed", 
#                      color = "grey")+
#         scale_x_date(breaks = seq(as.Date("2016-01-01"), as.Date("2026-01-01"), by = "2 years"),
#                      date_labels = "%Y")+
#         scale_y_continuous(limits = c(min(df_new[[var]], na.rm = TRUE) * 0.85, 
#                                       max(df_new[[var]], na.rm = TRUE) * 1.15),
#                            breaks = pretty(df_new[[var]], n = 4),
#                            expand = expansion(mult = c(0.05, 0.05)))+
#         theme_minimal()+
#         #xlab("Year of diagnosis")+
#         #ylab(y_label)+
#         xlab("")+
#         ylab("")+
#         theme(
#           legend.title = element_blank(),
#           panel.grid.major = element_blank(), 
#           panel.grid.minor = element_blank(),
#           axis.line = element_line(color = "grey"),
#           axis.ticks = element_line(color = "grey"),
#           axis.text = element_text(size = 10, color = "black"),
#           axis.title.x = element_text(size = 10, margin = margin(t = 10)),
#           axis.title.y = element_text(size = 10, margin = margin(r = 10)), 
#           plot.title = element_text(size = 14, hjust = 0.5, face = "plain") 
#         ) +
#         ggtitle(dis_title)
#       
#       saveRDS(c1, file = paste0("output/figures/test_", var, "_", dis, ".rds"))
#       ggsave(filename = paste0("output/figures/test_", var, "_", dis, ".svg"), plot = c1, width = 8, height = 6, device = "svg")
#       
#       print(c1)
#     }
#   }
# 
# dev.off()
# graphics.off()
# sink()  