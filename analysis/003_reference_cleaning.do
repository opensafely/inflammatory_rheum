version 16

/*==============================================================================
DO FILE NAME:			Reference population cleaning
PROJECT:				OpenSAFELY Inflammatory Rheumatology project
DATE: 					18/07/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Processing of reference population data
DATASETS USED:			Incidence files
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
log using "$logdir/reference_cleaning.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

set type double

set scheme plotplainblind

*Import dataset
import delimited "$projectdir/output/dataset_incidence_ref.csv", clear

*Create and label variables ===========================================================*/

**Sex
rename sex sex_s
gen sex = 1 if sex_s == "female"
replace sex = 2 if sex_s == "male"
lab var sex "Sex"
lab define sex 1 "Female" 2 "Male", modify
lab val sex sex
tab sex, missing
keep if sex == 1 | sex == 2

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

**IMD
gen imd_n = 1 if imd_quintile == "1 (most deprived)"
replace imd_n = 2 if imd_quintile == "2"
replace imd_n = 3 if imd_quintile == "3"
replace imd_n = 4 if imd_quintile == "4"
replace imd_n = 5 if imd_quintile == "5 (least deprived)"
replace imd_n = 6 if imd_quintile == "Unknown"

label define imd_n 1 "1 (most deprived)" 2 "2" 3 "3" 4 "4" 5 "5 (least deprived)" 6 "Unknown", modify
label values imd_n imd_n 
lab var imd_n "Index of multiple deprivation"
tab imd_n, missing
rename imd_quintile imd

**Age at cohort entry
lab var age "Age"
rename age_band age_band_s
gen age_band = 1 if ((age >= 18) & (age < 30)) 
replace age_band = 2 if ((age >= 30) & (age < 40))
replace age_band = 3 if ((age >= 40) & (age < 50))
replace age_band = 4 if ((age >= 50) & (age < 60))
replace age_band = 5 if ((age >= 60) & (age < 70))
replace age_band = 6 if ((age >= 70) & (age < 80))
replace age_band = 7 if ((age >= 80) & (age !=.))
lab var age_band "Age band, years"

label define age_band		1 "18 to 29" ///
							2 "30 to 39" ///
							3 "40 to 49" ///
							4 "50 to 59" ///
							5 "60 to 69" ///
							6 "70 to 79" ///
							7 "80 or above", modify
lab val age_band age_band

save "$projectdir/output/data/reference_data_processed.dta", replace

*Baseline tables================================================================*/

clear *
save "$projectdir/output/data/reference_table_rounded.dta", replace emptyok

use "$projectdir/output/data/reference_data_processed.dta", clear
	
	drop imd ethnicity
	rename imd_n imd
	rename ethnicity_n ethnicity

	foreach var of varlist imd ethnicity sex age_band {
		preserve
		contract `var'
		local v : variable label `var' 
		gen variable = `"`v'"'
		decode `var', gen(categories)
		gen count = round(_freq, 5)
		egen total = total(count)
		gen percent = round((count/total)*100, 0.0001)
		order total, before(percent)
		replace percent = . if count<=7
		replace total = . if count<=7
		replace count = . if count<=7
		gen cohort = "Reference population"
		order cohort, first
		format percent %14.4f
		format count total %14.0f
		list cohort variable categories count total percent
		keep cohort variable categories count total percent
		append using "$projectdir/output/data/reference_table_rounded.dta"
		save "$projectdir/output/data/reference_table_rounded.dta", replace
		restore
	}
	
	use "$projectdir/output/data/reference_data_processed.dta", clear

	foreach var of varlist age {
		preserve
		collapse (count) count=patient_id (mean) mean_age=`var' (sd) stdev_age=`var'
		rename *count freq
		gen count = round(freq, 5)
		replace stdev_age = . if count<=7
		replace mean_age = . if count<=7
		replace count = . if count<=7
		gen cohort = "Reference population"
		order cohort, first
		gen variable = "Mean age, years"
		order variable, after(cohort)
		gen categories = "Not applicable"
		order categories, after(variable)
		order count, after(stdev_age)
		gen total = count
		order total, after(count)
		format mean_age stdev_age %14.4f
		format count %14.0f
		list cohort variable categories mean_age stdev_age count total
		keep cohort variable categories mean_age stdev_age count total
		append using "$projectdir/output/data/reference_table_rounded.dta"
		save "$projectdir/output/data/reference_table_rounded.dta", replace
		restore
	}

use "$projectdir/output/data/reference_table_rounded.dta", clear
export delimited using "$projectdir/output/tables/reference_table_rounded.csv", datafmt replace

log close	
