version 16

/*==============================================================================
DO FILE NAME:			Prevalence graphs
PROJECT:				OpenSAFELY Inflammatory Rheumatology project
DATE: 					18/07/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Prevalence graphs
DATASETS USED:			Prevalence and Measures files
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
log using "$logdir/prevalence_graphs.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"

set type double

set scheme plotplainblind

*Prevalence graphs using rounded and redacted data ==========================================================*/
import delimited "$projectdir/output/tables/prevalence_rates_rounded.csv", clear

*Rename ANCA vasculitis
replace dis_full = "Small vessel vasculitis" if dis_full == "ANCA vasculitis"

levelsof disease, local(disease_list)

*Create graphs of prevalence rates diagnoses by year, by disease, using rounded/redacted data
foreach dis of local disease_list {
	preserve
	di "`dis'"
	keep if disease=="`dis'"
	keep if measure=="Prevalence"
		
	**Local full disease name
	local dis_full = dis_full[1]
	display "`dis_full'"
				
	***Ranges for prevalence graphs
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

	*Adjusted prevalence overall/male/female
	twoway connected s_rate_all year, ytitle("", size(med)) color(emerald%30) msymbol(circle) lcolor(emerald) lstyle(solid) ytitle("", size(medsmall)) || connected s_rate_male year, color(eltblue%30) msymbol(circle) lcolor(midblue) lstyle(solid) || connected s_rate_female year, color(orange%30) msymbol(circle) lcolor(red) lstyle(solid) ylabel("`ylab'", nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(1)2024, nogrid) title("`dis_full'", size(medium) margin(b=2)) xline(2020) legend(off) name(prev_adj_`dis', replace) saving("$projectdir/output/figures/prev_adj_`dis'.gph", replace)
		*graph export "$projectdir/output/figures/prev_adj_`dis'.png", replace
		graph export "$projectdir/output/figures/prev_adj_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "All" 2 "Male" 3 "Female"))
		
	*Adjusted prevalence comparison
	twoway connected rate_all year, ytitle("", size(med)) color(gold%30) msymbol(circle) lstyle(solid) lcolor(gold) ytitle("", size(medsmall)) || connected s_rate_all year, color(emerald%30) msymbol(circle) lstyle(solid) lcolor(emerald) ylabel("`ylab'", nogrid labsize(small)) xtitle("`xtitle'", size(medsmall) margin(medsmall)) xlabel(2016(1)2024, nogrid) xline(2020) title("`dis_full'", size(medium) margin(b=2)) legend(off) name(prev_comp_`dis', replace) saving("$projectdir/output/figures/prev_comp_`dis'.gph", replace)
		*graph export "$projectdir/output/figures/prev_comp_`dis'.png", replace
		graph export "$projectdir/output/figures/prev_comp_`dis'.svg", replace
		*legend(region(fcolor(white%0)) order(1 "Crude" 2 "Adjusted"))

	restore			
}

**Combine graphs (Nb. this doesnt work in OpenSAFELY console)
if $running_locally {
	preserve
	cd "$projectdir/output/figures"

	foreach stem in prev_adj prev_comp {
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
