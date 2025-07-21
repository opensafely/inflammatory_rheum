version 16

/*==============================================================================
DO FILE NAME:			Incidence graphs
PROJECT:				OpenSAFELY Inflammatory Rheumatology project
DATE: 					18/07/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Processing of incidence/measures data
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
log using "$logdir/incidence_disease.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"

set type double

*Import dataset
import delimited "$projectdir/output/dataset_incidence.csv", clear

set scheme plotplainblind

*Keep only patients with one or more incident diagnoses ==============================*/
gen has_disease = 0

foreach disease in $diseases {
	di "`disease'"
	
	rename `disease'_inc_date `disease'_inc_date_s
	gen `disease'_inc_date = date(`disease'_inc_date_s, "YMD") 
	format `disease'_inc_date %td
	drop `disease'_inc_date_s

	rename `disease'_prim_date `disease'_prim_date_s
	gen `disease'_prim_date = date(`disease'_prim_date_s, "YMD") 
	format `disease'_prim_date %td
	drop `disease'_prim_date_s
	
	*Update has_disease if any date is nonmissing
	replace has_disease = 1 if !missing(`disease'_inc_date) | !missing(`disease'_prim_date)
} 

*Keep only patients with at least one disease
keep if has_disease == 1

drop has_disease

*Create and label variables ===========================================================*/

**Sex
gen gender = 1 if sex == "female"
replace gender = 2 if sex == "male"
lab var gender "Gender"
lab define gender 1 "Female" 2 "Male", modify
lab val gender gender
tab gender, missing
keep if gender == 1 | gender == 2
drop sex

**Ethnicity
gen ethnicity_n = 1 if ethnicity == "White"
replace ethnicity_n = 2 if ethnicity == "Asian or Asian British"
replace ethnicity_n = 3 if ethnicity == "Black or Black British"
replace ethnicity_n = 4 if ethnicity == "Mixed"
replace ethnicity_n = 5 if ethnicity == "Chinese or Other Ethnic Groups"
replace ethnicity_n = 6 if ethnicity == "Unknown"


label define ethnicity_n	1 "White"  						///
							2 "Asian or Asian British"		///
							3 "Black or Black British"  	///
							4 "Mixed"						///
							5 "Chinese or Other Ethnic Groups" ///
							6 "Unknown", modify
							
label values ethnicity_n ethnicity_n
lab var ethnicity_n "Ethnicity"
tab ethnicity_n, missing
drop ethnicity
rename ethnicity_n ethnicity

**IMD
gen imd = 1 if imd_quintile == "1 (most deprived)"
replace imd = 2 if imd_quintile == "2"
replace imd = 3 if imd_quintile == "3"
replace imd = 4 if imd_quintile == "4"
replace imd = 5 if imd_quintile == "5 (least deprived)"
replace imd = 6 if imd_quintile == "Unknown"

label define imd 1 "1 (most deprived)" 2 "2" 3 "3" 4 "4" 5 "5 (least deprived)" 6 "Unknown", modify
label values imd imd 
lab var imd "Index of multiple deprivation"
tab imd, missing
drop imd_quintile

**Age at diagnosis
foreach disease in $diseases {
	lab var `disease'_age "Age at diagnosis"
	codebook `disease'_age
	gen `disease'_age_band = 1 if ((`disease'_age >= 18) & (`disease'_age < 30)) 
	replace `disease'_age_band = 2 if ((`disease'_age >= 30) & (`disease'_age < 40))
	replace `disease'_age_band = 3 if ((`disease'_age >= 40) & (`disease'_age < 50))
	replace `disease'_age_band = 4 if ((`disease'_age >= 50) & (`disease'_age < 60))
	replace `disease'_age_band = 5 if ((`disease'_age >= 60) & (`disease'_age < 70))
	replace `disease'_age_band = 6 if ((`disease'_age >= 70) & (`disease'_age < 80))
	replace `disease'_age_band = 7 if ((`disease'_age >= 80) & (`disease'_age !=.))
	lab var `disease'_age_band "Age band, years"

	label define `disease'_age_band		1 "18 to 30" ///
										2 "30 to 39" ///
										3 "40 to 49" ///
										4 "50 to 59" ///
										5 "60 to 69" ///
										6 "70 to 79" ///
										7 "80 or above", modify
	lab val `disease'_age_band `disease'_age_band
}

**Gen incident disease cohorts during full study period
foreach disease in $diseases {
	gen `disease' = 1 if `disease'_inc_case=="T" & (`disease'_age >=18 & `disease'_age <= 110) & `disease'_pre_reg=="T" & `disease'_alive_inc=="T"
	recode `disease' .=0
	gen `disease'_p = 1 if `disease'_inc_case_p=="T" & (`disease'_age_p >=18 & `disease'_age_p <= 110) & `disease'_pre_reg_p=="T" & `disease'_alive_inc_p=="T"
	recode `disease'_p .=0
}

**Format dates
foreach disease in $diseases {
    gen `disease'_year = year(`disease'_inc_date)
	format `disease'_year %ty
	gen `disease'_mon = month(`disease'_inc_date)
	gen `disease'_moyear = ym(`disease'_year, `disease'_mon)
	format `disease'_moyear %tmMon-CCYY
	generate str16 `disease'_moyear_st = strofreal(`disease'_moyear,"%tmCCYY!mNN")
	lab var `disease'_moyear "Month/Year of Diagnosis"
	lab var `disease'_moyear_st "Month/Year of Diagnosis"
	gen `disease'_year_p = year(`disease'_prim_date)
	format `disease'_year_p %ty
	gen `disease'_mon_p = month(`disease'_prim_date)
	gen `disease'_moyear_p = ym(`disease'_year_p, `disease'_mon_p)
	format `disease'_moyear_p %tmMon-CCYY
	generate str16 `disease'_moyear_pst = strofreal(`disease'_moyear_p,"%tmCCYY!mNN")
	lab var `disease'_moyear_p "Month/Year of Diagnosis"
	lab var `disease'_moyear_pst "Month/Year of Diagnosis"
}

save "$projectdir/output/data/incidence_data_processed.dta", replace

/*Tables================================================================*/

use "$projectdir/output/data/incidence_data_processed.dta", clear

**Baseline table for each disease
foreach disease in $diseases {
preserve
keep if `disease'==1
di "`disease'"
table1_mc, total(before) onecol nospacelowpercent missing iqrmiddle(",")  ///
	vars(`disease'_age contn %5.1f \ ///
		 `disease'_age_band cat %5.1f \ ///
		 gender cat %5.1f \ ///
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
	foreach var of varlist imd ethnicity gender `disease'_age_band {
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

*Graphs of raw diagnosis counts================================================================*/

**Combined primary and secondary care
use "$projectdir/output/data/incidence_data_processed.dta", clear

*Graph of (count) diagnoses by month, by disease
foreach disease in $diseases {
	preserve
	keep if `disease'==1 //would need to remove this if calculating incidence
	collapse (count) total_diag_un=`disease', by(`disease'_moyear) 
	gen total_diag = round(total_diag_un, 5)
	drop total_diag_un
	
	export delimited using "$projectdir/output/tables/incidence_count_`disease'.csv", datafmt replace
	
	**Label diseases
	local dis_full = strproper(subinstr("`disease'", "_", " ",.)) 
	if "`dis_full'" == "Rheumatoid" local dis_full "Rheumatoid arthritis"
	if "`dis_full'" == "Psa" local dis_full "Psoriatic arthritis"
	if "`dis_full'" == "Axialspa" local dis_full "Axial spondyloarthritis"
	if "`dis_full'" == "Undiffia" local dis_full "Undifferentiated IA"
	if "`dis_full'" == "Gca" local dis_full "Giant cell arteritis"
	if "`dis_full'" == "Sjogren" local dis_full "Sjogrens disease"
	if "`dis_full'" == "Ssc" local dis_full "Systemic sclerosis"
	if "`dis_full'" == "Sle" local dis_full "SLE"
	if "`dis_full'" == "Myositis" local dis_full "Myositis"
	if "`dis_full'" == "Anca" local dis_full "ANCA vasculitis"
	
	**Generate moving average
	gen total_diag_ma =(total_diag[_n-1]+total_diag[_n]+total_diag[_n+1])/3
	
	twoway scatter total_diag `disease'_moyear, ytitle("Monthly diagnosis count", size(med)) color(emerald%20) msymbol(circle) || line total_diag_ma `disease'_moyear, lcolor(emerald) lstyle(solid) ylabel(, nogrid labsize(small)) xtitle("Date of diagnosis", size(medium) margin(medsmall)) xlabel(671 "2016" 683 "2017" 695 "2018" 707 "2019" 719 "2020" 731 "2021" 743 "2022" 755 "2023" 767 "2024" 779 "2025" 791 "2026", nogrid labsize(small)) title("`dis_full'", size(medium) margin(b=2)) xline(722) legend(off) name(`disease'_count, replace) saving("$projectdir/output/figures/count_inc_`disease'.gph", replace)
		graph export "$projectdir/output/figures/count_inc_`disease'.svg", replace
		
	restore
}

**Primary care only
use "$projectdir/output/data/incidence_data_processed.dta", clear

*Graph of (count) diagnoses by month, by disease
foreach disease in $diseases {
	preserve
	keep if `disease'_p==1 //would need to remove this if calculating incidence
	collapse (count) total_diag_un=`disease'_p, by(`disease'_moyear_p) 
	gen total_diag = round(total_diag_un, 5)
	drop total_diag_un
	
	export delimited using "$projectdir/output/tables/incidence_count_p_`disease'.csv", datafmt replace
	
	**Label diseases
	local dis_full = strproper(subinstr("`disease'", "_", " ",.)) 
	if "`dis_full'" == "Rheumatoid" local dis_full "Rheumatoid arthritis"
	if "`dis_full'" == "Psa" local dis_full "Psoriatic arthritis"
	if "`dis_full'" == "Axialspa" local dis_full "Axial spondyloarthritis"	
	if "`dis_full'" == "Undiffia" local dis_full "Undifferentiated IA"
	if "`dis_full'" == "Gca" local dis_full "Giant cell arteritis"
	if "`dis_full'" == "Sjogren" local dis_full "Sjogrens disease"
	if "`dis_full'" == "Ssc" local dis_full "Systemic sclerosis"
	if "`dis_full'" == "Sle" local dis_full "SLE"
	if "`dis_full'" == "Myositis" local dis_full "Myositis"
	if "`dis_full'" == "Anca" local dis_full "ANCA vasculitis"	
	
	**Generate moving average
	gen total_diag_ma =(total_diag[_n-1]+total_diag[_n]+total_diag[_n+1])/3
	
	twoway scatter total_diag `disease'_moyear_p, ytitle("Monthly diagnosis count", size(med)) color(emerald%20) msymbol(circle) || line total_diag_ma `disease'_moyear_p, lcolor(emerald) lstyle(solid) ylabel(, nogrid labsize(small)) xtitle("Date of diagnosis", size(medium) margin(medsmall)) xlabel(671 "2016" 683 "2017" 695 "2018" 707 "2019" 719 "2020" 731 "2021" 743 "2022" 755 "2023" 767 "2024" 779 "2025" 791 "2026", nogrid labsize(small)) title("`dis_full' Primary", size(medium) margin(b=2)) xline(722) legend(off) name(`disease'_count_p, replace) saving("$projectdir/output/figures/count_inc_p_`disease'.gph", replace)
		graph export "$projectdir/output/figures/count_inc_p_`disease'.svg", replace
		
	restore
}

*Import measures data for denominators**********************************

local years "2016 2017 2018 2019 2020 2021 2022 2023 2024"
local first_year: word 1 of `years'

**Import first file as base dataset
import delimited "$projectdir/output/measures/measures_incidence_`first_year'.csv", clear
save "$projectdir/output/data/measures_appended.dta", replace

**Loop over diseases and years
foreach year in `years' {
	if ("`year'" != "`first_year'")  {
	import delimited "$projectdir/output/measures/measures_incidence_`year'.csv", clear
	append using "$projectdir/output/data/measures_appended.dta"
	save "$projectdir/output/data/measures_appended.dta", replace 
	}
}

sort measure interval_start sex age
drop interval_end 

rename interval_start interval_start_s
gen interval_start = date(interval_start_s, "YMD") 
format interval_start %td
drop interval_start_s

gen year = year(interval_start)
format year %ty
gen month = month(interval_start)
gen mo_year_diagn = ym(year, month)
format mo_year_diagn %tmMon-CCYY
lab var mo_year_diagn "Month/Year of Diagnosis"
drop interval_start month

*For now, keep only monthly overall data - not broken down by age and sex
keep if measure == "population_overall"
drop age sex

**Round numbers
rename numerator numerator_un 
rename denominator denominator_un 
rename ratio ratio_un
gen numerator = round(numerator_un, 5)
gen denominator = round(denominator_un, 5)
gen ratio = numerator/denominator

export delimited using "$projectdir/output/tables/denominator_counts.csv", datafmt replace

save "$projectdir/output/data/measures_appended.dta", replace 

*Graphs of incidence rates and output rounded table for SARIMA =====================================================================*/

clear *
save "$projectdir/output/data/incidence_rates_rounded.dta", replace emptyok

use "$projectdir/output/data/incidence_data_processed.dta", clear

*Graph of incidence rates diagnoses by month, by disease
foreach disease in $diseases {
	preserve
	keep if `disease'==1 //would need to remove this if calculating incidence
	collapse (count) total_diag_un=`disease', by(`disease'_moyear) 
	gen total_diag = round(total_diag_un, 5)
	drop total_diag_un
	gen disease = strproper(subinstr("`disease'", "_", " ",.))
	gen mo_year_diagn = `disease'_moyear
	drop `disease'_moyear
	format mo_year_diagn %tmMon-CCYY
	order total_diag, after(mo_year_diagn)

	**Import rounded denominators
	merge 1:1 mo_year_diagn using "$projectdir/output/data/measures_appended.dta", keep(match) nogen
	
	**Drop unnecessary variables
	drop measure ratio_un numerator_un denominator_un denominator ratio
	rename numerator denominator
	rename total_diag numerator
	order year, after(mo_year_diagn)
		
	**Gen incidence rate per 100,000 adult population	
	gen incidence = (numerator/denominator)*100000

	save "$projectdir/output/data/incidence_rate_`disease'.dta" , replace
	export delimited using "$projectdir/output/tables/incidence_rate_`disease'.csv", datafmt replace
	
	**Output to appended dta
	append using "$projectdir/output/data/incidence_rates_rounded.dta"
	save "$projectdir/output/data/incidence_rates_rounded.dta", replace  
	
	use "$projectdir/output/data/incidence_rate_`disease'.dta", replace
	
	**Label diseases
	local dis_full = strproper(subinstr("`disease'", "_", " ",.)) 
	if "`dis_full'" == "Rheumatoid" local dis_full "Rheumatoid arthritis"
	if "`dis_full'" == "Psa" local dis_full "Psoriatic arthritis"
	if "`dis_full'" == "Axialspa" local dis_full "Axial spondyloarthritis"
	if "`dis_full'" == "Undiffia" local dis_full "Undifferentiated IA"
	if "`dis_full'" == "Gca" local dis_full "Giant cell arteritis"
	if "`dis_full'" == "Sjogren" local dis_full "Sjogrens disease"
	if "`dis_full'" == "Ssc" local dis_full "Systemic sclerosis"
	if "`dis_full'" == "Sle" local dis_full "SLE"
	if "`dis_full'" == "Myositis" local dis_full "Myositis"
	if "`dis_full'" == "Anca" local dis_full "ANCA vasculitis"
	
	**Generate moving average
	gen incidence_ma =(incidence[_n-1]+incidence[_n]+incidence[_n+1])/3
	
	twoway scatter incidence mo_year_diagn, ytitle("Monthly incidence rate per 100,000 population", size(med)) color(emerald%20) msymbol(circle) || line incidence_ma mo_year_diagn, lcolor(emerald) lstyle(solid) ylabel(, nogrid labsize(small)) xtitle("Date of diagnosis", size(medium) margin(medsmall)) xlabel(671 "2016" 683 "2017" 695 "2018" 707 "2019" 719 "2020" 731 "2021" 743 "2022" 755 "2023" 767 "2024" 779 "2025" 791 "2026", nogrid labsize(small)) title("`dis_full'", size(medium) margin(b=2)) xline(722) legend(off) name(`disease'_inc, replace) saving("$projectdir/output/figures/inc_rate_`disease'.gph", replace)
		graph export "$projectdir/output/figures/inc_rate_`disease'.svg", replace
		
	restore
}

use "$projectdir/output/data/incidence_rates_rounded.dta", clear
export delimited using "$projectdir/output/tables/incidence_rates_rounded.csv", datafmt replace

log close	
