version 16

/*==============================================================================
DO FILE NAME:			Cleaning of GCA dataset
PROJECT:				Inflammatory Rheum OpenSAFELY project
DATE: 					20/05/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Data management for GCA cohort 
DATASETS USED:			GCA dataset definition
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

*Define list of diseases of interest
global disease "gca"
global disease_lbl = upper("$disease")

*Define comorbidities and outcomes of interest
global comorbidities "ocular aortic chd cva osteop frac pmr dm ild copd lung_ca solid_ca haem_ca depr ckd htn ccf"

*Define medications of interest
global medications "prednisolone leflunomide methotrexate_oral methotrexate_inj"

*Define study dates (passed from yaml)
global arglist studystart_date studyend_date studyfup_date
args $arglist

if $running_locally ==0 {
	foreach var of global arglist {
		local `var' : subinstr local `var' "|" " ", all
		global `var' "``var''"
		di "$`var'"
	}
}

if $running_locally ==1 {
	global studystart_date "2016-04-01"
	global studyend_date "2025-03-31"
	global studyfup_date "2025-09-30"
}

di "$studystart_date"
di "$studyend_date"
di "$studyfup_date"

*Start year, end year and number of study years (derived from above)
global base_year = year(date("$studystart_date", "YMD"))
global end_year = year(date("$studyend_date", "YMD"))
global max_year = $end_year - $base_year
di "$base_year"
di "$end_year"
di "$max_year"

set type double

set scheme plotplainblind

*Open a log file
global logdir "$projectdir/logs"
cap log close
log using "$logdir/${disease}_cleaning.log", replace

*Import dataset
import delimited "$projectdir/output/dataset_${disease}.csv", clear

*Conversion and formatting for dates====================================================*

**Convert format for variables containing dates that are in string format
ds *date*, has(type string) //check list of variables is appropriate
local string_dates `r(varlist)'

foreach var of local string_dates {
	gen double `var'_num = daily(`var', "YMD")
	quietly count if !missing(`var'_num)
	if r(N) {
		format `var'_num %td
		order `var'_num, after(`var')
		drop `var'
		rename `var'_num `var'
	}
	else {
		drop `var'_num
	}
}

**Convert format for variables containing dates that are in numeric format
ds *date*, has(type numeric) //check list of variables is appropriate
capture ds *date*, has(type numeric)
if !_rc & "`r(varlist)'" != "" {
    foreach var of varlist `r(varlist)' {
        format `var' %td
    }
}

*Keep cohort of interest====================================================*

codebook ${disease}_inc_case

**Check criteria applied in dataset definition (restricted to minimum age of 50 for GCA)
gen ${disease} = 1 if ${disease}_inc_case=="T" & ((${disease}_inc_date >= date("$studystart_date", "YMD")) & (${disease}_inc_date <= date("$studyend_date", "YMD"))) & (${disease}_age >=50 & ${disease}_age <= 110) & (sex!="") & ${disease}_pre_reg=="T" & ${disease}_alive_inc=="T"
recode ${disease} .=0
tab ${disease}, missing

keep if ${disease} == 1

**First code recorded in primary care
gen ${disease}_p = 1 if ${disease}_inc_date==${disease}_prim_date
recode ${disease}_p .=0 if ${disease} == 1
lab var ${disease}_p "First ${disease_lbl} code in primary care"
lab def ${disease}_p 0 "No" 1 "Yes"
lab val ${disease}_p ${disease}_p
tab ${disease}_p, missing

*Generate month and year of diagnosis, and define duration of follow-up post-diagnosis ===========================================================*/

gen ${disease}_year = year(${disease}_inc_date)
format ${disease}_year %ty
gen ${disease}_mon = month(${disease}_inc_date)
gen ${disease}_moyear = ym(${disease}_year, ${disease}_mon)
format ${disease}_moyear %tmMon-CCYY
generate str16 ${disease}_moyear_st = strofreal(${disease}_moyear,"%tmCCYY!mNN")
lab var ${disease}_moyear "Month/Year of Diagnosis"
lab var ${disease}_moyear_st "Month/Year of Diagnosis"

**Separate into 12-month diagnosis windows from April
gen diagnosis_year = (floor((${disease}_inc_date - date("$studystart_date", "YMD")) / 365.25) + 1) if inrange(${disease}_inc_date, date("$studystart_date", "YMD"), date("$studyend_date", "YMD"))
lab var diagnosis_year "Year of diagnosis"
forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
    local end = `start' + 1
    label define diagnosis_year_lbl `i' "April `start'-March `end'", add
}
lab val diagnosis_year diagnosis_year_lbl
tab diagnosis_year, missing

**Proportion of patients with at least 6 or 12 months of GP registration after diagnosis
foreach t in 6 12 {
	local days = int((`t'/12)*365.25)
	di `days'
	
	gen has_`t'm_fup=1 if (reg_end_date!=. & (reg_end_date >= (${disease}_inc_date + `days')) & ((${disease}_inc_date + `days') <= (date("$studyfup_date", "YMD")))) | (reg_end_date==. & ((${disease}_inc_date + `days') <= (date("$studyfup_date", "YMD"))))
	recode has_`t'm_fup .=0
	lab var has_`t'm_fup "At least `t' months of follow-up after diagnosis"
	lab def has_`t'm_fup 0 "No" 1 "Yes"
	lab val has_`t'm_fup has_`t'm_fup
	tab has_`t'm_fup
	tab ${disease}_moyear has_`t'm_fup
}
		
*Clean and label demographic and comorbidity variables ====================================*/

**Age
rename ${disease}_age age
lab var age "Age at diagnosis"
tabstat age, stat(n mean sd p50 p25 p75)

gen age_decile = age/10
lab var age_decile "Age decile at diagnosis"

***Define 10-year age bands
recode age 18/29.9999 = 1 /// 
		   30/39.9999 = 2 ///
           40/49.9999 = 3 ///
		   50/59.9999 = 4 ///
	       60/69.9999 = 5 ///
		   70/79.9999 = 6 ///
		   80/max = 7, gen(agegroup) 

label define agegroup	1 "18 to 29" ///
							2 "30 to 39" ///
							3 "40 to 49" ///
							4 "50 to 59" ///
							5 "60 to 69" ///
							6 "70 to 79" ///
							7 "80 or above", modify
						
label values agegroup agegroup
lab var agegroup "Age group"
order agegroup, after(age)
tab agegroup, missing

**Sex
rename sex sex_s
encode sex_s, gen(sex)
lab def sex 1 "Female" 2 "Male", modify
lab val sex sex
lab var sex "Sex"
drop sex_s
tab sex, missing

**Ethnicity
gen ethnicity_n = 1 if ethnicity == "White"
replace ethnicity_n = 2 if ethnicity == "Asian or Asian British"
replace ethnicity_n = 3 if ethnicity == "Black or Black British"
replace ethnicity_n = 4 if ethnicity == "Mixed"
replace ethnicity_n = 5 if ethnicity == "Chinese or Other Ethnic Groups"
replace ethnicity_n = 9 if ethnicity == "Unknown"


label define ethnicity_n	1 "White"  						///
							2 "Asian or Asian British"		///
							3 "Black or Black British"  	///
							4 "Mixed"						///
							5 "Chinese or Other Ethnic Groups" ///
							9 "Unknown", modify
							
label values ethnicity_n ethnicity_n
lab var ethnicity_n "Ethnicity"
tab ethnicity_n, missing
drop ethnicity
rename ethnicity_n ethnicity

**IMD (at time of primary diagnosis)
drop imd_quintile //latest address, rather than at diagnosis
gen imd = 1 if imd_quintile_diag == "1 (most deprived)"
replace imd = 2 if imd_quintile_diag == "2"
replace imd = 3 if imd_quintile_diag == "3"
replace imd = 4 if imd_quintile_diag == "4"
replace imd = 5 if imd_quintile_diag == "5 (least deprived)"
replace imd = 9 if imd_quintile_diag == "Unknown"

label define imd 1 "1 most deprived" 2 "2" 3 "3" 4 "4" 5 "5 least deprived" 9 "Not known", modify
label val imd imd 
lab var imd "Index of multiple deprivation"
drop imd_quintile_diag
tab imd, missing

**Practice region (at time of primary diagnosis)
replace region="Not known" if region==""
replace region="Yorkshire Humber" if region=="Yorkshire and The Humber"
encode region, gen(nuts_region)
gen region_nospace = region
replace region_nospace="SouthWest" if region=="South West"
replace region_nospace="EastMidlands" if region=="East Midlands"
replace region_nospace="East" if region=="East"
replace region_nospace="London" if region=="London"
replace region_nospace="NorthEast" if region=="North East"
replace region_nospace="NorthWest" if region=="North West"
replace region_nospace="SouthEast" if region=="South East"
replace region_nospace="WestMidlands" if region=="West Midlands"
replace region_nospace="YorkshireandTheHumber" if region=="Yorkshire Humber"
drop region
rename nuts_region region
lab var region "Region"
tab region, missing

**Body Mass Index
***Recode values that are more likely to be erroneous
replace bmi_value = . if !inrange(bmi_value, 10, 80)

***Restrict to last BMI recorded within 10 years of primary diagnosis date and aged > 16 years old
gen bmi_time = (${disease}_inc_date - bmi_date)/365.25
gen bmi_age = age - bmi_time
replace bmi_value = . if bmi_age < 16 
replace bmi_value = . if bmi_time > 10 & bmi_time !=. 
replace bmi_value = . if bmi_date == . 
replace bmi_date = . if bmi_value == . 
replace bmi_time = . if bmi_value == . 
replace bmi_age = . if bmi_value == . 

***Create BMI categories
gen bmicat = .
recode bmicat . = 1 if bmi_value < 18.5
recode bmicat . = 2 if bmi_value < 25
recode bmicat . = 3 if bmi_value < 30
recode bmicat . = 4 if bmi_value < 35
recode bmicat . = 5 if bmi_value < 40
recode bmicat . = 6 if bmi_value >= 40 & bmi_value!=.
replace bmicat = 9 if bmi_value == .

label define bmicat 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9)"		///
					3 "Overweight (25-29.9)"	///
					4 "Obese I (30-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					9 "Not known"
					
label values bmicat bmicat
lab var bmicat "BMI"
order bmicat, after (bmi_value)
drop bmi_age bmi_time
tab bmicat, missing

**Smoking status
gen smoke = 1 if smoking_status == "N"
replace smoke = 2 if smoking_status == "E"
replace smoke = 3 if smoking_status == "S"
replace smoke = 9 if smoking_status == "M"
replace smoke = 9 if smoking_status == "" 
label define smoke 1 "Never" 2 "Former" 3 "Current" 9 "Not known"
label values smoke smoke
lab var smoke "Smoking status"
drop smoking_status ever_smoked most_recent_smoking_code
tab smoke, missing

***Create non-missing 3-category variable for current smoking (assumes missing smoking is never smoking)
recode smoke 9 = 1, gen(smoke_nomiss)
order smoke_nomiss, after(smoke)
label values smoke_nomiss smoke
lab var smoke_nomiss "Smoking status"
tab smoke_nomiss, missing

**Clinical comorbidities and outcomes (Nb. not using creatinine or HBA1c values for now, just codes)
foreach comorbidity in $comorbidities {
    local lbl : subinstr local comorbidity "_" " ", all
	local lbl = strproper("`lbl'")
	di "`lbl'"
	
	***Present at baseline
	gen `comorbidity'_bl = 1 if (`comorbidity'_before_date <= ${disease}_inc_date) & `comorbidity'_before_date!=.
	recode `comorbidity'_bl .=0
	lab define `comorbidity'_bl 0 "No" 1 "Yes", modify
	lab val `comorbidity'_bl `comorbidity'_bl
	lab var `comorbidity'_bl "`lbl'"
	order `comorbidity'_bl, after(`comorbidity'_after_date)
	tab `comorbidity'_bl, missing

	***Occurs after diagnosis, irrespective of baseline status
	gen `comorbidity'_after = 1 if (`comorbidity'_after_date > ${disease}_inc_date) & `comorbidity'_after_date!=.
	recode `comorbidity'_after .=0
	lab define `comorbidity'_after 0 "No" 1 "Yes", modify
	lab var `comorbidity'_after "`lbl'"
	lab val `comorbidity'_after `comorbidity'_after
	order `comorbidity'_after, after(`comorbidity'_bl)
	tab `comorbidity'_after, missing
	
	***Occurs after diagnosis in people without comorbidity at baseline
	gen `comorbidity'_new = 1 if (`comorbidity'_after_date > ${disease}_inc_date) & `comorbidity'_after_date!=. & `comorbidity'_bl!=1
	recode `comorbidity'_new .=0
	lab define `comorbidity'_new 0 "No" 1 "Yes", modify 
	lab var `comorbidity'_new "`lbl'"
	lab val `comorbidity'_new `comorbidity'_new
	order `comorbidity'_new, after(`comorbidity'_after)
	tab `comorbidity'_new, missing
	
	***Occurs within 12m after diagnosis, irrespective of baseline status
	gen `comorbidity'_after12m = 1 if ((`comorbidity'_after_date > ${disease}_inc_date) & (`comorbidity'_after_date <= (${disease}_inc_date + 365))) & `comorbidity'_after_date!=.
	recode `comorbidity'_after12m .=0
	lab define `comorbidity'_after12m 0 "No" 1 "Yes", modify
	lab var `comorbidity'_after12m "`lbl'"
	lab val `comorbidity'_after12m `comorbidity'_after12m
	order `comorbidity'_after12m, after(`comorbidity'_bl)
	tab `comorbidity'_after12m, missing
		
	***Occurs within 12m after diagnosis in people without comorbidity at baseline
	gen `comorbidity'_new12m = 1 if ((`comorbidity'_after_date > ${disease}_inc_date) & (`comorbidity'_after_date <= (${disease}_inc_date + 365))) & `comorbidity'_after_date!=. & `comorbidity'_bl!=1
	recode `comorbidity'_new12m .=0
	lab define `comorbidity'_new12m 0 "No" 1 "Yes", modify
	lab var `comorbidity'_new12m "`lbl'"
	lab val `comorbidity'_new12m `comorbidity'_new12m
	order `comorbidity'_new12m, after(`comorbidity'_new)
	tab `comorbidity'_new12m, missing
}

***Amend comorbidity labels
local vars ///
    ocular "Ocular complications" ///
	aortic "Aortic complications" ///
	chd "Coronary heart disease" ///
	cva "Ischaemic stroke/TIA" ///
	osteop "Osteoporosis" ///
    frac "Fragility fracture" ///
	pmr "Polymyalgia rheumatica" ///
    dm "Type 2 diabetes mellitus" ///
    ild "Interstitial lung disease" ///
    copd "COPD" ///
    lung_ca "Lung cancer" ///
    solid_ca "Solid organ cancer" ///
    haem_ca "Haematological cancer" ///
    depr "Depression" ///
	ckd "Chronic kidney disease" ///
	htn "Hypertension" ///
	ccf "Heart failure"

foreach suffix in bl after new after12m new12m {
    local i = 1
    while `i' <= wordcount(`"`vars'"') {
        local var: word `i' of `vars'
        local ++i
        local label : word `i' of `vars'
        capture label variable `var'_`suffix' "`label'"
        local ++i
    }
}

**Blood tests

***Creatinine - set thresholds for plausible low and high values (amend as necessary)
local blood "creatinine"
local low 20
local high 3000

codebook `blood'_bl_value //check
tabstat `blood'_bl_value, stats(n mean sd p50 p25 p75) //check
replace `blood'_bl_value = . if !inrange(`blood'_bl_value, `low', `high')
replace `blood'_bl_value = . if `blood'_bl_date == . 
replace `blood'_bl_date = . if `blood'_bl_value == . 
codebook `blood'_bl_value //check
tabstat `blood'_bl_value, stats(n mean sd p50 p25 p75)

***Calculate eGFR
gen SCr_adj = creatinine_bl_value/88.4

gen min = .
replace min = SCr_adj/0.7 if sex==1
replace min = SCr_adj/0.9 if sex==2
replace min = min^-0.329  if sex==1
replace min = min^-0.411  if sex==2
replace min = 1 if min<1

gen max = .
replace max=SCr_adj/0.7 if sex==1
replace max=SCr_adj/0.9 if sex==2
replace max=max^-1.209
replace max=1 if max>1

gen egfr_bl_value=min*max*141
replace egfr_bl_value=egfr_bl_value*(0.993^age)
replace egfr_bl_value=egfr_bl_value*1.018 if sex==1
label var egfr_bl_value "eGFR at baseline"
drop min max SCr_adj

gen egfr_bl_date = creatinine_bl_date
format egfr_bl_date %td

***Categorise baseline eGFR into CKD stages
gen egfr_bl_cat = .
recode egfr_bl_cat . = 3 if egfr_bl_value < 30
recode egfr_bl_cat . = 2 if egfr_bl_value < 60
recode egfr_bl_cat . = 1 if egfr_bl_value < .
replace egfr_bl_cat = 9 if egfr_bl_value >= .

label define egfr_bl_cat 	1 ">=60" 		///
							2 "30-59"		///
							3 "<30"			///
							9 "Not known"
					
label val egfr_bl_cat egfr_bl_cat
lab var egfr_bl_cat "eGFR at baseline"
tab egfr_bl_cat, missing

***Categorise baseline eGFR into more granular CKD stages
gen egfr_bl_finecat = .
recode egfr_bl_finecat . = 6 if egfr_bl_value < 15
recode egfr_bl_finecat . = 5 if egfr_bl_value < 30
recode egfr_bl_finecat . = 4 if egfr_bl_value < 45
recode egfr_bl_finecat . = 3 if egfr_bl_value < 60
recode egfr_bl_finecat . = 2 if egfr_bl_value < 90
recode egfr_bl_finecat . = 1 if egfr_bl_value < .
replace egfr_bl_finecat = 9 if egfr_bl_value >= .

label define egfr_bl_finecat 	1 ">=90" 		///
								2 "60-89"		///
								3 "45-59"		///
								4 "30-44"		///
								5 "15-29"		///
								6 "<15"			///
								9 "Not known"
					
label val egfr_bl_finecat egfr_bl_finecat
lab var egfr_bl_finecat "eGFR at baseline"
tab egfr_bl_finecat, missing

***Generate baseline CKD code that combines CKD coding (stages 3-5) + eGFR (stages 3-5)
gen ckd_comb_bl = 0
replace ckd_comb_bl = 1 if egfr_bl_value != . & egfr_bl_value < 60
replace ckd_comb_bl = 1 if ckd_bl == 1
label define ckd_comb_bl 0 "No" 1 "Yes"
label val ckd_comb_bl ckd_comb_bl
label var ckd_comb_bl "Chronic kidney disease"
tab ckd_comb_bl, missing

**HbA1c

***Set thresholds for plausible low and high values (amend as necessary)
local blood "hba1c"
local low 10
local high 200

codebook `blood'_bl_value //check
tabstat `blood'_bl_value, stats(n mean sd p50 p25 p75) //check
replace `blood'_bl_value = . if !inrange(`blood'_bl_value, `low', `high')
replace `blood'_bl_value = . if `blood'_bl_date == . 
replace `blood'_bl_date = . if `blood'_bl_value == . 
codebook `blood'_bl_value //check
tabstat `blood'_bl_value, stats(n mean sd p50 p25 p75)

***Categorise HbA1c at baseline
gen hba1c_bl_cat = 0 if hba1c_bl_value < 58
replace hba1c_bl_cat = 1 if hba1c_bl_value >= 58 & hba1c_bl_val !=.
replace hba1c_bl_cat = 9 if hba1c_bl_cat ==. 
label define hba1c_bl_cat 0 "HbA1c <58mmol/mol" 1 "HbA1c >=58mmol/mol" 9 "Not known"
label val hba1c_bl_cat hba1c_bl_cat
lab var hba1c_bl_cat "HbA1c at baseline"
tab hba1c_bl_cat, missing

***Create combined diabetes code that combines diabetes coding + HBA1c
gen diab_bl_cat = 1 if dm_bl==0
replace diab_bl_cat = 2 if dm_bl==1 & hba1c_bl_cat==0
replace diab_bl_cat = 3 if dm_bl==1 & hba1c_bl_cat==1
replace diab_bl_cat = 4 if dm_bl==1 & hba1c_bl_cat==9

label define diab_bl_cat 1 "No diabetes" 			///
						2 "Diabetes with HbA1c <58mmol/mol"		///
						3 "Diabetes with HbA1c >58mmol/mol" 	///
						4 "Diabetes with no recorded HbA1c"
label values diab_bl_cat diab_bl_cat
lab var diab_bl_cat "Type 2 diabetes mellitus with HbA1c categorisation"
tab diab_bl_cat, missing

save "$projectdir/output/data/cohort_generic.dta", replace

*Check first rheum appt date==================================*/

use "$projectdir/output/data/cohort_generic.dta", clear

gen rheum_appt = 1 if rheum_appt_date!=. 
recode rheum_appt .=0
lab def rheum_appt 0 "No" 1 "Yes"
lab val rheum_appt rheum_appt
lab var rheum_appt "First rheumatology appointment within 12 months before or after diagnosis"

gen rheum_appt_any = 1 if rheum_appt_any_date!=. 
recode rheum_appt_any .=0
lab def rheum_appt_any 0 "No" 1 "Yes"
lab val rheum_appt_any rheum_appt_any
lab var rheum_appt_any "Any rheumatology appointment within 12 months before or after diagnosis"

tab rheum_appt, missing //proportion of patients with an rheum outpatient date (with first attendance option selected) in the 12 months before or after after diagnosis code appeared in GP record; data only April 2019 onwards
tab rheum_appt if rheum_appt_date<=${disease}_inc_date & rheum_appt_date!=. //confirm proportion who had first rheum appt (i.e. not missing) before diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date - 30) & rheum_appt_date!=. //confirm proportion who had first rheum appt within 30 days before diagnosis code 
tab rheum_appt if rheum_appt_date>(${disease}_inc_date - 60) & rheum_appt_date!=. //confirm proportion who had first rheum appt within 60 days before diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date - 120) & rheum_appt_date!=. //confirm proportion who had first rheum appt within 120 days before diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date - 180) & rheum_appt_date!=. //confirm proportion who had first rheum appt within 180 days before diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date - 365) & rheum_appt_date!=. //confirm proportion who had first rheum appt within 365 days before diagnosis code

tab rheum_appt if rheum_appt_date>${disease}_inc_date & rheum_appt_date!=. //confirm proportion who had first rheum appt (i.e. not missing) after diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date + 30) & rheum_appt_date!=. //confirm proportion who had first rheum appt 30 days after diagnosis code 
tab rheum_appt if rheum_appt_date>(${disease}_inc_date + 60) & rheum_appt_date!=. //confirm proportion who had first rheum appt 60 days after diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date + 120) & rheum_appt_date!=. //confirm proportion who had first rheum appt 120 days after diagnosis code
tab rheum_appt if rheum_appt_date>(${disease}_inc_date + 180) & rheum_appt_date!=. //confirm proportion who had first rheum appt 180 days after diagnosis code

tab rheum_appt_any, missing //proportion of patients with a rheum outpatient date (without first attendance option selected) in the 12 months before or after diagnosis code appeared in GP record; data only April 2019 onwards
tab rheum_appt_any if rheum_appt_any_date<=${disease}_inc_date & rheum_appt_any_date!=. //confirm proportion who had first rheum appt (i.e. not missing) before diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date - 30) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt within 30 days before diagnosis code 
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date - 60) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt within 60 days before diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date - 120) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt within 120 days before diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date - 180) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt within 180 days before diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date - 365) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt within 365 days before diagnosis code

tab rheum_appt_any if rheum_appt_any_date>${disease}_inc_date & rheum_appt_any_date!=. //confirm proportion who had first rheum appt (i.e. not missing) after diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date + 30) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 30 days after diagnosis code 
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date + 60) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 60 days after diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date + 120) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 120 days after diagnosis code
tab rheum_appt_any if rheum_appt_any_date>(${disease}_inc_date + 180) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 180 days after diagnosis code

**Month/year of first rheum appt
gen year_appt=year(rheum_appt_date) if rheum_appt_date!=.
format year_appt %ty
gen month_appt=month(rheum_appt_date) if rheum_appt_date!=. 
gen mo_year_appt=ym(year_appt, month_appt)
format mo_year_appt %tmMon-CCYY
generate str16 mo_year_appt_s = strofreal(mo_year_appt,"%tmCCYY!mNN")

*Check rheumatology referrals======================================*/

**From clinical referral codes (requires rheum appt to have been present)
gen ref_12m_preappt = 1 if ref_12m_preappt_date!=. 
recode ref_12m_preappt .=0
lab def ref_12m_preappt 0 "No" 1 "Yes"
lab val ref_12m_preappt ref_12m_preappt
lab var ref_12m_preappt "Last rheum referral code in the year before first rheumatology outpatient appt"
tab ref_12m_preappt, missing 
tab ref_12m_preappt if rheum_appt==1, missing

**From HES OPA (referral_request_received_date) with first attendance flag
gen rheum_appt_ref = 1 if rheum_appt_ref_date!=. 
recode rheum_appt_ref .=0
lab def rheum_appt_ref 0 "No" 1 "Yes"
lab val rheum_appt_ref rheum_appt_ref
lab var rheum_appt_ref "Rheum referral received date from HES OPA"
tab rheum_appt_ref, missing
tab rheum_appt_ref if rheum_appt==1, missing
codebook rheum_appt_ref_date
tab ${disease}_moyear rheum_appt_ref, missing
tab ${disease}_moyear rheum_appt_ref if rheum_appt==1, missing

**Difference between referral ordered date (SNOMED code date) and referral request received date (HES)
tab ref_12m_preappt rheum_appt_ref if rheum_appt==1, missing
gen delta_referral = rheum_appt_ref_date - ref_12m_preappt_date if ref_12m_preappt_date!=. & rheum_appt_ref_date!=.
tabstat delta_referral, stat(n mean sd p50 p25 p75)
tabstat delta_referral if rheum_appt==1, stat(n mean sd p50 p25 p75)

**From HES OPA (referral_request_received_date) without first attendance flag
gen rheum_any_ref = 1 if rheum_any_ref_date!=. 
recode rheum_any_ref .=0
lab def rheum_any_ref 0 "No" 1 "Yes"
lab val rheum_any_ref rheum_any_ref
lab var rheum_any_ref "Rheum referral received date from HES OPA"
tab rheum_any_ref, missing
tab rheum_any_ref if rheum_appt==1, missing

**Difference between referral ordered date (SNOMED code date) and referral request received date (HES)
gen delta_referral_any = rheum_appt_any_date - ref_12m_preappt_date if ref_12m_preappt_date!=. & rheum_appt_any_date!=.
tabstat delta_referral_any, stat(n mean sd p50 p25 p75)
tabstat delta_referral_any if rheum_appt_any==1, stat(n mean sd p50 p25 p75)

*Number and medium of rheumatology appointments ======================================*/

**Check number of rheumatology appts in the year after first rheumatology outpatient appointment
tabstat rheum_appt_count, stat (n mean sd p50 p25 p75)
bys diagnosis_year: tabstat rheum_appt_count, stat (n mean sd p50 p25 p75)

**Check medium used for rheumatology appointment
codebook rheum_appt_medium
tab rheum_appt_medium, missing
gen rheum_appt_medium_clean = rheum_appt_medium if rheum_appt_medium >0 & rheum_appt_medium<100
recode rheum_appt_medium_clean 3=2 //recode telemedicine=telephone
replace rheum_appt_medium_clean=10 if rheum_appt_medium_clean>2 & rheum_appt_medium_clean!=.
lab define rheum_appt_medium_clean 1 "Face-to-face" 2 "Telephone" 10 "Other", modify
lab val rheum_appt_medium_clean rheum_appt_medium_clean
lab var rheum_appt_medium_clean "Rheumatology consultation medium"
tab rheum_appt_medium_clean
tab rheum_appt_medium_clean, missing 

*Time to rheum appointment using clinical code for referral=============================================*/

**Time from referral to rheum appt using HES OPA rheum ref to rheum appt
gen time_hes_rheum_appt = (rheum_appt_date - rheum_appt_ref_date) if rheum_appt_date!=. & rheum_appt_ref_date!=. & (rheum_appt_ref_date<=rheum_appt_date)
tabstat time_hes_rheum_appt, stats (n mean p50 p25 p75)

**Using working days
workdays rheum_appt_ref_date rheum_appt_date if rheum_appt_date!=. & rheum_appt_ref_date!=. & (rheum_appt_ref_date<=rheum_appt_date), gen(wd_hes_rheum_appt)
tabstat wd_hes_rheum_appt, stats (n mean p50 p25 p75)

**Time from referral to rheum appt using HES OPA rheum ref to rheum appt (without first attendance)
gen time_hes_any_appt = (rheum_appt_any_date - rheum_any_ref_date) if rheum_appt_any_date!=. & rheum_any_ref_date!=. & (rheum_any_ref_date<=rheum_appt_any_date)
tabstat time_hes_any_appt, stats (n mean p50 p25 p75)

**Using working days
workdays rheum_any_ref_date rheum_appt_any_date if rheum_appt_any_date!=. & rheum_any_ref_date!=. & (rheum_any_ref_date<=rheum_appt_any_date), gen(wd_hes_any_appt)
tabstat wd_hes_any_appt, stats (n mean p50 p25 p75)

**Time from referral to rheum appt using 12m referral cut-off (using SNOMED referral code)
gen time_ref_rheum_appt = (rheum_appt_date - ref_12m_preappt_date) if rheum_appt_date!=. & ref_12m_preappt_date!=. & (ref_12m_preappt_date<=rheum_appt_date)
tabstat time_ref_rheum_appt, stats (n mean p50 p25 p75)

**Using working days
workdays ref_12m_preappt_date rheum_appt_date if rheum_appt_date!=. & ref_12m_preappt_date!=. & (ref_12m_preappt_date<=rheum_appt_date), gen(wd_ref_rheum_appt)
tabstat wd_ref_rheum_appt, stats (n mean p50 p25 p75)

*Time to diagnosis code==================================================*/

**Time from rheum ref to diagnosis code using SNOMED code (Nb. could be after diagnosis code)
gen time_rheum_appt_code = (${disease}_inc_date - rheum_appt_date) if rheum_appt_date!=. 
tabstat time_rheum_appt_code, stats (n mean p50 p25 p75)

*Medication use in primary care==================================================*/

***REMOVE LATER
rename leflunomide_date leflunomide_first_date
rename methotrexate_oral_date methotrexate_oral_first_date
rename methotrexate_inj_date methotrexate_inj_first_date
rename lef_last_date leflunomide_last_date
rename mtx_oral_last_date methotrexate_oral_last_date
rename mtx_inj_last_date methotrexate_inj_last_date

foreach medication in $medications {
    local lbl : subinstr local medication "_" " ", all
	local lbl = strproper("`lbl'")
	di "`lbl'"
	
	**Ever prescribed (from 90 days before to study end date)
	gen `medication'_ever = 1 if `medication'_first_date!=.
	recode `medication'_ever .=0
	lab define `medication'_ever 0 "No" 1 "Yes", modify
	lab val `medication'_ever `medication'_ever
	lab var `medication'_ever "`lbl' ever prescribed"
	tab `medication'_ever, missing
	
	**Prescribed within 90 days before diagnosis
	gen `medication'_bl = 1 if (`medication'_first_date < ${disease}_inc_date) & `medication'_first_date!=.
	recode `medication'_bl .=0
	lab define `medication'_bl 0 "No" 1 "Yes", modify
	lab val `medication'_bl `medication'_bl
	lab var `medication'_bl "`lbl' prescribed within 90 days before diagnosis"
	tab `medication'_bl, missing
	
	**Prescribed from 90 days before to 1 year after diagnosis
	gen `medication'_12m = 1 if (`medication'_first_date <= (${disease}_inc_date + 365)) & `medication'_first_date!=.
	recode `medication'_12m .=0
	lab define `medication'_12m 0 "No" 1 "Yes", modify
	lab val `medication'_12m `medication'_12m
	lab var `medication'_12m "`lbl' prescribed within 1 year of diagnosis"
	tab `medication'_12m, missing
	
	**Time to first prescription in primary care (from -90 days onwards)
	gen time_to_`medication' = (`medication'_first_date - ${disease}_inc_date) if `medication'_first_date!=.
	tabstat time_to_`medication', stats (n mean p50 p25 p75)

	gen time_to_`medication'_cat = 1 if time_to_`medication'>=-90 & time_to_`medication'<0
	replace time_to_`medication'_cat = 2 if time_to_`medication'>=0 & time_to_`medication'<30
	replace time_to_`medication'_cat = 3 if time_to_`medication'>=30 & time_to_`medication'<183
	replace time_to_`medication'_cat = 4 if time_to_`medication'>=183 & time_to_`medication'<365
	replace time_to_`medication'_cat = 5 if time_to_`medication'>=365 & time_to_`medication'!=.
	replace time_to_`medication'_cat = 6 if time_to_`medication'==.

	lab define time_to_`medication'_cat 1 "Up to 90 days before diagnosis" 2 "Up to 30 days after diagnosis" 3 "Between 30 days and 6m after diagnosis" 4 "Between 6m and 12m after diagnosis" 5 "More than 12m after diagnosis" 6 "No `medication' prescription"
	lab val time_to_`medication'_cat time_to_`medication'_cat
	lab var time_to_`medication'_cat "Timing of first `medication' prescription in primary care"
	tab time_to_`medication'_cat, missing
}

save "$projectdir/output/data/${disease}_processed.dta", replace

log close
