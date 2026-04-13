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
*global projectdir "C:\Users\k1754142\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
*global running_locally = 1   // Running on local machine
global projectdir `c(pwd)'
global running_locally = 0   // Running on OpenSAFELY console

di "$projectdir"

capture mkdir "$projectdir/output/data"
capture mkdir "$projectdir/output/tables"
capture mkdir "$projectdir/output/figures"

global logdir "$projectdir/logs"
di "$logdir"

*Open a log file
cap log close
log using "$logdir/incidence_graphs_sens.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"

set type double

set scheme plotplainblind

*Incidence graphs using rounded and redacted data ==========================================================*/
import delimited "$projectdir/output/tables/incidence_rates_rounded_sens.csv", clear

*Reformat date
rename mo_year_diagn mo_year_diagn_s
gen mo_year_diagn = monthly(mo_year_diagn_s, "MY")
format mo_year_diagn %tmMon-CCYY
drop mo_year_diagn_s

*Rename ANCA vasculitis
replace dis_full = "Small vessel vasculitis" if dis_full == "ANCA vasculitis"

levelsof disease, local(disease_list)

*Create graphs of incidence rates diagnoses by month, by disease, using rounded/redacted data
foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
		
	**Local full disease name
	local dis_full = dis_full[1]
	display "`dis_full'"
	
	**Set y-axis format
	egen incidence_max = max(incidence)
	egen incidence_min = min(incidence)
	
	**Set y-axis ranges for overall/age/sex graphs
	if incidence_max < 1 {
		gen rate_low = round(incidence_min, 0.01)
		gen rate_up = round(incidence_max, 0.01)
		local format = "format(%03.1f)"
	}
	else if incidence_max >= 1 & incidence_max < 10 {
		gen rate_low = round(incidence_min, 0.1)
		gen rate_up = round(incidence_max, 0.1)
		local format = "format(%9.1f)"
	}
	else if incidence_max >= 10 & incidence_max < 100 {
		gen rate_low = round(incidence_min, 1)
		gen rate_up = round(incidence_max, 1)
		local format = "format(%9.0f)"
	}
		
	local lower = rate_low
	if `lower' < 0.2 local lower = 0
	di `lower'
	local upper = rate_up*1.05
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
		
	**Generate moving average
	gen incidence_ma =(incidence[_n-1]+incidence[_n]+incidence[_n+1])/3
	
	twoway scatter incidence mo_year_diagn, ytitle("`ytitle'", size(medsmall)) color(emerald%20) msymbol(circle) || line incidence_ma mo_year_diagn, lcolor(emerald) lstyle(solid) ylabel(`ylab', `format' nogrid labsize(small)) xtitle("`xtitle'") xlabel(671 "2016" 695 "2018" 719 "2020" 743 "2022" 767 "2024" 791 "2026", nogrid labsize(small)) title("`dis_full'", size(medium) margin(b=2)) xline(722) legend(off) name(inc_rate_sens_`dis', replace) saving("$projectdir/output/figures/inc_rate_sens_`dis'.gph", replace)
		graph export "$projectdir/output/figures/inc_rate_sens_`dis'.svg", replace
		*graph export "$projectdir/output/figures/inc_rate_sens_`dis'.png", replace
				
	restore
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	foreach stem in inc_rate_sens {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
	graph export "`stem'_combined.png", replace
	graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
restore
}
else {
    di "Not running locally — skipping graph combine"
}

*Create graphs of yearly incidence rates, by disease and subgroups ===================================*/
import delimited "$projectdir/output/tables/incidence_rates_rounded_subgroups_sens.csv", clear

*Rename ANCA vasculitis
replace dis_full = "Small vessel vasculitis" if dis_full == "ANCA vasculitis"

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

save "$projectdir/output/data/redacted_standardised_sens.dta", replace

use "$projectdir/output/data/redacted_standardised_sens.dta", clear

levelsof disease, local(disease_list)

foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
		
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
		if rate_min_`stem' < 1 {
			gen rate_low_`stem' = round(0.80 * rate_min_`stem', 0.01)
			gen rate_up_`stem' = round(1.10 * rate_max_`stem', 0.01)
		}
		else if rate_min_`stem' >1 & rate_min_`stem' < 10 {
			gen rate_low_`stem' = round(0.80 * rate_min_`stem', 0.1)
			gen rate_up_`stem' = round(1.10 * rate_max_`stem', 0.1)
		}
		else if rate_min_`stem' >10 & rate_min_`stem' < 100 {
			gen rate_low_`stem' = round(0.80 * rate_min_`stem', 1)
			gen rate_up_`stem' = round(1.10 * rate_max_`stem', 1)
		}
		else if rate_min_`stem' >100 & rate_min_`stem' < 1000 {
			gen rate_low_`stem' = round(0.80 * rate_min_`stem', 10)
			gen rate_up_`stem' = round(1.10 * rate_max_`stem', 10)
		}
		
		local lower_`stem' = rate_low_`stem'
		di `lower_`stem''
		local upper_`stem' = rate_up_`stem'
		di `upper_`stem''
		nicelabels `lower_`stem'' `upper_`stem'', local(ylab_`stem')
		di "`ylab_`stem''"
		
		if rate_max_`stem' < 5 {
			local format_`stem' = "format(%03.1f)"
		}
		else {
			local format_`stem' = "format(%9.0f)"
		}
	}
		
	**Yearly incidence comparison between adjusted and crude
	twoway connected rate_all year, ytitle("`ytitle'", size(medsmall)) color(gold%30) msymbol(circle) lstyle(solid) lcolor(gold) || connected s_rate_all year, color(emerald%30) msymbol(circle) lstyle(solid) lcolor(emerald) ylabel(`ylab_all', `format_all' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(inc_comp_sens_`dis', replace) saving("$projectdir/output/figures/inc_comp_sens_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/inc_comp_sens_`dis'.png", replace
		graph export "$projectdir/output/figures/inc_comp_sens_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "Crude" 2 "Adjusted")) 
	
	**Yearly incidence comparison by sex (adjusted)
	twoway connected s_rate_male year, ytitle("`ytitle'", size(medsmall)) color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(midblue) || connected s_rate_female year, color(orange%20) mlcolor(orange%20) msymbol(circle) lstyle(solid) lcolor(red) ylabel(`ylab_sex', `format_sex' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(adj_sex_sens_`dis', replace) saving("$projectdir/output/figures/adj_sex_sens_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/adj_sex_sens_`dis'.png", replace
		graph export "$projectdir/output/figures/adj_sex_sens_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "Male" 2 "Female"))
	
	**Yearly incidence comparison by age band (unadjusted)
	twoway connected rate_18_39 year, ytitle("`ytitle'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_40_59 year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_60_79 year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_80 year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_age', `format_age' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_age_sens_`dis', replace) saving("$projectdir/output/figures/unadj_age_sens_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_age_sens_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_age_sens_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("Age group", size(small) margin(b=1)) order(1 "18-39" 2 "40-59" 3 "60-79" 4 "80+"))
		
	**Yearly incidence comparison by ethnicity (unadjusted)
	twoway connected rate_white year, ytitle("`ytitle_ethn'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_mixed year, color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(eltblue) || connected rate_black year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_asian year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_other year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_ethn', `format_ethn' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_ethn_sens_`dis', replace) saving("$projectdir/output/figures/unadj_ethn_sens_`dis'.gph", replace)
		*graph export "$projectdir/output/figures/unadj_ethn_sens_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_ethn_sens_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("Ethnicity", size(medsmall) margin(b=1)) order(1 "White" 2 "Mixed" 3 "Black" 4 "Asian" 5 "Chinese/Other"))
		
	**Yearly incidence comparison by IMD quintile (unadjusted)
	twoway connected rate_imd1 year, ytitle("`ytitle'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_imd2 year, color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(eltblue) || connected rate_imd3 year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_imd4 year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_imd5 year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(`ylab_imd', `format_imd' nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(unadj_imd_sens_`dis', replace) saving("$projectdir/output/figures/unadj_imd_sens_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_imd_sens_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_imd_sens_`dis'.svg", replace
		*legend(region(fcolor(white%0)) title("IMD quintile", size(small) margin(b=1)) order(1 "1 Most deprived" 2 "2" 3 "3" 4 "4" 5 "5 Least deprived")) 
		
	restore
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	foreach stem in inc_comp_sens adj_sex_sens unadj_age_sens unadj_imd_sens {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
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

	foreach stem in unadj_ethn_sens {
		graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Sjogren `stem'_Sle `stem'_Gca, col(3) name(`stem'_combined, replace)
	graph export "`stem'_combined.png", replace
	graph export "`stem'_combined.tif", replace width(1800) height(1200)
	}
	restore
}
else {
    di "Not running locally — skipping graph combine"
}

log close	
