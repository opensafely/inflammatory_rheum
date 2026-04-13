version 16

/*==============================================================================
DO FILE NAME:			Prevalence cleaning
PROJECT:				OpenSAFELY Inflammatory Rheumatology project
DATE: 					18/07/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Processing of prevalence/measures data
DATASETS USED:			Prevalence and Measures files
OTHER OUTPUT: 			logfiles, printed to folder $Logdir
USER-INSTALLED ADO: 	 
  (place .ado file(s) in analysis folder)						
==============================================================================*/

*Set filepaths
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
log using "$logdir/prevalence_cleaning.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"

set type double

set scheme plotplainblind

*Import first measures file as base dataset
local first_disease: word 1 of $diseases
di "`first_disease'"

import delimited "$projectdir/output/measures/measures_prevalence_`first_disease'.csv", clear
save "$projectdir/output/data/measures_prevalence_appended.dta", replace

**Loop over diseases
foreach disease in $diseases {
	if ("`disease'" != "`first_disease'")  {
	import delimited "$projectdir/output/measures/measures_prevalence_`disease'.csv", clear
	append using "$projectdir/output/data/measures_prevalence_appended.dta"
	save "$projectdir/output/data/measures_prevalence_appended.dta", replace 
	}
}

sort measure interval_start sex age
save "$projectdir/output/data/measures_prevalence_appended.dta", replace 

*Clean dataset ============================================>/
use "$projectdir/output/data/measures_prevalence_appended.dta", clear 

**Format dates
rename interval_start interval_start_s
gen interval_start = date(interval_start_s, "YMD") 
format interval_start %td
drop interval_start_s interval_end

**Year of interval
gen year = year(interval_start)
format year %ty

**Code prevalent measure
gen measure_prev = 1 if substr(measure,-11,.) == "_prevalence"
recode measure_prev .=0

**Label diseases
gen diseases_ = substr(measure, 1, strlen(measure) - 11) if measure_prev==1
gen disease = strproper(subinstr(diseases_, "_", " ",.)) 
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
replace dis_full = "ANCA vasculitis" if dis_full == "Anca"
order dis_full, after(disease)
drop diseases_

save "$projectdir/output/data/measures_prevalence_appended.dta", replace 

*Generate prevalence by year across ages, sexes
sort disease year measure
bys disease year measure: egen numerator_all = sum(numerator)
bys disease year measure: egen denominator_all = sum(denominator)

**Redact and round counts
replace numerator_all =. if numerator_all<=7 | denominator_all<=7
replace denominator_all =. if numerator_all<=7 | numerator_all==. | denominator_all<=7
replace numerator_all = round(numerator_all, 5)
replace denominator_all = round(denominator_all, 5)

gen ratio_all = (numerator_all/denominator_all) if (numerator_all!=. & denominator_all!=.)
replace ratio_all =. if (numerator_all==. | denominator_all==.)
gen ratio_all_100000 = ratio_all*100000

*For males
bys disease year measure: egen numerator_male = sum(numerator) if sex=="male"
bys disease year measure: egen denominator_male = sum(denominator) if sex=="male"

**Redact and round
replace numerator_male =. if numerator_male<=7 | denominator_male<=7
replace denominator_male =. if numerator_male<=7 | numerator_male==. | denominator_male<=7
replace numerator_male = round(numerator_male, 5)
replace denominator_male = round(denominator_male, 5)

gen ratio_male = (numerator_male/denominator_male) if (numerator_male!=. & denominator_male!=.)
replace ratio_male =. if (numerator_male==. | denominator_male==.)
gen ratio_male_100000 = ratio_male*100000

sort disease year measure ratio_male_100000 
by disease year measure (ratio_male_100000): replace ratio_male_100000 = ratio_male_100000[_n-1] if missing(ratio_male_100000)
sort disease year measure numerator_male 
by disease year measure (numerator_male): replace numerator_male = numerator_male[_n-1] if missing(numerator_male)
sort disease year measure denominator_male 
by disease year measure (denominator_male): replace denominator_male = denominator_male[_n-1] if missing(denominator_male)

*For females
bys disease year measure: egen numerator_female = sum(numerator) if sex=="female"
bys disease year measure: egen denominator_female = sum(denominator) if sex=="female"

**Redact and round
replace numerator_female =. if numerator_female<=7 | denominator_female<=7
replace denominator_female =. if numerator_female<=7 | numerator_female==. | denominator_female<=7
replace numerator_female = round(numerator_female, 5)
replace denominator_female = round(denominator_female, 5)

gen ratio_female = (numerator_female/denominator_female) if (numerator_female!=. & denominator_female!=.)
replace ratio_female =. if (numerator_female==. | denominator_female==.)
gen ratio_female_100000 = ratio_female*100000

sort disease year measure ratio_female_100000 
by disease year measure (ratio_female_100000): replace ratio_female_100000 = ratio_female_100000[_n-1] if missing(ratio_female_100000)
sort disease year measure numerator_female 
by disease year measure (numerator_female): replace numerator_female = numerator_female[_n-1] if missing(numerator_female)
sort disease year measure denominator_female 
by disease year measure (denominator_female): replace denominator_female = denominator_female[_n-1] if missing(denominator_female)

/*
*For age groups
foreach var in 18_29 30_39 40_49 50_59 60_69 70_79 80 {
bys disease year measure: egen numerator_`var' = sum(numerator) if age=="age_`var'"
bys disease year measure: egen denominator_`var' = sum(denominator) if age=="age_`var'"

**Redact and round
replace numerator_`var' =. if numerator_`var'<=7 | denominator_`var'<=7
replace denominator_`var' =. if numerator_`var'<=7 | numerator_`var'==. | denominator_`var'<=7
replace numerator_`var' = round(numerator_`var', 5)
replace denominator_`var' = round(denominator_`var', 5)

gen ratio_`var' = (numerator_`var'/denominator_`var') if (numerator_`var'!=. & denominator_`var'!=.)
replace ratio_`var' =. if (numerator_`var'==. | denominator_`var'==.)
gen ratio_`var'_100000 = ratio_`var'*100000

sort disease year measure ratio_`var'_100000 
by disease year measure (ratio_`var'_100000): replace ratio_`var'_100000 = ratio_`var'_100000[_n-1] if missing(ratio_`var'_100000)
sort disease year measure numerator_`var'
by disease year measure (numerator_`var'): replace numerator_`var' = numerator_`var'[_n-1] if missing(numerator_`var')
sort disease year measure denominator_`var' 
by disease year measure (denominator_`var'): replace denominator_`var' = denominator_`var'[_n-1] if missing(denominator_`var')
}
*/

save "$projectdir/output/data/prevalence_rates_nonstandardised.dta", replace 

*Calculate age-standardised prevalence rates==============

use "$projectdir/output/data/prevalence_rates_nonstandardised.dta", clear 

*Calculate  age-standardised prevalence rates, based upon European Standard Population 2013 (from 18+; total weight 80,700)
gen prop=14200 if age=="age_18-29"
replace prop=13500 if age=="age_30_39"
replace prop=14000 if age=="age_40_49"
replace prop=13500 if age=="age_50_59"
replace prop=11500 if age=="age_60_69"
replace prop=9000 if age=="age_70_79"
replace prop=5000 if age=="age_80"

gen ratio_100000 = ratio*100000
gen new_value = prop*ratio_100000
bys disease year measure: egen sum_new_value_female=sum(new_value) if sex=="female"
gen s_rate_female = sum_new_value_female/80700
replace s_rate_female=. if ratio_female_100000==.
sort disease year measure s_rate_female 
by disease year measure (s_rate_female): replace s_rate_female = s_rate_female[_n-1] if missing(s_rate_female)
bys disease year measure: egen sum_new_value_male=sum(new_value) if sex=="male"
gen s_rate_male = sum_new_value_male/80700
replace s_rate_male=. if ratio_male_100000==.
sort disease year measure s_rate_male 
by disease year measure (s_rate_male): replace s_rate_male = s_rate_male[_n-1] if missing(s_rate_male)
bys disease year measure: egen sum_new_value_all=sum(new_value)
gen s_rate_all = sum_new_value_all/161400
replace s_rate_all=. if ratio_all_100000==.

drop new_value sum_new* prop

bys disease year: gen n=_n
keep if n==1
drop n ratio numerator denominator sex age measure_prev ratio_100000
replace measure = "Prevalence"
order disease, after(measure)
order dis_full, after(disease)

foreach var in all male female  {
	drop ratio_`var'
	rename ratio_`var'_100000 rate_`var' //unadjusted IR 
	order s_rate_`var', after(rate_`var') //age and sex-standardised IR
	format s_rate_`var' %14.4f
	format rate_`var' %14.4f
	format numerator_`var' %14.0f
	format denominator_`var' %14.0f
}

/*
foreach var in 18_29 30_39 40_49 50_59 60_69 70_79 80 {
	drop ratio_`var'
	rename ratio_`var'_100000 rate_`var'
	format rate_`var' %14.4f
	order rate_`var', after(denominator_`var')
	format numerator_`var' %14.0f
	format denominator_`var' %14.0f
}
*/

save "$projectdir/output/data/prevalence_rates_standardised.dta", replace

export delimited using "$projectdir/output/tables/prevalence_rates_rounded.csv", datafmt replace

log close	
