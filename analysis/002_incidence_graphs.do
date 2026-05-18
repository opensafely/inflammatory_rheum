version 16

/*==============================================================================
DO FILE NAME:			Incidence graphs
PROJECT:				OpenSAFELY Inflammatory Rheumatology project
DATE: 					18/07/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Incidence tables and graphs
DATASETS USED:			Incidence and Measures files
OTHER OUTPUT: 			logfiles, printed to folder $Logdir
USER-INSTALLED ADO: 	 
  (place .ado file(s) in analysis folder)						
==============================================================================*/

*Set filepaths
/*
global projectdir "C:\Users\k1754142\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
global running_locally = 1 // Running on local machine
*/

global projectdir `c(pwd)'
global running_locally = 0 // Running on OpenSAFELY console

capture mkdir "$projectdir/output/data"
capture mkdir "$projectdir/output/tables"
capture mkdir "$projectdir/output/figures"

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list and study dates (passed from yaml)
global arglist diseases intervention_date_covid suffix
args $arglist

if $running_locally ==0 {
	foreach var of global arglist {
		local `var' : subinstr local `var' "|" " ", all
		global `var' "``var''"
		di "$`var'"
	}
}

if $running_locally ==1 {
	global diseases "eia rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"
	global intervention_date_covid "2020-03-01"
	global suffix ""
}

di "$diseases"
di "$intervention_date_covid"
di "$suffix"

*Open a log file
global logdir "$projectdir/logs"
cap log close
log using "$logdir/incidence_graphs${suffix}.log", replace

set type double

set scheme plotplainblind

*Incidence graphs using rounded and redacted data ==========================================================*/
import delimited "$projectdir/output/tables/incidence_rates_rounded${suffix}.csv", clear

*Reformat date
rename mo_year_diagn mo_year_diagn_s
gen mo_year_diagn = monthly(mo_year_diagn_s, "MY")
format mo_year_diagn %tmMon-CCYY
drop mo_year_diagn_s

levelsof disease, local(disease_list)

*Create graphs of incidence rates diagnoses by month, by disease, using rounded/redacted data
foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
	
	**Skip if no observations
	if _N == 0 {
    di as error "No observations for `dis'; skipping"
    restore
    continue
	}
		
	**Local full disease name
	local dis_full = dis_full[1]
	display "`dis_full'"
	
	**Set y-axis format
	egen incidence_max = max(incidence)
	egen incidence_min = min(incidence)

	summ incidence_max, meanonly
	local imax = r(max)

	summ incidence_min, meanonly
	local imin = r(min)

	if missing(`imax') | missing(`imin') {
		di as error "Incidence not estimable for `dis'; skipping"
		restore
		continue
	}

	if `imax' == 0 {
		local lower = 0
		local upper = 1
		local format = "format(%9.1f)"
	}
	else if `imax' < 1 {
		local lower = round(`imin', 0.01)
		local upper = round(`imax', 0.01) * 1.05
		local format = "format(%03.1f)"
	}
	else if `imax' < 10 {
		local lower = round(`imin', 0.1)
		local upper = round(`imax', 0.1) * 1.05
		local format = "format(%9.1f)"
	}
	else {
		local lower = round(`imin', 1)
		local upper = round(`imax', 1) * 1.05
		local format = "format(%9.0f)"
	}

	if `lower' < 0.2 local lower = 0
	if `upper' <= `lower' local upper = `lower' + 1
	di `lower'
	di `upper'

	nicelabels `lower' `upper', local(ylab)
	di "`ylab'"
	
	**Label y-axis (for combined graph)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" | "`dis'" == "Gca" {
		*local ytitle "Monthly incidence rate per 100,000"
		local ytitle ""
	}
	else {
		local ytitle ""
	}

	**Label x-axis (for combined graph)
	if "`dis'" == "Anca" | "`dis'" == "Gca" {
		*local xtitle "Year"
		local xtitle ""
	}
	else {
		local xtitle ""
	}
	
	**********Need to automate xlabel dates
	
	***Set vertical intervention line
	local year  = real(substr("$intervention_date_covid", 1, 4))
	local month = real(substr("$intervention_date_covid", 6, 2))
	local intervention = ym(`year', `month')
	di `intervention'
	local xintlab = `intervention' + 1 
		
	**Generate moving average
	gen incidence_ma =(incidence[_n-1]+incidence[_n]+incidence[_n+1])/3
	
	twoway scatter incidence mo_year_diagn, ytitle("`ytitle'", size(medsmall)) color(emerald%20) msymbol(circle) || line incidence_ma mo_year_diagn, lcolor(emerald) lstyle(solid) ylabel(`ylab', `format' nogrid labsize(small)) xtitle("`xtitle'") xlabel(671 "2016" 695 "2018" 719 "2020" 743 "2022" 767 "2024" 791 "2026", nogrid labsize(small)) title("`dis_full'", size(medium) margin(b=2)) xline(`intervention') legend(off) name(inc_rate${suffix}_`dis', replace) saving("$projectdir/output/figures/inc_rate${suffix}_`dis'.gph", replace)
		graph export "$projectdir/output/figures/inc_rate${suffix}_`dis'.svg", replace
		*graph export "$projectdir/output/figures/inc_rate${suffix}_`dis'.png", replace
				
	restore
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	local stems "inc_rate${suffix}"
	foreach stem in `stems' {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
	graph export "`stem'_combined.svg", replace
	graph export "`stem'_combined.png", replace
	graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
restore
}
else {
    di "Not running locally — skipping graph combine"
}

*Create graphs of yearly incidence rates, by disease and subgroups ===================================*/
import delimited "$projectdir/output/tables/incidence_rates_rounded_subgroups${suffix}.csv", clear

**Collapse age bands
bys disease year: egen numerator_18_39 = sum(numerator_18_29 + numerator_30_39)
bys disease year: egen numerator_40_59 = sum(numerator_40_49 + numerator_50_59)
bys disease year: egen numerator_60_79 = sum(numerator_60_69 + numerator_70_79)

bys disease year: egen denominator_18_39 = sum(denominator_18_29 + denominator_30_39)
bys disease year: egen denominator_40_59 = sum(denominator_40_49 + denominator_50_59)
bys disease year: egen denominator_60_79 = sum(denominator_60_69 + denominator_70_79)

gen rate_18_39 = (numerator_18_39/denominator_18_39)*100000
gen rate_40_59 = (numerator_40_59/denominator_40_59)*100000
gen rate_60_79 = (numerator_60_79/denominator_60_79)*100000

**For age rate bands with >70% missing data, convert all in that age rate to missing
foreach disease in $diseases {
	di "`disease'"
	foreach var in rate_18_39 rate_40_59 rate_60_79 rate_80 rate_18_29 rate_30_39 rate_40_49 rate_50_59 rate_60_69 rate_70_79 {
		di "`var'"
		quietly count if missing(`var') & disease == "`disease'"
		local num_missing = r(N)
		di `num_missing'
		
		quietly count if disease == "`disease'"
		local total = r(N)
		di `total'
		
		local pct_missing = (`num_missing' / `total') * 100
		di `pct_missing'
		
		replace `var' = . if (`pct_missing' > 70) & disease == "`disease'"
	} 
} 

**Convert missing age rates to zero
foreach var in rate_18_39 rate_40_59 rate_60_79 rate_80 rate_18_29 rate_30_39 rate_40_49 rate_50_59 rate_60_69 rate_70_79 {
	recode `var' .=0 if `var' ==.
}

save "$projectdir/output/data/redacted_standardised${suffix}.dta", replace

use "$projectdir/output/data/redacted_standardised${suffix}.dta", clear

levelsof disease, local(disease_list)

foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
	
	**Skip if no observations
	if _N == 0 {
    di as error "No observations for `dis'; skipping"
    restore
    continue
	}
		
	**Local full disease name
	local dis_full = dis_full[1]
	display "`dis_full'"
		
	**Label y-axis (for combined graphs)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" | "`dis'" == "Gca" {
		*local ytitle "Yearly incidence rate per 100,000"
		local ytitle ""
	}
	else {
		local ytitle ""
	}
	
	**Label y-axis (for ethnicity graphs)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" {
		*local ytitle_ethn "Yearly incidence rate per 100,000"
		local ytitle ""
	}
	else {
		local ytitle_ethn ""
	}

	**Label x-axis (for combined graphs)
	if "`dis'" == "Anca" | "`dis'" == "Gca" {
		*local xtitle "Year"
		local xtitle ""
	}
	else {
		local xtitle ""
	}

	**Set y-axis ranges for overall/age/sex graphs
	egen rate_max_all = max(s_rate_all)
	egen rate_min_all = min(s_rate_all)
	egen rate_max_sex = max(max(s_rate_male, s_rate_female))
	egen rate_min_sex = min(min(s_rate_male, s_rate_female))
	egen rate_max_age = max(max(rate_18_39, rate_40_59, rate_60_79, rate_80))
	egen rate_min_age = min(min(rate_18_39, rate_40_59, rate_60_79, rate_80))
	egen rate_max_ethn = max(max(rate_white, rate_mixed, rate_black, rate_asian, rate_other, rate_ethunk))
	egen rate_min_ethn = min(min(rate_white, rate_mixed, rate_black, rate_asian, rate_other, rate_ethunk))
	egen rate_max_imd = max(max(rate_imd1, rate_imd2, rate_imd3, rate_imd4, rate_imd5, rate_imdunk))
	egen rate_min_imd = min(min(rate_imd1, rate_imd2, rate_imd3, rate_imd4, rate_imd5, rate_imdunk))

	foreach stem in all sex age ethn imd {

		summ rate_min_`stem', meanonly
		local rmin = r(min)

		summ rate_max_`stem', meanonly
		local rmax = r(max)

		if missing(`rmin') | missing(`rmax') {
			di as error "Rates not estimable for `stem'; using default y-axis"
			local lower_`stem' = 0
			local upper_`stem' = 1
			local format_`stem' = "format(%9.1f)"
		}
		else if `rmax' == 0 {
			local lower_`stem' = 0
			local upper_`stem' = 1
			local format_`stem' = "format(%9.1f)"
		}
		else if `rmin' < 1 {
			local lower_`stem' = round(0.80 * `rmin', 0.01)
			local upper_`stem' = round(1.10 * `rmax', 0.01)
			local format_`stem' = "format(%03.1f)"
		}
		else if `rmin' < 10 {
			local lower_`stem' = round(0.80 * `rmin', 0.1)
			local upper_`stem' = round(1.10 * `rmax', 0.1)
			local format_`stem' = "format(%9.1f)"
		}
		else if `rmin' < 100 {
			local lower_`stem' = round(0.80 * `rmin', 1)
			local upper_`stem' = round(1.10 * `rmax', 1)
			local format_`stem' = "format(%9.0f)"
		}
		else {
			local lower_`stem' = round(0.80 * `rmin', 10)
			local upper_`stem' = round(1.10 * `rmax', 10)
			local format_`stem' = "format(%9.0f)"
		}

		if `lower_`stem'' < 0.2 local lower_`stem' = 0
		if `upper_`stem'' <= `lower_`stem'' local upper_`stem' = `lower_`stem'' + 1
		di `lower_`stem''
		di `upper_`stem''

		nicelabels `lower_`stem'' `upper_`stem'', local(ylab_`stem')
		di "`ylab_`stem''"
	}
	
	**Set vertical intervention line
	local intervention = real(substr("$intervention_date_covid",1,4))
	display `intervention'
		
	**Yearly incidence comparison between adjusted and crude
	twoway connected rate_all year, ytitle("`ytitle'", size(medsmall)) color(gold%30) msymbol(circle) lstyle(solid) lcolor(gold) || connected s_rate_all year, color(emerald%30) msymbol(circle) lstyle(solid) lcolor(emerald) ylabel(`ylab_all', `format_all' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(inc_comp${suffix}_`dis', replace) saving("$projectdir/output/figures/inc_comp${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/inc_comp${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/inc_comp${suffix}_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "Crude" 2 "Adjusted")) 
	
	**Yearly incidence comparison by sex (adjusted)
	twoway connected s_rate_male year, ytitle("`ytitle'", size(medsmall)) color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(midblue) || connected s_rate_female year, color(orange%20) mlcolor(orange%20) msymbol(circle) lstyle(solid) lcolor(red) ylabel(`ylab_sex', `format_sex' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(adj_sex${suffix}_`dis', replace) saving("$projectdir/output/figures/adj_sex${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/adj_sex${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/adj_sex${suffix}_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "Male" 2 "Female"))
	
	**Yearly incidence comparison by age band (unadjusted)
	twoway connected rate_18_39 year, ytitle("`ytitle'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_40_59 year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_60_79 year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_80 year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_age', `format_age' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_age${suffix}_`dis', replace) saving("$projectdir/output/figures/unadj_age${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_age${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_age${suffix}_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("Age group", size(small) margin(b=1)) order(1 "18-39" 2 "40-59" 3 "60-79" 4 "80+"))
		
	**Yearly incidence comparison by ethnicity (unadjusted)
	twoway connected rate_white year, ytitle("`ytitle_ethn'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_mixed year, color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(eltblue) || connected rate_black year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_asian year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_other year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_ethn', `format_ethn' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_ethn${suffix}_`dis', replace) saving("$projectdir/output/figures/unadj_ethn${suffix}_`dis'.gph", replace)
		*graph export "$projectdir/output/figures/unadj_ethn${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_ethn${suffix}_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("Ethnicity", size(medsmall) margin(b=1)) order(1 "White" 2 "Mixed" 3 "Black" 4 "Asian" 5 "Chinese/Other"))
		
	**Yearly incidence comparison by IMD quintile (unadjusted)
	twoway connected rate_imd1 year, ytitle("`ytitle'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_imd2 year, color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(eltblue) || connected rate_imd3 year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_imd4 year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_imd5 year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_imd', `format_imd' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_imd${suffix}_`dis', replace) saving("$projectdir/output/figures/unadj_imd${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_imd${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_imd${suffix}_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("IMD quintile", size(small) margin(b=1)) order(1 "1 Most deprived" 2 "2" 3 "3" 4 "4" 5 "5 Least deprived")) 
		
	restore
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	local stems "inc_comp${suffix} adj_sex${suffix} unadj_age${suffix} unadj_imd${suffix}"
	foreach stem in `stems' {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
	graph export "`stem'_combined.svg", replace
	graph export "`stem'_combined.png", replace
		graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
	restore
}
else {
    di "Not running locally — skipping graph combine"
}

**Combine graphs for ethnicity (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	local stems "unadj_ethn${suffix}"
	foreach stem in `stems' {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Sjogren `stem'_Sle `stem'_Gca, col(3) name(`stem'_combined, replace)
	graph export "`stem'_combined.svg", replace
	graph export "`stem'_combined.png", replace
	graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
	restore
}
else {
    di "Not running locally — skipping graph combine"
}

*Graphs of mean age, by study year and disease==============================*/
import delimited "$projectdir/output/tables/mean_age_rounded${suffix}.csv", clear

gen disease = strproper(subinstr(cohort, "_", " ",.))
drop cohort
gen dis_full = disease
replace dis_full = "Rheumatoid arthritis" if dis_full == "Rheumatoid"
replace dis_full = "Psoriatic arthritis" if dis_full == "Psa"
replace dis_full = "Axial spondyloarthritis" if dis_full == "Axialspa"
replace dis_full = "Undifferentiated IA" if dis_full == "Undiffia"
replace dis_full = "Giant cell arteritis" if dis_full == "Gca"
replace dis_full = "Sjogren's disease" if dis_full == "Sjogren"
replace dis_full = "Systemic sclerosis" if dis_full == "Ssc"
replace dis_full = "SLE" if dis_full == "Sle"
replace dis_full = "Myositis" if dis_full == "Myositis"
replace dis_full = "Small vessel vasculitis" if dis_full == "Anca"
order disease, first
order dis_full, after(disease)

levelsof disease, local(disease_list)

foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
	
	**Skip if no observations
	if _N == 0 {
    di as error "No observations for `dis'; skipping"
    restore
    continue
	}
		
	**Local full disease name
	local dis_full = dis_full[1]
	display "`dis_full'"

	**Label y-axis (for combined graph)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" | "`dis'" == "Gca" {
		*local ytitle "Age at diagnosis"
		local ytitle ""
	}
	else {
		local ytitle ""
	}

	**Label x-axis (for combined graph)
	if "`dis'" == "Anca" | "`dis'" == "Gca" {
		*local xtitle "Year"
		local xtitle ""
	}
	else {
		local xtitle ""
	}
	
	***Set vertical intervention line
	local intervention = real(substr("$intervention_date_covid",1,4))
	display `intervention'
		
	twoway connected mean_age year, ytitle("`ytitle'", size(medsmall)) color(emerald%20) msymbol(circle) lstyle(solid) lcolor(emerald) ylabel(20(10)80, nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(mean_age${suffix}_`dis', replace) saving("$projectdir/output/figures/mean_age${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/mean_age${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/mean_age${suffix}_`dis'.svg", replace
	
	twoway connected median_age year, ytitle("`ytitle'", size(medsmall)) color(orange%20) msymbol(circle) lstyle(solid) lcolor(orange) ylabel(20(10)80, nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(off) name(median_age${suffix}_`dis', replace) saving("$projectdir/output/figures/median_age${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/median_age${suffix}_`dis'.png", replace
		graph export "$projectdir/output/figures/median_age${suffix}_`dis'.svg", replace
		
	twoway connected mean_age year, ytitle("`ytitle'", size(medsmall)) color(emerald%20) msymbol(circle) lstyle(solid) lcolor(emerald) || connected median_age year, color(orange%20) msymbol(circle) lstyle(solid) lcolor(orange) ylabel(20(10)80, nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(`intervention') title("`dis_full'", size(medium) margin(b=2)) legend(region(fcolor(white%0)) order(1 "Mean age" 2 "Median age")) name(mean_med_age_`dis', replace) saving("$projectdir/output/figures/mean_med_age${suffix}_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/mean_med_age${suffix}_`dis'.png", replace width(1800) height(1200)
		graph export "$projectdir/output/figures/mean_med_age${suffix}_`dis'.svg", replace
				
	restore
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	local stems "mean_age${suffix} mean_med_age${suffix}"
	foreach stem in `stems' {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
	graph export "`stem'_combined.png", replace
	graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
restore
}
else {
    di "Not running locally — skipping graph combine"
}

log close	
