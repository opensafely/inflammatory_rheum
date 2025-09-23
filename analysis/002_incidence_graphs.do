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
*global projectdir "C:\Users\Mark\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
*global projectdir "C:\Users\k1754142\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
global projectdir `c(pwd)'
di "$projectdir"

capture mkdir "$projectdir/output/data"
capture mkdir "$projectdir/output/tables"
capture mkdir "$projectdir/output/figures"

global logdir "$projectdir/logs"
di "$logdir"

*Open a log file
cap log close
log using "$logdir/incidence_graphs.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "eia ctd vasc ctdvasc rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"
*global diseases "ctd"

set type double

*Baseline tables================================================================*/

use "$projectdir/output/data/incidence_data_processed.dta", clear

**Baseline table for each disease
foreach disease in $diseases {
preserve
keep if `disease'==1
di "`disease'"
table1_mc, total(before) onecol nospacelowpercent missing iqrmiddle(",")  ///
	vars(`disease'_age contn %5.1f \ ///
		 `disease'_age_band cat %5.1f \ ///
		 sex cat %5.1f \ ///
		 ethnicity cat %5.1f \ ///
		 imd cat %5.1f \ ///
		 )
restore
}

**Rounded and redacted baseline tables for each disease
clear *
save "$projectdir/output/data/baseline_table_rounded.dta", replace emptyok

foreach disease in $diseases {
	use "$projectdir/output/data/incidence_data_processed.dta", clear
	keep if `disease'==1
	foreach var of varlist imd ethnicity sex `disease'_age_band {
		preserve
		contract `var'
		local v : variable label `var' 
		gen variable = `"`v'"'
		decode `var', gen(categories)
		gen count = round(_freq, 5)
		egen total = total(count)
		gen percent = round((count/total)*100, 0001)
		order total, before(percent)
		replace percent = . if count<=7
		replace total = . if count<=7
		replace count = . if count<=7
		gen cohort = "`disease'"
		order cohort, first
		format percent %14.4f
		format count total %14.0f
		list cohort variable categories count total percent
		keep cohort variable categories count total percent
		append using "$projectdir/output/data/baseline_table_rounded.dta"
		save "$projectdir/output/data/baseline_table_rounded.dta", replace
		restore
	}

	preserve
	collapse (count) count=`disease' (mean) mean_age=`disease'_age (sd) stdev_age=`disease'_age
	gen cohort ="`disease'"
	rename *count freq
	gen count = round(freq, 5)
	gen countstr = string(count)
	replace stdev_age = . if count<=7
	replace mean_age = . if count<=7
	replace count = . if count<=7
	order cohort, first
	gen variable = "Age"
	order variable, after(cohort)
	gen categories = "Not applicable"
	order categories, after(variable)
	order count, after(stdev_age)
	gen total = count
	order total, after(count)
	format mean_age %14.4f
	format stdev_age %14.4f
	format count %14.0f
	list cohort variable categories mean_age stdev_age count total
	keep cohort variable categories mean_age stdev_age count total
	append using "$projectdir/output/data/baseline_table_rounded.dta"
	save "$projectdir/output/data/baseline_table_rounded.dta", replace	
	restore
}	
use "$projectdir/output/data/baseline_table_rounded.dta", clear
export delimited using "$projectdir/output/tables/baseline_table_rounded.csv", datafmt replace

*Incidence graphs using rounded and redacted data ==========================================================
import delimited "$projectdir/output/tables/incidence_rates_rounded.csv", clear

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
		
	**Label diseases - can remove this once re-run and add new line to local dis_full = dis_full
	if "`dis'" == "Eia" local dis_full "Early inflammatory arthritis"
	if "`dis'" == "Rheumatoid" local dis_full "Rheumatoid arthritis"
	if "`dis'" == "Psa" local dis_full "Psoriatic arthritis"
	if "`dis'" == "Axialspa" local dis_full "Axial spondyloarthritis"
	if "`dis'" == "Undiffia" local dis_full "Undifferentiated IA"
	if "`dis'" == "Gca" local dis_full "Giant cell arteritis"
	if "`dis'" == "Sjogren" local dis_full "Sjogren's disease"
	if "`dis'" == "Ssc" local dis_full "Systemic sclerosis"
	if "`dis'" == "Sle" local dis_full "SLE"
	if "`dis'" == "Myositis" local dis_full "Myositis"
	if "`dis'" == "Anca" local dis_full "ANCA vasculitis"
	if "`dis'" == "Ctd" local dis_full "Connective tissue diseases"
	if "`dis'" == "Vasc" local dis_full "Vasculitis"
	if "`dis'" == "Ctdvasc" local dis_full "CTD and vasculitis"
	
	***Set y-axis format
	egen incidence_min = min(incidence)
	if incidence_min < 1 {
		local format = "format(%03.2f)"
	}
	else if incidence_min >= 1 & incidence_min < 10 {
		local format = "format(%9.1f)"
	}
	else {
		local format = "format(%9.1f)"
	}
	di "`format'"
	
	*Label y-axis (for combined graph)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" | "`dis'" == "Gca" {
		local ytitle "Monthly incidence rate per 100,000"
	}
	else {
		local ytitle ""
	}

	*Label x-axis (for combined graph)
	if "`dis'" == "Anca" | "`dis'" == "Gca" {
		*local xtitle "Year"
		local xtitle ""
	}
	else {
		local xtitle ""
	}	
		
	**Generate moving average
	gen incidence_ma =(incidence[_n-1]+incidence[_n]+incidence[_n+1])/3
	
	twoway scatter incidence mo_year_diagn, ytitle("`ytitle'", size(medsmall)) color(emerald%20) msymbol(circle) || line incidence_ma mo_year_diagn, lcolor(emerald) lstyle(solid) ylabel(, `format' nogrid labsize(small)) xtitle("`xtitle'") xlabel(671 "2016" 695 "2018" 719 "2020" 743 "2022" 767 "2024" 791 "2026", nogrid labsize(small)) title("`dis_full'", size(medium) margin(b=2)) xline(722) legend(off) name(inc_rate_`dis', replace) saving("$projectdir/output/figures/inc_rate_`dis'.gph", replace)
		graph export "$projectdir/output/figures/inc_rate_`dis'.svg", replace
		*graph export "$projectdir/output/figures/inc_rate_`dis'.png", replace
				
	restore
}

/*
*Combine graphs - Nb. this won't work in OpenSAFELY console
preserve
cd "$projectdir/output/figures"

foreach stem in inc_rate {
	graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
graph export "`stem'_combined.png", replace
}
restore
*/

*Create graphs of yearly incidence rates, by disease
import delimited "$projectdir/output/tables/incidence_rates_rounded_standardised.csv", clear

***Collapse age bands
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

save "$projectdir/output/data/redacted_standardised.dta", replace

use "$projectdir/output/data/redacted_standardised.dta", clear

levelsof disease, local(disease_list)

foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
		
	**Label diseases - can remove this once re-run and add new line to local dis_full = dis_full
	if "`dis'" == "Eia" local dis_full "Early inflammatory arthritis"
	if "`dis'" == "Rheumatoid" local dis_full "Rheumatoid arthritis"
	if "`dis'" == "Psa" local dis_full "Psoriatic arthritis"
	if "`dis'" == "Axialspa" local dis_full "Axial spondyloarthritis"
	if "`dis'" == "Undiffia" local dis_full "Undifferentiated IA"
	if "`dis'" == "Gca" local dis_full "Giant cell arteritis"
	if "`dis'" == "Sjogren" local dis_full "Sjogren's disease"
	if "`dis'" == "Ssc" local dis_full "Systemic sclerosis"
	if "`dis'" == "Sle" local dis_full "SLE"
	if "`dis'" == "Myositis" local dis_full "Myositis"
	if "`dis'" == "Anca" local dis_full "ANCA vasculitis"
	if "`dis'" == "Ctd" local dis_full "Connective tissue diseases"
	if "`dis'" == "Vasc" local dis_full "Vasculitis"
	if "`dis'" == "Ctdvasc" local dis_full "CTD and vasculitis"
	
	/*
	***Set y-axis format
	egen incidence_min = min(rate_all)
	if incidence_min < 1 {
		local format = "format(%03.2f)"
	}
	else if incidence_min >= 1 & incidence_min < 10 {
		local format = "format(%9.1f)"
	}
	else {
		local format = "format(%9.0f)"
	}
	di "`format'"
	*/
	
	*Label y-axis (for combined graph)
	if "`dis'" == "Rheumatoid" | "`dis'" == "Sjogren" | "`dis'" == "Gca" {
		local ytitle "Yearly incidence rate per 100,000"
	}
	else {
		local ytitle ""
	}

	*Label x-axis (for combined graph)
	if "`dis'" == "Anca" | "`dis'" == "Gca" {
		*local xtitle "Year"
		local xtitle ""
	}
	else {
		local xtitle ""
	}

	***Ranges for graphs
	egen s_rate_all_av = mean(s_rate_all)
	egen s_rate_male_max = max(s_rate_male)
	egen s_rate_male_min = min(s_rate_male)
	egen s_rate_female_max = max(s_rate_female)
	egen s_rate_female_min = min(s_rate_female)
	gen s_rate_max = max(s_rate_male_max, s_rate_female_max)
	gen s_rate_min = min(s_rate_male_min, s_rate_female_min)
	
	if s_rate_all_av < 1 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 0.01)
		gen s_rate_all_up = round(1.20 * s_rate_max, 0.01)
	}
	else if s_rate_all_av >1 & s_rate_all_av < 10 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 0.1)
		gen s_rate_all_up = round(1.20 * s_rate_max, 0.1)
	}
	else if s_rate_all_av >10 & s_rate_all_av < 100 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 1)
		gen s_rate_all_up = round(1.20 * s_rate_max, 1)
	}
	else if s_rate_all_av >100 & s_rate_all_av < 1000 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 10)
		gen s_rate_all_up = round(1.20 * s_rate_max, 10)
	}
	else if s_rate_all_av >1000 & s_rate_all_av < 10000 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 100)
		gen s_rate_all_up = round(1.20 * s_rate_max, 100)
	}
	else if s_rate_all_av >10000 & s_rate_all_av < 100000 {
		gen s_rate_all_low = round(0.80 * s_rate_min, 1000)
		gen s_rate_all_up = round(1.20 * s_rate_max, 1000)
	}

	di s_rate_all_av
	local lower = s_rate_all_low
	di `lower'
	local upper = s_rate_all_up
	di `upper'
	nicelabels `lower' `upper', local(ylab)
	di "`ylab'"

	*Yearly incidence comparison between adjusted and crude
	twoway connected rate_all year, ytitle("`ytitle'", size(medsmall)) color(gold%30) msymbol(circle) lstyle(solid) lcolor(gold) || connected s_rate_all year, color(emerald%30) msymbol(circle) lstyle(solid) lcolor(emerald) ylabel("`ylab'", nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(region(fcolor(white%0)) order(1 "Crude" 2 "Adjusted")) name(inc_comp_`dis', replace) saving("$projectdir/output/figures/inc_comp_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/inc_comp_`dis'.png", replace
		graph export "$projectdir/output/figures/inc_comp_`dis'.svg", replace
	
	*Yearly incidence comparison by sex (unadjusted)
	twoway connected rate_male year, ytitle("`ytitle'", size(medsmall)) color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(midblue) || connected rate_female year, color(orange%20) mlcolor(orange%20) msymbol(circle) lstyle(solid) lcolor(red) ylabel("`ylab'", nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(region(fcolor(white%0)) order(1 "Male" 2 "Female")) name(unadj_sex_`dis', replace) saving("$projectdir/output/figures/unadj_sex_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_sex_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_sex_`dis'.svg", replace
		
	*Yearly incidence comparison by sex (adjusted)
	twoway connected s_rate_male year, ytitle("`ytitle'", size(medsmall)) color(eltblue%20) mlcolor(eltblue%20) msymbol(circle) lstyle(solid) lcolor(midblue) || connected s_rate_female year, color(orange%20) mlcolor(orange%20) msymbol(circle) lstyle(solid) lcolor(red) ylabel("`ylab'", nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(region(fcolor(white%0)) order(1 "Male" 2 "Female")) name(adj_sex_`dis', replace) saving("$projectdir/output/figures/adj_sex_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/adj_sex_`dis'.png", replace
		graph export "$projectdir/output/figures/adj_sex_`dis'.svg", replace
		
	*Yearly incidence comparison by age band (unadjusted)
	twoway connected rate_18_39 year, ytitle("`ytitle'", size(medsmall)) color(ltblue%20) mlcolor(ltblue%20) msymbol(circle) lstyle(solid) lcolor(ltblue) || connected rate_40_59 year, color(ebblue%20) mlcolor(ebblue%20) msymbol(circle) lstyle(solid) lcolor(ebblue) || connected rate_60_79 year, color(blue%20) mlcolor(blue%20) msymbol(circle) lstyle(solid) lcolor(blue) || connected rate_80 year, color(navy%20) mlcolor(navy%20) msymbol(circle) lstyle(solid) lcolor(navy) ylabel(, nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(2)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(region(fcolor(white%0)) title("Age group", size(small) margin(b=1)) order(1 "18-39" 2 "40-59" 3 "60-79" 4 "80+")) name(unadj_age_`dis', replace) saving("$projectdir/output/figures/unadj_age_`dis'.gph", replace)	
		*graph export "$projectdir/output/figures/unadj_age_`dis'.png", replace
		graph export "$projectdir/output/figures/unadj_age_`dis'.svg", replace
					
	restore
}

/*Combine graphs (Nb. this doesnt work in OpenSAFELY console)
preserve
cd "$projectdir/output/figures"

foreach stem in inc_comp unadj_sex adj_sex unadj_age {
	graph combine `stem'_Rheumatoid `stem'_Psa `stem'_Axialspa `stem'_Undiffia `stem'_Sjogren `stem'_Sle `stem'_Ssc `stem'_Myositis `stem'_Gca `stem'_Anca, col(4) name(`stem'_combined, replace)
graph export "`stem'_combined.png", replace
}
restore
*/

log close	
