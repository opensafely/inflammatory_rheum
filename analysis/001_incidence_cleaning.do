version 16

/*==============================================================================
DO FILE NAME:			Incidence cleaning
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
log using "$logdir/incidence_cleaning.log", replace

*Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Set disease list
global diseases "eia ctd vasc ctdvasc rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"
*global diseases "ctd"

set type double

set scheme plotplainblind

*Import dataset
import delimited "$projectdir/output/dataset_incidence.csv", clear

*Can remove this once python confirmed - Keep only patients with one or more incident diagnoses ==============================
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

	label define `disease'_age_band		1 "18 to 29" ///
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
	
	**Replace years as April-April
	rename `disease'_year `disease'_year_old
	gen `disease'_year = `disease'_year_old
	replace `disease'_year = `disease'_year_old - 1 if inlist(month(dofm(`disease'_moyear)),1,2,3)
}

**Gen incident disease cohorts by sex
foreach disease in $diseases {
	gen `disease'_female = 1 if `disease'==1 & sex==1
	recode `disease'_female .=0
	gen `disease'_male = 1 if `disease'==1 & sex==2
	recode `disease'_male .=0
}

**Gen incident disease cohorts by sex and age group
foreach disease in $diseases {
	gen `disease'_f_18_29 = 1 if `disease'==1 & sex==1 & `disease'_age_band==1
	gen `disease'_m_18_29 = 1 if `disease'==1 & sex==2 & `disease'_age_band==1
	gen `disease'_f_30_39 = 1 if `disease'==1 & sex==1 & `disease'_age_band==2
	gen `disease'_m_30_39 = 1 if `disease'==1 & sex==2 & `disease'_age_band==2
	gen `disease'_f_40_49 = 1 if `disease'==1 & sex==1 & `disease'_age_band==3
	gen `disease'_m_40_49 = 1 if `disease'==1 & sex==2 & `disease'_age_band==3
	gen `disease'_f_50_59 = 1 if `disease'==1 & sex==1 & `disease'_age_band==4
	gen `disease'_m_50_59 = 1 if `disease'==1 & sex==2 & `disease'_age_band==4
	gen `disease'_f_60_69 = 1 if `disease'==1 & sex==1 & `disease'_age_band==5
	gen `disease'_m_60_69 = 1 if `disease'==1 & sex==2 & `disease'_age_band==5
	gen `disease'_f_70_79 = 1 if `disease'==1 & sex==1 & `disease'_age_band==6
	gen `disease'_m_70_79 = 1 if `disease'==1 & sex==2 & `disease'_age_band==6
	gen `disease'_f_80 = 1 if `disease'==1 & sex==1 & `disease'_age_band==7
	gen `disease'_m_80 = 1 if `disease'==1 & sex==2 & `disease'_age_band==7
}

save "$projectdir/output/data/incidence_data_processed.dta", replace

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

**Replace years as April-April
rename year year_old
gen year = year_old
replace year = year_old - 1 if inlist(month(dofm(mo_year_diagn)),1,2,3)

rename sex sex_s
gen sex = 1 if sex_s == "female"
replace sex = 2 if sex_s == "male"
lab var sex "Sex"
lab define sex 1 "Female" 2 "Male", modify
lab val sex sex
tab sex, missing

encode age, gen(age_band)
label define age_band	1 "18 to 29" ///
						2 "30 to 39" ///
						3 "40 to 49" ///
						4 "50 to 59" ///
						5 "60 to 69" ///
						6 "70 to 79" ///
						7 "80 or above", modify
lab val age_band age_band

drop sex_s age year_old

rename numerator numerator_un 
rename denominator denominator_un 

preserve
keep if measure == "population_bands"
collapse (sum) numerator denominator, by(sex age_band year)
drop if age_band==.
keep if sex == 1 | sex == 2
save "$projectdir/output/data/measures_appended_age_sex.dta", replace
restore 

**Round numbers
gen numerator = round(numerator_un, 5)
gen denominator = round(denominator_un, 5)
gen rate = numerator/denominator

*Overall denominator
keep if measure == "population_overall"
drop age* sex* measure rate numerator_un denominator_un ratio
export delimited using "$projectdir/output/tables/denominator_counts.csv", datafmt replace
save "$projectdir/output/data/measures_appended.dta", replace 

*Incidence rates diagnoses by month, by disease; not age/sex-standardised =================================================*/

clear *
save "$projectdir/output/data/incidence_rates_rounded.dta", replace emptyok

use "$projectdir/output/data/incidence_data_processed.dta", clear

*Create rounded/redacted incidence rates diagnoses by month, by disease
foreach disease in $diseases {
	preserve
	keep if `disease'==1
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
	drop denominator
	rename numerator denominator
	rename total_diag numerator
	order year, after(mo_year_diagn)
	order disease, first
	
	gen dis_full = disease
	replace dis_full = "Rheumatoid_Arthritis" if dis_full == "Rheumatoid"
	replace dis_full = "Early inflammatory arthritis" if dis_full == "Eia"
	replace dis_full = "Psoriatic arthritis" if dis_full == "Psa"
	replace dis_full = "Axial spondyloarthritis" if dis_full == "Axialspa"
	replace dis_full = "Undifferentiated IA" if dis_full == "Undiffia"
	replace dis_full = "Giant cell arteritis" if dis_full == "Gca"
	replace dis_full = "Sjogren's disease" if dis_full == "Sjogren"
	replace dis_full = "Systemic sclerosis" if dis_full == "Ssc"
	replace dis_full = "SLE" if dis_full == "Sle"
	replace dis_full = "Myositis" if dis_full == "Myositis"
	replace dis_full = "ANCA vasculitis" if dis_full == "Anca"
	replace dis_full = "Connective tissue disease" if dis_full == "Ctd"
	replace dis_full = "Vasculitis" if dis_full == "Vasc"
	replace dis_full = "CTD/vasculitis" if dis_full == "Ctdvasc"
	order dis_full, after(disease)
		
	**Gen incidence rate per 100,000 adult population	
	gen incidence = (numerator/denominator)*100000

	**Output to appended dta
	append using "$projectdir/output/data/incidence_rates_rounded.dta"
	save "$projectdir/output/data/incidence_rates_rounded.dta", replace  
	
	restore
}

use "$projectdir/output/data/incidence_rates_rounded.dta", clear
export delimited using "$projectdir/output/tables/incidence_rates_rounded.csv", datafmt replace

*Age/sex-standardised incidence rates diagnoses by year, by disease=================================*/

clear *
save "$projectdir/output/data/incidence_rates_rounded_standardised.dta", replace emptyok

use "$projectdir/output/data/incidence_data_processed.dta", clear

foreach disease in $diseases {
	preserve
	keep if `disease'==1
	collapse (count) total_diag_un=`disease', by(sex `disease'_age_band `disease'_year) 
	gen disease = strproper(subinstr("`disease'", "_", " ",.))
	rename `disease'_year year
	rename `disease'_age_band age_band

	**Import denominators
	merge 1:1 year age_band sex using "$projectdir/output/data/measures_appended_age_sex.dta", keep(match) nogen
	
	**Drop unnecessary variables
	drop denominator
	order disease, first
	rename numerator denominator_un
	rename total_diag_un numerator_un
	order year, after(disease)
	
	gen rate_un = (numerator_un/denominator_un)*100000
	
	**Non-standardised incidence rate per 100,000 population overall
	sort disease year
	bys disease year: egen numerator_all = sum(numerator_un)
	bys disease year: egen denominator_all = sum(denominator_un)

	**Redact and round counts and rates
	replace numerator_all =. if numerator_all<=7 | denominator_all<=7
	replace denominator_all =. if numerator_all<=7 | numerator_all==. | denominator_all<=7
	replace numerator_all = round(numerator_all, 5)
	replace denominator_all = round(denominator_all, 5)

	gen rate_all = (numerator_all/denominator_all) if (numerator_all!=. & denominator_all!=.)
	replace rate_all =. if (numerator_all==. | denominator_all==.)
	replace rate_all = rate_all*100000
	
	**For females
	bys disease year: egen numerator_female = sum(numerator_un) if sex==1
	bys disease year: egen denominator_female = sum(denominator_un) if sex==1

	**Redact and round counts and rates
	replace numerator_female =. if numerator_female<=7 | denominator_female<=7
	replace denominator_female =. if numerator_female<=7 | numerator_female==. | denominator_female<=7
	replace numerator_female = round(numerator_female, 5)
	replace denominator_female = round(denominator_female, 5)

	gen rate_female = (numerator_female/denominator_female) if (numerator_female!=. & denominator_female!=.)
	replace rate_female =. if (numerator_female==. | denominator_female==.)
	replace rate_female = rate_female*100000
	
	sort disease year rate_female 
	by disease year (rate_female): replace rate_female = rate_female[_n-1] if missing(rate_female)
	sort disease year numerator_female 
	by disease year (numerator_female): replace numerator_female = numerator_female[_n-1] if missing(numerator_female)
	sort disease year denominator_female 
	by disease year (denominator_female): replace denominator_female = denominator_female[_n-1] if missing(denominator_female)
	
	**For males
	bys disease year: egen numerator_male = sum(numerator_un) if sex==2
	bys disease year: egen denominator_male = sum(denominator_un) if sex==2

	**Redact and round counts and rates
	replace numerator_male =. if numerator_male<=7 | denominator_male<=7
	replace denominator_male =. if numerator_male<=7 | numerator_male==. | denominator_male<=7
	replace numerator_male = round(numerator_male, 5)
	replace denominator_male = round(denominator_male, 5)

	gen rate_male = (numerator_male/denominator_male) if (numerator_male!=. & denominator_male!=.)
	replace rate_male =. if (numerator_male==. | denominator_male==.)
	replace rate_male = rate_male*100000
	
	sort disease year rate_male 
	by disease year (rate_male): replace rate_male = rate_male[_n-1] if missing(rate_male)
	sort disease year numerator_male 
	by disease year (numerator_male): replace numerator_male = numerator_male[_n-1] if missing(numerator_male)
	sort disease year denominator_male 
	by disease year (denominator_male): replace denominator_male = denominator_male[_n-1] if missing(denominator_male)
	
	*For age band
	decode age_band, gen(age_band_s)
	order age_band_s, after(age_band)
	replace age_band_s = "18_29" if age_band_s == "18 to 29"
	replace age_band_s = "30_39" if age_band_s == "30 to 39"
	replace age_band_s = "40_49" if age_band_s == "40 to 49"
	replace age_band_s = "50_59" if age_band_s == "50 to 59"
	replace age_band_s = "60_69" if age_band_s == "60 to 69"
	replace age_band_s = "70_79" if age_band_s == "70 to 79"
	replace age_band_s = "80" if age_band_s == "80 or above"
	
	foreach var in 18_29 30_39 40_49 50_59 60_69 70_79 80 {
		bys disease year: egen numerator_`var' = sum(numerator_un) if age_band_s=="`var'"
		bys disease year: egen denominator_`var' = sum(denominator_un) if age_band_s=="`var'"

		**Redact and round
		replace numerator_`var' =. if numerator_`var'<=7 | denominator_`var'<=7
		replace denominator_`var' =. if numerator_`var'<=7 | numerator_`var'==. | denominator_`var'<=7
		replace numerator_`var' = round(numerator_`var', 5)
		replace denominator_`var' = round(denominator_`var', 5)

		gen rate_`var' = (numerator_`var'/denominator_`var') if (numerator_`var'!=. & denominator_`var'!=.)
		replace rate_`var' =. if (numerator_`var'==. | denominator_`var'==.)
		replace rate_`var' = rate_`var'*100000

		sort disease year rate_`var' 
		by disease year (rate_`var'): replace rate_`var' = rate_`var'[_n-1] if missing(rate_`var')
		sort disease year numerator_`var'
		by disease year (numerator_`var'): replace numerator_`var' = numerator_`var'[_n-1] if missing(numerator_`var')
		sort disease year denominator_`var' 
		by disease year (denominator_`var'): replace denominator_`var' = denominator_`var'[_n-1] if missing(denominator_`var')
	}
/*
	*For ethnicity
	bys disease year: egen numerator_white = sum(numerator) if ethnicity=="White"
	bys disease year: egen denominator_white = sum(denominator) if ethnicity=="White"

	bys disease year: egen numerator_mixed = sum(numerator) if ethnicity=="Mixed"
	bys disease year: egen denominator_mixed = sum(denominator) if ethnicity=="Mixed"

	bys disease year: egen numerator_black = sum(numerator) if ethnicity=="Black or Black British"
	bys disease year: egen denominator_black = sum(denominator) if ethnicity=="Black or Black British"

	bys disease year: egen numerator_asian = sum(numerator) if ethnicity=="Asian or Asian British"
	bys disease year: egen denominator_asian = sum(denominator) if ethnicity=="Asian or Asian British"

	bys disease year: egen numerator_other = sum(numerator) if ethnicity=="Chinese or Other Ethnic Groups"
	bys disease year: egen denominator_other = sum(denominator) if ethnicity=="Chinese or Other Ethnic Groups"

	bys disease year: egen numerator_ethunk = sum(numerator) if ethnicity=="Unknown"
	bys disease year: egen denominator_ethunk = sum(denominator) if ethnicity=="Unknown"

	**Redact and round
	foreach var in white mixed black asian other ethunk {
	replace numerator_`var' =. if numerator_`var'<=7 | denominator_`var'<=7
	replace denominator_`var' =. if numerator_`var'<=7 | numerator_`var'==. | denominator_`var'<=7
	replace numerator_`var' = round(numerator_`var', 5)
	replace denominator_`var' = round(denominator_`var', 5)

	gen ratio_`var' = (numerator_`var'/denominator_`var') if (numerator_`var'!=. & denominator_`var'!=.)
	replace ratio_`var' =. if (numerator_`var'==. | denominator_`var'==.)
	gen ratio_`var'_100000 = ratio_`var'*100000

	sort disease mo_year_diagn measure_prev measure_inc_any ratio_`var'_100000 
	by disease mo_year_diagn measure_prev measure_inc_any (ratio_`var'_100000): replace ratio_`var'_100000 = ratio_`var'_100000[_n-1] if missing(ratio_`var'_100000)
	sort disease mo_year_diagn measure_prev measure_inc_any numerator_`var'
	by disease mo_year_diagn measure_prev measure_inc_any (numerator_`var'): replace numerator_`var' = numerator_`var'[_n-1] if missing(numerator_`var')
	sort disease mo_year_diagn measure_prev measure_inc_any denominator_`var' 
	by disease mo_year_diagn measure_prev measure_inc_any (denominator_`var'): replace denominator_`var' = denominator_`var'[_n-1] if missing(denominator_`var')
	}

	*For IMD
	bys disease mo_year_diagn measure: egen numerator_imd1 = sum(numerator) if imd=="1 (most deprived)"
	bys disease mo_year_diagn measure: egen denominator_imd1 = sum(denominator) if imd=="1 (most deprived)"

	bys disease mo_year_diagn measure: egen numerator_imd2 = sum(numerator) if imd=="2"
	bys disease mo_year_diagn measure: egen denominator_imd2 = sum(denominator) if imd=="2"

	bys disease mo_year_diagn measure: egen numerator_imd3 = sum(numerator) if imd=="3"
	bys disease mo_year_diagn measure: egen denominator_imd3 = sum(denominator) if imd=="3"

	bys disease mo_year_diagn measure: egen numerator_imd4 = sum(numerator) if imd=="4"
	bys disease mo_year_diagn measure: egen denominator_imd4 = sum(denominator) if imd=="4"

	bys disease mo_year_diagn measure: egen numerator_imd5 = sum(numerator) if imd=="5 (least deprived)"
	bys disease mo_year_diagn measure: egen denominator_imd5 = sum(denominator) if imd=="5 (least deprived)"

	bys disease mo_year_diagn measure: egen numerator_imdunk = sum(numerator) if imd=="Unknown"
	bys disease mo_year_diagn measure: egen denominator_imdunk = sum(denominator) if imd=="Unknown"

	**Redact and round
	foreach var in imd1 imd2 imd3 imd4 imd5 imdunk {
	replace numerator_`var' =. if numerator_`var'<=7 | denominator_`var'<=7
	replace denominator_`var' =. if numerator_`var'<=7 | numerator_`var'==. | denominator_`var'<=7
	replace numerator_`var' = round(numerator_`var', 5)
	replace denominator_`var' = round(denominator_`var', 5)

	gen ratio_`var' = (numerator_`var'/denominator_`var') if (numerator_`var'!=. & denominator_`var'!=.)
	replace ratio_`var' =. if (numerator_`var'==. | denominator_`var'==.)
	gen ratio_`var'_100000 = ratio_`var'*100000

	sort disease mo_year_diagn measure_prev measure_inc_any ratio_`var'_100000 
	by disease mo_year_diagn measure_prev measure_inc_any (ratio_`var'_100000): replace ratio_`var'_100000 = ratio_`var'_100000[_n-1] if missing(ratio_`var'_100000)
	sort disease mo_year_diagn measure_prev measure_inc_any numerator_`var'
	by disease mo_year_diagn measure_prev measure_inc_any (numerator_`var'): replace numerator_`var' = numerator_`var'[_n-1] if missing(numerator_`var')
	sort disease mo_year_diagn measure_prev measure_inc_any denominator_`var' 
	by disease mo_year_diagn measure_prev measure_inc_any (denominator_`var'): replace denominator_`var' = denominator_`var'[_n-1] if missing(denominator_`var')
	}
*/
	
	*Calculate  age-standardized incidence rates, based upon European Standard Population 2013 (from 18+; total weight 80,700)
	gen prop=14200 if age_band==1 //for 18-29 age band
	replace prop=13500 if age_band==2
	replace prop=14000 if age_band==3
	replace prop=13500 if age_band==4
	replace prop=11500 if age_band==5
	replace prop=9000 if age_band==6
	replace prop=5000 if age_band==7
	
	gen new_value = prop*rate_un
	bys disease year: egen sum_new_value_female=sum(new_value) if sex==1
	gen s_rate_female = sum_new_value_female/80700
	replace s_rate_female=. if rate_female==.
	sort disease year s_rate_female 
	by disease year (s_rate_female): replace s_rate_female = s_rate_female[_n-1] if missing(s_rate_female)
	bys disease year: egen sum_new_value_male=sum(new_value) if sex==2
	gen s_rate_male = sum_new_value_male/80700
	replace s_rate_male=. if rate_male==.
	sort disease year s_rate_male 
	by disease year (s_rate_male): replace s_rate_male = s_rate_male[_n-1] if missing(s_rate_male)
	bys disease year: egen sum_new_value_all=sum(new_value)
	gen s_rate_all = sum_new_value_all/161400
	replace s_rate_all=. if rate_all==.

	drop new_value sum_new* prop numerator_un denominator_un rate_un age_band_s
	
	bys disease year: gen n=_n
	keep if n==1
	drop sex age_band n
	
	foreach var in all male female  {
		order s_rate_`var', after(rate_`var')
		format s_rate_`var' %14.4f
		format rate_`var' %14.4f
		format numerator_`var' %14.0f
		format denominator_`var' %14.0f
	}

	foreach var in 18_29 30_39 40_49 50_59 60_69 70_79 80 {
		format rate_`var' %14.4f
		order rate_`var', after(denominator_`var')
		format numerator_`var' %14.0f
		format denominator_`var' %14.0f
	}
	
	gen dis_full = disease
	replace dis_full = "Rheumatoid_Arthritis" if dis_full == "Rheumatoid"
	replace dis_full = "Early inflammatory arthritis" if dis_full == "Eia"
	replace dis_full = "Psoriatic arthritis" if dis_full == "Psa"
	replace dis_full = "Axial spondyloarthritis" if dis_full == "Axialspa"
	replace dis_full = "Undifferentiated IA" if dis_full == "Undiffia"
	replace dis_full = "Giant cell arteritis" if dis_full == "Gca"
	replace dis_full = "Sjogren's disease" if dis_full == "Sjogren"
	replace dis_full = "Systemic sclerosis" if dis_full == "Ssc"
	replace dis_full = "SLE" if dis_full == "Sle"
	replace dis_full = "Myositis" if dis_full == "Myositis"
	replace dis_full = "ANCA vasculitis" if dis_full == "Anca"
	replace dis_full = "Connective tissue disease" if dis_full == "Ctd"
	replace dis_full = "Vasculitis" if dis_full == "Vasc"
	replace dis_full = "CTD/vasculitis" if dis_full == "Ctdvasc"
	order dis_full, after(disease)
	
	**Output to appended dta
	append using "$projectdir/output/data/incidence_rates_rounded_standardised.dta"
	save "$projectdir/output/data/incidence_rates_rounded_standardised.dta", replace  
	
	restore
}

use "$projectdir/output/data/incidence_rates_rounded_standardised.dta", clear
export delimited using "$projectdir/output/tables/incidence_rates_rounded_standardised.csv", datafmt replace

log close	
