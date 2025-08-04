version 16

/*==============================================================================
DO FILE NAME:			define covariates using dataset definition
PROJECT:				Inflammatory Rheum OpenSAFELY project
DATE: 					20/05/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	data management for inflammatory rheum project  
						reformat variables 
						categorise variables
						label variables 
DATASETS USED:			data in memory (from output/dataset.csv)
DATASETS CREATED: 		analysis files
OTHER OUTPUT: 			logfiles, printed to folder $Logdir
USER-INSTALLED ADO: 	 
  (place .ado file(s) in analysis folder)						
==============================================================================*/

**Set filepaths
*global projectdir "C:\Users\k1754142\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
*global projectdir "C:\Users\Mark\OneDrive\PhD Project\OpenSAFELY NEIAA\inflammatory_rheum"
global projectdir `c(pwd)'

capture mkdir "$projectdir/output/data"
capture mkdir "$projectdir/output/figures"
capture mkdir "$projectdir/output/tables"

global logdir "$projectdir/logs"

**Open a log file
cap log close
log using "$logdir/eia_dataset.log", replace

**Set Ado file path
adopath + "$projectdir/analysis/extra_ados"

*Import EIA specific dataset
import delimited "$projectdir/output/dataset_eia.csv", clear

set scheme plotplainblind

**Set index dates ===========================================================*/

global index_date = "01/04/2016"
global start_date = "01/04/2019" //for outpatient analyses, data only be available from April 2019
global end_date = "31/03/2025"
global base_year = year(date("$start_date", "DMY"))
global end_year = year(date("$end_date", "DMY"))
global max_year = $end_year - $base_year

**Conversion for dates====================================================*

***Variables ending in _date that are string
ds *_date, has(type string)
local string_dates `r(varlist)'
foreach var of local string_dates {
    gen `var'_num = date(`var', "YMD")
    format `var'_num %td
    order `var'_num, after(`var')
    drop `var'
    rename `var'_num `var'
}

***Variables ending in _date that are numeric
foreach var of varlist *_date {
    capture confirm string variable `var'
    if _rc != 0 {
        format `var' %td
    }
}

***Create binary indicator for each
ds *_date
local dates `r(varlist)'
foreach var of local dates {
	local newvar =  substr("`var'", 1, length("`var'") - 5)
	gen `newvar' = (`var'!=. )
	order `newvar', after(`var')
	lab define `newvar' 0 "No" 1 "Yes"
	lab val `newvar' `newvar'
	tab `newvar', missing
}

/*
**Will also need to amend conversion for biologic dates ====================================================*
***Some dates are given with month/year only, so adding day 15 to enable them to be processed as dates
***Would do this by labelling as _date_hcd then doing similar to above/below, but adding 15 days first

foreach var of varlist 	 abatacept_date						///
						 adalimumab_date					///	
						 baricitinib_date					///
						 certolizumab_date					///
						 etanercept_date					///
						 golimumab_date						///
						 guselkumab_date					///	
						 infliximab_date					///
						 ixekizumab_date					///
						 methotrexate_hcd_date				///
						 rituximab_date						///
						 sarilumab_date						///
						 secukinumab_date					///	
						 tocilizumab_date					///
						 tofacitinib_date					///
						 upadacitinib_date					///
						 ustekinumab_date					///
						 {
						 	
		capture confirm string variable `var'
		if _rc!=0 {
			assert `var'==.
			rename `var' `var'_date
		}
	
		else {
				replace `var' = `var' + "-15"
				rename `var' `var'_dstr
				replace `var'_dstr = " " if `var'_dstr == "-15"
				gen `var'_date = date(`var'_dstr, "YMD") 
				order `var'_date, after(`var'_dstr)
				drop `var'_dstr
		}
	
	format `var'_date %td
}
*/
		
**All patients should have diagnostic code=============================================================*/
tab eia_inc, missing
keep if eia_inc==1	

*Generate diagnosis date===============================================================*/

**Use diagnostic code date (in GP record) as diagnosis date
gen diagnosis_date=eia_inc_date
format diagnosis_date %td

*Refine diagnostic window=============================================================*/

**Keep patients with diagnosis date after start date and before end date - should be none dropped
keep if diagnosis_date>=date("$start_date", "DMY") & diagnosis_date!=. 
tab eia_inc, missing
keep if diagnosis_date<=date("$end_date", "DMY") & diagnosis_date!=. 
tab eia_inc, missing	
		
**Create and label variables ===========================================================*/

***Age variables
*Create categorised age
gen age = eia_age

drop if age<18 & age !=.
drop if age>109 & age !=.
drop if age==.
lab var age "Age at diagnosis"

recode age 18/29.9999 = 1 /// 
		   30/39.9999 = 2 ///
           40/49.9999 = 3 ///
		   50/59.9999 = 4 ///
	       60/69.9999 = 5 ///
		   70/79.9999 = 6 ///
		   80/max = 7, gen(agegroup) 

label define agegroup 	1 "18 to 30" ///
						2 "30 to 39" ///
						3 "40 to 49" ///
						4 "50 to 59" ///
						5 "60 to 69" ///
						6 "70 to 79" ///
						7 "80 or above", modify
						
label values agegroup agegroup
lab var agegroup "Age group"
tab agegroup, missing
order agegroup, after(age)

***Sex
gen male = 1 if sex == "male"
replace male = 0 if sex == "female"
lab var male "Male"
lab define male 0 "No" 1 "Yes", modify
lab val male male
tab male, missing
order male, after(sex)

***Ethnicity
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
							6 "Not known", modify
							
label values ethnicity_n ethnicity_n
lab var ethnicity_n "Ethnicity"
tab ethnicity_n, missing
drop ethnicity
rename ethnicity_n ethnicity 

***Practice regions
encode region, gen(nuts_region)
tab region, missing
replace region="Not known" if region==""
gen region_nospace=region
replace region_nospace="SouthWest" if region=="South West"
replace region_nospace="EastMidlands" if region=="East Midlands"
replace region_nospace="East" if region=="East"
replace region_nospace="London" if region=="London"
replace region_nospace="NorthEast" if region=="North East"
replace region_nospace="NorthWest" if region=="North West"
replace region_nospace="SouthEast" if region=="South East"
replace region_nospace="WestMidlands" if region=="West Midlands"
replace region_nospace="YorkshireandTheHumber" if region=="Yorkshire and The Humber"

***IMD
gen imd = 1 if imd_quintile == "1 (most deprived)"
replace imd = 2 if imd_quintile == "2"
replace imd = 3 if imd_quintile == "3"
replace imd = 4 if imd_quintile == "4"
replace imd = 5 if imd_quintile == "5 (least deprived)"
replace imd = .u if imd_quintile == "Unknown"

label define imd 1 "1 (most deprived)" 2 "2" 3 "3" 4 "4" 5 "5 (least deprived)" .u "Unknown", modify
label values imd imd 
lab var imd "Index of multiple deprivation"
tab imd, missing
drop imd_quintile

***Body Mass Index
*Recode strange values 
replace bmi_value = . if bmi_value == 0 
replace bmi_value = . if !inrange(bmi_value, 10, 80)

*Restrict to within 10 years of EIA diagnosis date and aged>16 
gen bmi_time = (eia_inc_date - bmi_date)/365.25
gen bmi_age = age - bmi_time
replace bmi_value = . if bmi_age < 16 
replace bmi_value = . if bmi_time > 10 & bmi_time != . 

*Set to missing if no date, and vice versa 
replace bmi_value = . if bmi_date == . 
replace bmi_date = . if bmi_value == . 
replace bmi_time = . if bmi_value == . 
replace bmi_age = . if bmi_value == . 

*Create BMI categories
gen 	bmicat = .
recode  bmicat . = 1 if bmi_value < 18.5
recode  bmicat . = 2 if bmi_value < 25
recode  bmicat . = 3 if bmi_value < 30
recode  bmicat . = 4 if bmi_value < 35
recode  bmicat . = 5 if bmi_value < 40
recode  bmicat . = 6 if bmi_value < .
replace bmicat = .u if bmi_value >= .

label define bmicat 1 "Underweight (<18.5)" 	///
					2 "Normal (18.5-24.9)"		///
					3 "Overweight (25-29.9)"	///
					4 "Obese I (30-34.9)"		///
					5 "Obese II (35-39.9)"		///
					6 "Obese III (40+)"			///
					.u "Not known"
					
label values bmicat bmicat
lab var bmicat "BMI"
tab bmicat, missing
order bmicat, after (bmi_value)
drop bmi_age bmi_time

*Create less granular categorisation
recode bmicat 1/3 .u = 1 4 = 2 5 = 3 6 = 4, gen(obese4cat)

label define obese4cat 	1 "No record of obesity" 	///
						2 "Obese I (30-34.9)"		///
						3 "Obese II (35-39.9)"		///
						4 "Obese III (40+)"		

label values obese4cat obese4cat
order obese4cat, after(bmicat)
lab var obese4cat "Obesity categories"

***Smoking 
label define smoke 1 "Never" 2 "Former" 3 "Current" .u "Not known"

gen     smoke = 1  if smoking_status == "N"
replace smoke = 2  if smoking_status == "E"
replace smoke = 3  if smoking_status == "S"
replace smoke = .u if smoking_status == "M"
replace smoke = .u if smoking_status == "" 

label values smoke smoke
lab var smoke "Smoking status"
drop smoking_status
tab smoke, missing

*Create non-missing 3-category variable for current smoking (assumes missing smoking is never smoking)
recode smoke .u = 1, gen(smoke_nomiss)
order smoke_nomiss, after(smoke)
label values smoke_nomiss smoke

**Clinical comorbidities
***Nb. not using creatinine of HBA1c values for now, just codes
foreach disease in ckd dm ild copd cva lung_ca solid_ca haem_ca depr osteop frac dem chd {
	tab `disease'_before, missing
	tab `disease'_after, missing
	gen `disease'_new = 1 if (`disease'_after == 1 & `disease'_before == 0)
	recode `disease'_new .=0
	label define `disease'_new 0 "No" 1 "Yes"
	label values `disease'_new `disease'_new
	tab `disease'_new, missing
	order `disease'_new, after(`disease'_after)
}

*Label remaining variables 
lab var ckd_before "Chronic kidney disease"
lab var ckd_after "Chronic kidney disease"
lab var ckd_new "Chronic kidney disease"
lab var dm_before "Type 2 diabetes mellitus"
lab var dm_after "Type 2 diabetes mellitus"
lab var dm_new "Type 2 diabetes mellitus"
lab var ild_before "Interstitial lung disease"
lab var ild_after "Interstitial lung disease"
lab var ild_new "Interstitial lung disease"
lab var copd_before "COPD"
lab var copd_after "COPD"
lab var copd_new "COPD"
lab var lung_ca_before "Lung cancer"
lab var lung_ca_after "Lung cancer"
lab var lung_ca_new "Lung cancer"
lab var solid_ca_before "Solid organ cancer"
lab var solid_ca_after "Solid organ cancer"
lab var solid_ca_new "Solid organ cancer"
lab var haem_ca_before "Haematological cancer"
lab var haem_ca_after "Haematological cancer"
lab var haem_ca_new "Haematological cancer"
lab var depr_before "Depression"
lab var depr_after "Depression"
lab var depr_new "Depression"
lab var osteop_before "Osteoporosis"
lab var osteop_after "Osteoporosis"
lab var osteop_new "Osteoporosis"
lab var frac_before "Fragility fracture"
lab var frac_after "Fragility fracture"
lab var frac_new "Fragility fracture"
lab var dem_before "Dementia"
lab var dem_after "Dementia"
lab var dem_new "Dementia"
lab var chd_before "Coronary heart disease"
lab var chd_after "Coronary heart disease"
lab var chd_new "Coronary heart disease"

lab var rheum_appt "First rheumatology appointment within 12 months"
lab var rheum_appt_any "Any rheumatology appointment within 12 months"

lab var eia_inc "Early inflammatory arthritis"
lab var rheumatoid_inc "Rheumatoid arthritis"
lab var psa_inc "Psoriatic arthritis"
lab var axialspa_inc "Axial spondyloarthritis"
lab var undiffia_inc "Undifferentiated inflammatory arthritis"

**RF and CCP positivity (blood test and/or diagnostic code)
codebook rheumatoid_inc
codebook rf_code
codebook rf_test_value
tabstat rf_test_value, stats (n mean p50 p25 p75) //recode on the basis of values
gen rf_pos_ra = 1 if (rf_test_value>=20 & rf_test_value!=.) | rf_code==1 //check ranges
recode rf_pos_ra .=0 //Nb. 0 will also include those where test not done (or not coded for)
lab define rf_pos_ra 0 "RF negative/not known" 1 "RF positive"
lab val rf_pos_ra rf_pos_ra
lab var rf_pos_ra "Rheumatoid factor positivity"
tab rf_pos_ra if rheumatoid_inc==1 //Nb. 0 will also include those where test not done (or not coded for)

codebook rheumatoid_inc
codebook ccp_code
codebook ccp_test_value
tabstat ccp_test_value, stats (n mean p50 p25 p75) //recode on the basis of values
gen ccp_pos_ra = 1 if (ccp_test_value>=10 & ccp_test_value!=.) | ccp_code==1 //check ranges
recode ccp_pos_ra .=0 //Nb. 0 will also include those where test not done (or not coded for)
lab define ccp_pos_ra 0 "CCP negative/not known" 1 "CCP positive"
lab val ccp_pos_ra ccp_pos_ra
lab var ccp_pos_ra "CCP positivity"
tab ccp_pos_ra if rheumatoid_inc==1 //Nb. 0 will also include those where test not done (or not coded for)

**Seropositive RA (RF and/or CCP positive and/or seropositive diagnostic code)
gen seropos_ra = 1 if rf_pos_ra==1 | ccp_pos_ra==1 | seropositive_code==1 //check ranges
recode seropos_ra .=0 //Nb. 0 will also include those where test not done (or not coded for)
lab define seropos_ra 0 "Seronegative/not known" 1 "Seropositive"
lab val seropos_ra seropos_ra
lab var seropos_ra "Seropositivity"
tab seropos_ra if rheumatoid_inc==1 //Nb. 0 will also include those where test not done (or not coded for)

**Erosive codes
lab var erosive_ra_code "Erosive rheumatoid arthritis"
tab erosive_ra_code if rheumatoid_inc==1 //Nb. 0 will also include those where test not done (or not coded for)

**Check first rheum appt date==================================*/

tab rheum_appt, missing //proportion of patients with an rheum outpatient date (with first attendance option selected) in the 12 months before or after after EIA code appeared in GP record; data only April 2019 onwards
tab rheum_appt if rheum_appt_date>eia_inc_date & rheum_appt_date!=. //confirm proportion who had first rheum appt (i.e. not missing) after EIA code
tab rheum_appt if rheum_appt_date>(eia_inc_date + 30) & rheum_appt_date!=. //confirm proportion who had first rheum appt 30 days after EIA code 
tab rheum_appt if rheum_appt_date>(eia_inc_date + 60) & rheum_appt_date!=. //confirm proportion who had first rheum appt 60 days after EIA code
tab rheum_appt if rheum_appt_date>(eia_inc_date + 120) & rheum_appt_date!=. //confirm proportion who had first rheum appt 120 days after EIA code
tab rheum_appt if rheum_appt_date>(eia_inc_date + 180) & rheum_appt_date!=. //confirm proportion who had first rheum appt 180 days after EIA code
replace rheum_appt=0 if rheum_appt_date>(eia_inc_date + 365) & rheum_appt_date!=. //replace as missing if first appt >365 days after EIA code - should be none
replace rheum_appt_date=. if rheum_appt_date>(eia_inc_date + 365) & rheum_appt_date!=. //replace as missing if first appt >365 days after EIA code - should be none

tab rheum_appt_last, missing //proportion of patients with an rheum outpatient date (with first attendance option selected + last in period) in the 12 months before and 60 days after EIA code appeared in GP record; data only April 2019 onwards

tab rheum_appt_any, missing //proportion of patients with a rheum outpatient date (without first attendance option selected) in the 12 months before or after EIA code appeared in GP record; data only April 2019 onwards
tab rheum_appt_any if rheum_appt_any_date>eia_inc_date & rheum_appt_any_date!=. //confirm proportion who had first rheum appt (i.e. not missing) after EIA code
tab rheum_appt_any if rheum_appt_any_date>(eia_inc_date + 60) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 60 days after EIA code
tab rheum_appt_any if rheum_appt_any_date>(eia_inc_date + 120) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 120 days after EIA code - should be none
tab rheum_appt_any if rheum_appt_any_date>(eia_inc_date + 180) & rheum_appt_any_date!=. //confirm proportion who had first rheum appt 180 days after EIA code - should be none
replace rheum_appt_any=0 if rheum_appt_any_date>(eia_inc_date + 60) & rheum_appt_any_date!=. //replace as missing those appts >365 days after EIA code - should be none
replace rheum_appt_any_date=. if rheum_appt_any_date>(eia_inc_date + 60) & rheum_appt_any_date!=. //replace as missing those appts >365 days after EIA code - should be none

*Check if first csDMARD/biologic was before first rheum appt date=====================================================*/

**csDMARDs (not including high cost MTX; wouldn't be shared care)
gen csdmard=1 if hydroxychloroquine==1 | leflunomide==1 | methotrexate_oral==1 | methotrexate_inj==1 | sulfasalazine==1
recode csdmard .=0 
tab csdmard, missing

**Date of first csDMARD script (not including high cost MTX prescriptions)
gen csdmard_date=min(hydroxychloroquine_date, leflunomide_date, methotrexate_oral_date, methotrexate_inj_date, sulfasalazine_date)
format %td csdmard_date

**Generate combined methotrexate (primary care only)
gen mtx = 1 if methotrexate_oral==1 | methotrexate_inj==1
recode mtx .=0
lab var mtx "Methotrexate"
gen mtx_date = min(methotrexate_oral_date, methotrexate_inj_date) if mtx == 1
format %td mtx_date

**Exclude if first csdmard was more than 60 days before first rheum appt
tab csdmard if rheum_appt_date!=. & csdmard_date!=. & csdmard_date<rheum_appt_date
tab csdmard if rheum_appt_date!=. & csdmard_date!=. & (csdmard_date + 60)<rheum_appt_date
 
gen pre_ra_csdmard_time = (rheum_appt_date - csdmard_date) if rheum_appt_date!=. & csdmard_date!=. & csdmard_date<rheum_appt_date
tabstat pre_ra_csdmard_time, stats (n mean p50 p25 p75) // how long before were csdmards prescribed

tab mtx if rheum_appt_date!=. & mtx_date!=. & (mtx_date + 60)<rheum_appt_date 
tab hydroxychloroquine if rheum_appt_date!=. & hydroxychloroquine_date!=. & (hydroxychloroquine_date + 60)<rheum_appt_date 
tab sulfasalazine if rheum_appt_date!=. & sulfasalazine_date!=. & (sulfasalazine_date + 60)<rheum_appt_date 
tab leflunomide if rheum_appt_date!=. & leflunomide_date!=. & (leflunomide_date + 60)<rheum_appt_date 

**Drop if first csDMARD more than 60 days before first attendance at a rheum appt 
drop if rheum_appt_date!=. & csdmard_date!=. & (csdmard_date + 60)<rheum_appt_date

tab csdmard if rheum_appt_date==. & rheum_appt_any_date!=. & csdmard_date!=. & (csdmard_date + 60)<rheum_appt_any_date

*drop if rheum_appt_date==. & rheum_appt_any_date!=. & csdmard_date!=. & (csdmard_date + 60)<rheum_appt_any_date //drop if first csDMARD more than 60 days before first captured rheum appt that did not have first attendance tag

/*
**Biologic use
gen biologic=1 if abatacept==1 | adalimumab==1 | baricitinib==1 | certolizumab==1 | etanercept==1 | golimumab==1 | guselkumab==1 | infliximab==1 | ixekizumab==1 | rituximab==1 | sarilumab==1 | secukinumab==1 | tocilizumab==1 | tofacitinib==1 | upadacitinib==1 | ustekinumab==1 
recode biologic .=0
tab biologic, missing

**Date of first biologic script
gen biologic_date=min(abatacept_date, adalimumab_date, baricitinib_date, certolizumab_date, etanercept_date, golimumab_date, guselkumab_date, infliximab_date, ixekizumab_date, rituximab_date, sarilumab_date, secukinumab_date, tocilizumab_date, tofacitinib_date, upadacitinib_date, ustekinumab_date)
format %td biologic_date

tab biologic if rheum_appt_date!=. & biologic_date!=. & biologic_date<rheum_appt_date 
tab biologic if rheum_appt_date!=. & biologic_date!=. & (biologic_date + 60)<rheum_appt_date 
drop if rheum_appt_date!=. & biologic_date!=. & (biologic_date + 60)<rheum_appt_date //drop if first biologic more than 60 days before first rheum_appt_date
tab biologic if rheum_appt_date==. & rheum_appt_any_date!=. & biologic_date!=. & (biologic_date + 60)<rheum_appt_any_date
drop if rheum_appt_date==. & rheum_appt_any_date!=. & biologic_date!=. & (biologic_date + 60)<rheum_appt_any_date //drop if first biologic more than 60 days before first captured rheum appt that did not have first attendance tag
*/

*Include only most recent EIA sub-diagnosis=============================================*/
replace rheumatoid_inc =0 if psa_inc_date > rheumatoid_inc_date & psa_inc_date !=.
replace rheumatoid_inc =0 if axialspa_inc_date > rheumatoid_inc_date & axialspa_inc_date !=.
replace rheumatoid_inc =0 if undiffia_inc_date > rheumatoid_inc_date & undiffia_inc_date !=.
replace psa_inc =0 if rheumatoid_inc_date >= psa_inc_date & rheumatoid_inc_date !=.
replace psa_inc =0 if axialspa_inc_date > psa_inc_date & axialspa_inc_date !=.
replace psa_inc =0 if undiffia_inc_date > psa_inc_date & undiffia_inc_date !=.
replace axialspa_inc =0 if psa_inc_date >= axialspa_inc_date & psa_inc_date !=.
replace axialspa_inc =0 if rheumatoid_inc_date >= axialspa_inc_date & rheumatoid_inc_date !=.
replace axialspa_inc =0 if undiffia_inc_date > axialspa_inc_date & undiffia_inc_date !=.
replace undiffia_inc =0 if rheumatoid_inc_date >= undiffia_inc_date & rheumatoid_inc_date !=.
replace undiffia_inc =0 if psa_inc_date >= undiffia_inc_date & psa_inc_date !=.
replace undiffia_inc =0 if axialspa_inc_date >= undiffia_inc_date & axialspa_inc_date !=.
gen eia_diagnosis=1 if rheumatoid_inc==1
replace eia_diagnosis=2 if psa_inc==1
replace eia_diagnosis=3 if axialspa_inc==1
replace eia_diagnosis=4 if undiffia_inc==1
lab define eia_diagnosis 1 "RA" 2 "PsA" 3 "AxSpA" 4 "undiffia IA", modify
lab val eia_diagnosis eia_diagnosis
tab eia_diagnosis, missing
drop if eia_diagnosis==. //should be none

decode eia_diagnosis, gen(eia_diag)
replace eia_diag="Undifferentiated IA" if eia_diagnosis==4

*Split into time windows=========================================*/

**Month/Year of GP diagnostic code
gen year_diag=year(eia_inc_date)
format year_diag %ty
gen month_diag=month(eia_inc_date)
gen mo_year_diagn=ym(year_diag, month_diag)
format mo_year_diagn %tmMon-CCYY
generate str16 mo_year_diagn_s = strofreal(mo_year_diagn,"%tmCCYY!mNN")
lab var mo_year_diagn "Month/Year of Diagnosis"
lab var mo_year_diagn_s "Month/Year of Diagnosis"

**Month/Year of rheum appt
gen year_appt=year(rheum_appt_date) if rheum_appt_date!=.
format year_appt %ty
gen month_appt=month(rheum_appt_date) if rheum_appt_date!=. 
gen mo_year_appt=ym(year_appt, month_appt)
format mo_year_appt %tmMon-CCYY
generate str16 mo_year_appt_s = strofreal(mo_year_appt,"%tmCCYY!mNN")

**Separate into 3-month time windows (for diagnosis date)
gen diagnosis_3m = qofd(diagnosis_date)
format diagnosis_3m %tq
lab var diagnosis_3m "Time period for diagnosis"
tab diagnosis_3m, missing
bys eia_diagnosis: tab diagnosis_3m, missing

**Separate into 12-month time windows (for diagnosis date)
gen diagnosis_year = (floor((diagnosis_date - date("$start_date", "DMY")) / 365.25) + 1) if inrange(diagnosis_date, date("$start_date", "DMY"), date("$end_date", "DMY"))
lab var diagnosis_year "Year of diagnosis"
forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
    local end = `start' + 1
    label define diagnosis_year_lbl `i' "Apr `start'–Mar `end'", add
}
lab val diagnosis_year diagnosis_year_lbl
tab diagnosis_year, missing
bys eia_diagnosis: tab diagnosis_year, missing

**Separate into 3-month time windows (for appt date)
gen appt_3m = qofd(rheum_appt_date)
format appt_3m %tq
lab var appt_3m "Time period for appointment"
tab appt_3m, missing
bys eia_diagnosis: tab appt_3m, missing

**Separate into 12-month time windows (for appt date)
gen appt_year = (floor((rheum_appt_date - date("$start_date", "DMY")) / 365.25) + 1) if inrange(rheum_appt_date, date("$start_date", "DMY"), date("$end_date", "DMY"))
lab var appt_year "Year of appointment"
forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
    local end = `start' + 1
    label define appt_year_lbl `i' "Apr `start'–Mar `end'", add
}
lab val appt_year appt_year_lbl
tab appt_year, missing
bys eia_diagnosis: tab appt_year, missing

*Define Rheumatology appointments ======================================*/

tab mo_year_diagn rheum_appt, missing //proportion of patients with a rheum outpatient date (with first attendance option selected) in the 12 months before or after after EIA code appeared in GP record; data only April 2019 onwards

***Check number of rheumatology appts in the year after first rheumatology outpatient appointment
tabstat rheum_appt_count, stat (n mean sd p50 p25 p75)
bys diagnosis_year: tabstat rheum_appt_count, stat (n mean sd p50 p25 p75)
bys appt_year: tabstat rheum_appt_count, stat (n mean sd p50 p25 p75)

***Check medium used for rheumatology appointment
tab rheum_appt_medium, missing
gen rheum_appt_medium_clean = rheum_appt_medium if rheum_appt_medium >0 & rheum_appt_medium<100
recode rheum_appt_medium_clean 3=2 //recode telemedicine=telephone
replace rheum_appt_medium_clean=10 if rheum_appt_medium_clean>2 & rheum_appt_medium_clean!=.
recode rheum_appt_medium_clean .=.u
lab define rheum_appt_medium_clean 1 "Face-to-face" 2 "Telephone" 10 "Other" .u "Missing", modify
lab val rheum_appt_medium_clean rheum_appt_medium_clean
lab var rheum_appt_medium_clean "Rheumatology consultation medium"
tab rheum_appt_medium_clean 

*Gen rheum appt variable with 6m/12m+ until study end date
gen rheum_appt_12m=rheum_appt if rheum_appt_date<=(date("$end_date", "DMY")-365) 
recode rheum_appt_12m .=0
lab var rheum_appt_12m "Rheumatology appt 12m+"
lab define rheum_appt_12m 0 "No" 1 "Yes", modify
lab val rheum_appt_12m rheum_appt_12m

gen rheum_appt_6m=rheum_appt if rheum_appt_date<=(date("$end_date", "DMY")-183) 
recode rheum_appt_6m .=0
lab var rheum_appt_6m "Rheumatology appt 6m+"
lab define rheum_appt_6m 0 "No" 1 "Yes", modify
lab val rheum_appt_6m rheum_appt_6m

**Define Rheumatology referrals ======================================*/

/*
***From HES OPA (referral_request_received_date)
tab rheum_appt_ref, missing
codebook rheum_appt_ref_date
tab mo_year_diagn rheum_appt_ref, missing
tab mo_year_diagn rheum_appt_ref if rheum_appt!=., missing

***From RTT clock-stop data (only available for those with clock-stop date between May 2021 and May 2022)
tab rtt_cl_ref, missing
codebook rtt_cl_ref_date
tab rtt_cl_ref if rheum_appt!=0 & rtt_cl_ref_date<=rheum_appt_date, missing 
tab mo_year_diagn rtt_cl_ref, missing
tab mo_year_diagn rtt_cl_ref if rheum_appt!=., missing
tab rtt_cl_start, missing //check how this differs
codebook rtt_cl_start_date
tab rtt_cl_start if rheum_appt!=0 & rtt_cl_start_date<=rheum_appt_date, missing 

***From RTT open pathway data (only available as a snapshot of those with open RTT pathways as of May 2022)
tab rtt_op_ref, missing
codebook rtt_op_ref_date
tab rtt_op_ref if rheum_appt!=0 & rtt_op_ref_date<=rheum_appt_date, missing 
tab mo_year_diagn rtt_op_ref, missing
tab mo_year_diagn rtt_op_ref if rheum_appt!=., missing
tab rtt_op_start, missing //check how this differs
codebook rtt_op_start_date
tab rtt_op_start if rheum_appt!=0 & rtt_op_start_date<=rheum_appt_date, missing 

***Combination of RTT clock-stop and open pathway
gen rtt_ref_date = rtt_cl_ref_date
replace rtt_ref_date = rtt_op_ref_date if rtt_cl_ref_date==. & rtt_op_ref_date!=. //need to think how to handle duplicate pathways
format %td rtt_ref_date
gen rtt_ref =1 if rtt_ref_date!=.
recode rtt_ref .=0
tab rtt_ref, missing
tab mo_year_diagn rtt_ref, missing
tab mo_year_diagn rtt_ref if rheum_appt!=0 & rtt_ref_date<=rheum_appt_date, missing 
*/

***From clinical events (Nb. low capture of coded rheumatology referrals in clinical events at present)
tab ref_12m_preappt, missing //last rheum referral in the year before rheumatology outpatient (requires rheum appt to have been present)
tab ref_12m_preappt if rheum_appt!=0 & ref_12m_preappt_date<=rheum_appt_date, missing  //last rheum referral in the 2 years before rheumatology outpatient, assuming ref date before rheum appt date (should be accounted for by Python code)

***From clinical events (using 6m cut-off)
tab ref_6m_preappt, missing //last rheum referral in the 6 months before rheumatology outpatient (requires rheum appt to have been present)
tab ref_6m_preappt if rheum_appt!=0 & ref_6m_preappt_date<=rheum_appt_date, missing  //last rheum referral in the 6 months before rheumatology outpatient, assuming ref date before rheum appt date (should be accounted for by Python code)

tab ref_12m_precode, missing //last rheum referral in the year before IA code 
gen referral_rheum_comb_date = ref_12m_preappt_date if ref_12m_preappt_date!=.
replace referral_rheum_comb_date = ref_12m_precode_date if ref_12m_preappt_date==. & ref_12m_precode_date!=. //combination of the two above
format %td referral_rheum_comb_date

/*
***From GP appointments (proxy)
tab last_gp_refrheum, missing //proportion with last GP appointment in 2 years before rheum referral (pre-rheum appt); requires there to have been a rheum referral before a rheum appt

gen last_gp_prerheum_12m=last_gp_prerheum if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-365)
recode last_gp_prerheum_12m .=0
lab var last_gp_prerheum_12m "GP and rheum appt 12m+"
lab define last_gp_prerheum_12m 0 "No" 1 "Yes", modify
lab val last_gp_prerheum_12m last_gp_prerheum_12m

gen last_gp_prerheum_6m=last_gp_prerheum if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-183)
recode last_gp_prerheum_6m .=0
lab var last_gp_prerheum_6m "GP and rheum appt 6m+"
lab define last_gp_prerheum_6m 0 "No" 1 "Yes", modify
lab val last_gp_prerheum_6m last_gp_prerheum_6m

tab last_gp_refcode, missing //last GP appointment before rheum ref (pre-EIA code ref); requires there to have been a rheum referral before an EIA code (i.e. rheum appt could have been missing)
tab last_gp_prerheum, missing //last GP appointment before rheum appt; requires there to have been a rheum appt before and EIA code
tab last_gp_precode, missing //last GP appointment before EIA code

****All appts in the correct order (using clinical events referrals)
gen all_appts=1 if last_gp_refrheum==1 & ref_12m_preappt==1 & rheum_appt==1 & (last_gp_refrheum_date<=ref_12m_preappt_date) & (ref_12m_preappt_date<=rheum_appt_date)
recode all_appts .=0
tab all_appts, missing //proportion who had a last gp appt, then rheum ref, then rheum appt
*/

**Define who qualifies in terms of appointments and referrals ===============================*/

**Proportion of patients with at least 6 or 12 months of GP registration after diagnostic code
rename has_6m_follow_up has_6m_follow_up_s 
gen has_6m_follow_up=1 if has_6m_follow_up_s=="T"
recode has_6m_follow_up .=0
drop has_6m_follow_up_s
tab has_6m_follow_up
rename has_12m_follow_up has_12m_follow_up_s 
gen has_12m_follow_up=1 if has_12m_follow_up_s=="T"
recode has_12m_follow_up .=0
drop has_12m_follow_up_s
tab has_12m_follow_up 
tab mo_year_diagn has_6m_follow_up
tab mo_year_diagn has_12m_follow_up

*For appt and csDMARD analyses, all patients must have 1) rheum appt 2) rheum ref before rheum appt 3) 12m follow-up after rheum appt 4) 12m of registration after diagnostic code

*gen has_6m_post_appt=1 if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-183) & has_6m_follow_up==1 & last_gp_prerheum==1
gen has_6m_post_appt=1 if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-183) & has_6m_follow_up==1 & ref_12m_preappt==1
recode has_6m_post_appt .=0
lab var has_6m_post_appt "GP/rheum/registration 6m+"
lab define has_6m_post_appt 0 "No" 1 "Yes", modify
lab val has_6m_post_appt has_6m_post_appt
tab has_6m_post_appt

*gen has_12m_post_appt=1 if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-365) & has_12m_follow_up==1 & last_gp_prerheum==1
gen has_12m_post_appt=1 if rheum_appt_date!=. & rheum_appt_date<=(date("$end_date", "DMY")-365) & has_12m_follow_up==1 & ref_12m_preappt==1
recode has_12m_post_appt .=0
lab var has_12m_post_appt "GP/rheum/registration 12m+"
lab define has_12m_post_appt 0 "No" 1 "Yes", modify
lab val has_12m_post_appt has_12m_post_appt
tab has_12m_post_appt

*Time to rheum referral =============================================*/

/*
**Time from last GP appt to rheum ref before rheum appt (i.e. if appts are present and in correct time order)
gen time_gp_rheum_ref_appt = (ref_12m_preappt_date - last_gp_refrheum_date) if ref_12m_preappt_date!=. & last_gp_refrheum_date!=. & rheum_appt_date!=. & (ref_12m_preappt_date>=last_gp_refrheum_date) & (ref_12m_preappt_date<=rheum_appt_date)
tabstat time_gp_rheum_ref_appt, stats (n mean p50 p25 p75) //all patients (should be same number as all_appts)

gen gp_ref_cat=1 if time_gp_rheum_ref_appt<=3 & time_gp_rheum_ref_appt!=. 
replace gp_ref_cat=2 if time_gp_rheum_ref_appt>3 & time_gp_rheum_ref_appt<=7 & time_gp_rheum_ref_appt!=. & gp_ref_cat==.
replace gp_ref_cat=3 if time_gp_rheum_ref_appt>7 & time_gp_rheum_ref_appt!=. & gp_ref_cat==.
lab define gp_ref_cat 1 "Within 3 days" 2 "Between 3-7 days" 3 "More than 7 days", modify
lab val gp_ref_cat gp_ref_cat
lab var gp_ref_cat "Time to GP referral"
tab gp_ref_cat, missing

gen gp_ref_3d=1 if time_gp_rheum_ref_appt<=3 & time_gp_rheum_ref_appt!=. 
replace gp_ref_3d=2 if time_gp_rheum_ref_appt>3 & time_gp_rheum_ref_appt!=.
lab define gp_ref_3d 1 "Within 3 days" 2 "More than 3 days", modify
lab val gp_ref_3d gp_ref_3d
lab var gp_ref_3d "Time to GP referral"
tab gp_ref_3d, missing

**Time from last GP to rheum ref before eia code (sensitivity analysis; includes those with no rheum appt)
gen time_gp_rheum_ref_inc = (ref_12m_precode_date - last_gp_refcode_date) if ref_12m_precode_date!=. & last_gp_refcode_date!=. & ref_12m_precode_date>=last_gp_refcode_date & ref_12m_precode_date<=eia_inc_date
tabstat time_gp_rheum_ref_inc, stats (n mean p50 p25 p75)

**Time from last GP to rheum ref (combined - sensitivity analysis; includes those with no rheum appt)
gen time_gp_rheum_ref_comb = time_gp_rheum_ref_appt 
replace time_gp_rheum_ref_comb = time_gp_rheum_ref_inc if time_gp_rheum_ref_appt==. & time_gp_rheum_ref_inc!=.
tabstat time_gp_rheum_ref_comb, stats (n mean p50 p25 p75)

*Time to rheum appointment=============================================*/

**Time from rheum ref to rheum appt (i.e. if appts are present and in correct order) using 12m referral cut-off
gen time_ref_rheum_appt = (rheum_appt_date - ref_12m_preappt_date) if rheum_appt_date!=. & ref_12m_preappt_date!=. & (ref_12m_preappt_date<=rheum_appt_date)
tabstat time_ref_rheum_appt, stats (n mean p50 p25 p75)
tabstat time_ref_rheum_appt if eia_diagnosis==1, stats (n mean p50 p25 p75) //RA
tabstat time_ref_rheum_appt if eia_diagnosis==2, stats (n mean p50 p25 p75) //PsA
tabstat time_ref_rheum_appt if (eia_diagnosis==1 | eia_diagnosis==2), stats (n mean p50 p25 p75) //RA or PsA
tabstat time_ref_rheum_appt if eia_diagnosis==3, stats (n mean p50 p25 p75) //axSpA
tabstat time_ref_rheum_appt if eia_diagnosis==4, stats (n mean p50 p25 p75) //Undiff IA
tabstat time_ref_rheum_appt if eia_diagnosis==1 & csdmard==1, stats (n mean p50 p25 p75) //RA and csDMARD at any point
tabstat time_ref_rheum_appt if eia_diagnosis==2 & csdmard==1, stats (n mean p50 p25 p75) //PsA and csDMARD at any point
tabstat time_ref_rheum_appt if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1, stats (n mean p50 p25 p75) //RA or PsA and csDMARD at any point

**Using working days
workdays ref_12m_preappt_date rheum_appt_date if rheum_appt_date!=. & ref_12m_preappt_date!=. & (ref_12m_preappt_date<=rheum_appt_date), gen(wd_ref_rheum_appt)
tabstat wd_ref_rheum_appt, stats (n mean p50 p25 p75)
tabstat wd_ref_rheum_appt if eia_diagnosis==1, stats (n mean p50 p25 p75) //RA
tabstat wd_ref_rheum_appt if eia_diagnosis==2, stats (n mean p50 p25 p75) //PsA
tabstat wd_ref_rheum_appt if (eia_diagnosis==1 | eia_diagnosis==2), stats (n mean p50 p25 p75) //RA or PsA
tabstat wd_ref_rheum_appt if eia_diagnosis==3, stats (n mean p50 p25 p75) //axSpA
tabstat wd_ref_rheum_appt if eia_diagnosis==4, stats (n mean p50 p25 p75) //Undiff IA
tabstat wd_ref_rheum_appt if eia_diagnosis==1 & csdmard==1, stats (n mean p50 p25 p75) //RA and csDMARD at any point
tabstat wd_ref_rheum_appt if eia_diagnosis==2 & csdmard==1, stats (n mean p50 p25 p75) //PsA and csDMARD at any point
tabstat wd_ref_rheum_appt if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1, stats (n mean p50 p25 p75) //RA or PsA and csDMARD at any point

**Time from rheum ref to rheum appt (i.e. if appts are present and in correct order) using 6m referral cut-off
gen time_ref_rheum_appt_6m = (rheum_appt_date - ref_6m_preappt_date) if rheum_appt_date!=. & ref_6m_preappt_date!=. & (ref_6m_preappt_date<=rheum_appt_date)
tabstat time_ref_rheum_appt_6m, stats (n mean p50 p25 p75)

workdays ref_6m_preappt_date rheum_appt_date if rheum_appt_date!=. & ref_6m_preappt_date!=. & (ref_6m_preappt_date<=rheum_appt_date), gen(wd_ref_rheum_appt_6m)
tabstat wd_ref_rheum_appt_6m, stats (n mean p50 p25 p75)

/*
**Time from last GP pre-rheum appt to first rheum appt (proxy for referral to appt delay)
gen time_gp_rheum_appt = (rheum_appt_date - last_gp_prerheum_date) if rheum_appt_date!=. & last_gp_prerheum_date!=. & (rheum_appt_date>=last_gp_prerheum_date)
tabstat time_gp_rheum_appt, stats (n mean p50 p25 p75)

**Time from rheum appt received date to rheum appt (i.e. if appts are present and in correct order)
gen time_hes_rheum_appt = (rheum_appt_date - rheum_appt_ref_date) if rheum_appt_date!=. & rheum_appt_ref_date!=. & (rheum_appt_ref_date<=rheum_appt_date)
tabstat time_hes_rheum_appt, stats (n mean p50 p25 p75)

**Time from RTT combined ref date to rheum appt (i.e. if appts are present and in correct order)
gen time_rtt_rheum_appt = (rheum_appt_date - rtt_ref_date) if rheum_appt_date!=. & rtt_ref_date!=. & (rtt_ref_date<=rheum_appt_date)
tabstat time_rtt_rheum_appt, stats (n mean p50 p25 p75)

**Time from RTT closed ref date to rheum appt (i.e. if appts are present and in correct order)
gen time_rtt_cl_rheum_appt = (rheum_appt_date - rtt_cl_ref_date) if rheum_appt_date!=. & rtt_cl_ref_date!=. & (rtt_cl_ref_date<=rheum_appt_date)
tabstat time_rtt_cl_rheum_appt, stats (n mean p50 p25 p75)

**Time from RTT open ref date to rheum appt (i.e. if appts are present and in correct order)
gen time_rtt_op_rheum_appt = (rheum_appt_date - rtt_op_ref_date) if rheum_appt_date!=. & rtt_op_ref_date!=. & (rtt_op_ref_date<=rheum_appt_date)
tabstat time_rtt_op_rheum_appt, stats (n mean p50 p25 p75)

gen gp_appt_cat=1 if time_gp_rheum_appt<=21 & time_gp_rheum_appt!=. 
replace gp_appt_cat=2 if time_gp_rheum_appt>21 & time_gp_rheum_appt<=42 & time_gp_rheum_appt!=. & gp_appt_cat==.
replace gp_appt_cat=3 if time_gp_rheum_appt>42 & time_gp_rheum_appt!=. & gp_appt_cat==.
lab define gp_appt_cat 1 "Within 3 weeks" 2 "Between 3-6 weeks" 3 "More than 6 weeks", modify
lab val gp_appt_cat gp_appt_cat
lab var gp_appt_cat "Time to rheumatology assessment, overall"
tab gp_appt_cat, missing

forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
    local end = `start' + 1
	gen gp_appt_cat_`start'=gp_appt_cat if appt_year==`i'
    lab define gp_appt_cat_`start' 1 "Within 3 weeks" 2 "Between 3-6 weeks" 3 "More than 6 weeks", modify
	lab val gp_appt_cat_`start' gp_appt_cat_`start'
	lab var gp_appt_cat_`start' "Time to rheumatology assessment, Apr `start'-Mar `end'"
	tab gp_appt_cat_`start', missing
}

gen gp_appt_3w=1 if time_gp_rheum_appt<=21 & time_gp_rheum_appt!=. 
replace gp_appt_3w=2 if time_gp_rheum_appt>21 & time_gp_rheum_appt!=.
lab define gp_appt_3w 1 "Within 3 weeks" 2 "More than 3 weeks", modify
lab val gp_appt_3w gp_appt_3w
lab var gp_appt_3w "Time to rheumatology assessment, overall"
tab gp_appt_3w, missing

*/

gen ref_appt_cat=1 if wd_ref_rheum_appt<=21 & wd_ref_rheum_appt!=. 
replace ref_appt_cat=2 if wd_ref_rheum_appt>21 & wd_ref_rheum_appt<=42 & wd_ref_rheum_appt!=. & ref_appt_cat==.
replace ref_appt_cat=3 if wd_ref_rheum_appt>42 & wd_ref_rheum_appt!=. & ref_appt_cat==.
lab define ref_appt_cat 1 "Within 3 weeks" 2 "Between 3-6 weeks" 3 "More than 6 weeks", modify
lab val ref_appt_cat ref_appt_cat
lab var ref_appt_cat "Time to rheumatology assessment"
tab ref_appt_cat  
tab ref_appt_cat if (eia_diagnosis==1 | eia_diagnosis==2) //RA or PsA
tab ref_appt_cat if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1 //RA or PsA and csDMARD at any point
bys region: tab ref_appt_cat
bys region: tab ref_appt_cat if (eia_diagnosis==1 | eia_diagnosis==2) //RA or PsA
bys region: tab ref_appt_cat if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1 //RA or PsA and csDMARD at any point

forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
	di "`start'"
    local end = `start' + 1
	gen ref_appt_cat_`start'=ref_appt_cat if appt_year==`i'
    lab define ref_appt_cat_`start' 1 "Within 3 weeks" 2 "Between 3-6 weeks" 3 "More than 6 weeks", modify
	lab val ref_appt_cat_`start' ref_appt_cat_`start'
	lab var ref_appt_cat_`start' "Time to rheumatology assessment, Apr `start'-Mar `end'"
	tab ref_appt_cat_`start'
}

gen ref_appt_3w=1 if wd_ref_rheum_appt<=21 & wd_ref_rheum_appt!=. 
replace ref_appt_3w=2 if wd_ref_rheum_appt>21 & wd_ref_rheum_appt!=.
lab define ref_appt_3w 1 "Within 3 weeks" 2 "More than 3 weeks", modify
lab val ref_appt_3w ref_appt_3w
lab var ref_appt_3w "Time to rheumatology assessment"
tab ref_appt_3w
bys region: tab ref_appt_3w

forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
	di "`start'"
    local end = `start' + 1
	gen ref_appt_3w_`start'=ref_appt_3w if appt_year==`i'
    lab define ref_appt_3w_`start' 1 "Within 3 weeks" 2 "More than 3 weeks", modify
	lab val ref_appt_3w_`start' ref_appt_3w_`start'
	lab var ref_appt_3w_`start' "Time to rheumatology assessment, Apr `start'-Mar `end'"
	tab ref_appt_3w_`start'
	tab ref_appt_3w_`start' if (eia_diagnosis==1 | eia_diagnosis==2) //RA or PsA
	tab ref_appt_3w_`start' if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1 //RA or PsA and csDMARD at any point
	bys region: tab ref_appt_3w_`start'
	bys region: tab ref_appt_3w_`start' if (eia_diagnosis==1 | eia_diagnosis==2) //RA or PsA
	bys region: tab ref_appt_3w_`start' if (eia_diagnosis==1 | eia_diagnosis==2) & csdmard==1 //RA or PsA and csDMARD at any point
}

*Time to EIA code==================================================*/

/*
**Time from last GP pre-code to EIA code (sensitivity analysis; includes those with no rheum ref and/or no rheum appt)
gen time_gp_eia_inc = (eia_inc_date - last_gp_precode_date) if eia_inc_date!=. & last_gp_precode_date!=. & eia_inc_date>=last_gp_precode_date
tabstat time_gp_eia_inc, stats (n mean p50 p25 p75)

**Time from last GP to EIA diagnosis (combined - sensitivity analysis; includes those with no rheum appt)
gen time_gp_eia_diag = time_gp_rheum_appt
replace time_gp_eia_diag = time_gp_eia_inc if time_gp_rheum_appt==. & time_gp_eia_inc!=.
tabstat time_gp_eia_diag, stats (n mean p50 p25 p75)
*/

**Time from rheum ref to EIA code (sensitivity analysis; includes those with no rheum appt)
gen time_ref_rheum_eia = (eia_inc_date - ref_12m_precode_date) if eia_inc_date!=. & ref_12m_precode_date!=. & ref_12m_precode_date<=eia_inc_date  
tabstat time_ref_rheum_eia, stats (n mean p50 p25 p75)

**Time from rheum ref to EIA diagnosis (combined - sensitivity analysis; includes those with no rheum appt)
gen time_ref_rheum_eia_comb = time_ref_rheum_appt
replace time_ref_rheum_eia_comb = time_ref_rheum_eia if time_ref_rheum_appt==. & time_ref_rheum_eia!=.
tabstat time_ref_rheum_eia_comb, stats (n mean p50 p25 p75)

**Time from rheum appt to EIA code
gen time_rheum_eia_inc = (eia_inc_date - rheum_appt_date) if eia_inc_date!=. & rheum_appt_date!=. 
tabstat time_rheum_eia_inc, stats (n mean p50 p25 p75) 
gen time_rheuml_eia_inc = (eia_inc_date - rheum_appt_last_date) if eia_inc_date!=. & rheum_appt_last_date!=. 
tabstat time_rheuml_eia_inc, stats (n mean p50 p25 p75) 

*Time from rheum appt to first csDMARD prescriptions in primary care record======================================================================*/

**Time to first csDMARD script; prescription must be within 6 months of first rheum appt for all csDMARDs below ==================*/
gen time_to_csdmard=(csdmard_date-rheum_appt_date) if csdmard==1 & rheum_appt_date!=. & (csdmard_date<=(rheum_appt_date+183))
tabstat time_to_csdmard, stats (n mean p50 p25 p75)

**All generate time to first csDMARD script; with no time restriction ==================*/
gen time_to_csdmard_unr=(csdmard_date-rheum_appt_date) if csdmard==1 & rheum_appt_date!=.
tabstat time_to_csdmard_unr, stats (n mean p50 p25 p75)

**csDMARD time categories
gen csdmard_time=1 if time_to_csdmard<=90 & time_to_csdmard!=. 
replace csdmard_time=2 if time_to_csdmard>90 & time_to_csdmard<=183 & time_to_csdmard!=.
replace csdmard_time=3 if time_to_csdmard>183 | time_to_csdmard==.
lab define csdmard_time 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months", modify
lab val csdmard_time csdmard_time
lab var csdmard_time "csDMARD in primary care, overall" 
tab csdmard_time, missing
tab csdmard_time if has_6m_follow_up==1, missing
tab csdmard_time if rheumatoid_inc==1 & has_6m_follow_up==1, missing 
tab csdmard_time if psa_inc==1 & has_6m_follow_up==1, missing
tab csdmard_time if axialspa_inc==1 & has_6m_follow_up==1, missing
tab csdmard_time if undiffia_inc==1 & has_6m_follow_up==1, missing

forvalues i = 1/$max_year {
    local start = $base_year + `i' - 1
    local end = `start' + 1
	gen csdmard_time_`start'=csdmard_time if appt_year==`i'
	recode csdmard_time_`start' .=4
    lab define csdmard_time_`start' 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months" 4 "Outside `start'/`end'", modify
	lab val csdmard_time_`start' csdmard_time_`start'
	lab var csdmard_time_`start' "csDMARD in primary care, Apr `start'-Mar `end'"
	tab csdmard_time_`start' if has_6m_follow_up==1, missing
}

**csDMARD time categories - binary 6 months
gen csdmard_6m=1 if time_to_csdmard<=183 & time_to_csdmard!=. 
replace csdmard_6m=0 if time_to_csdmard>183 | time_to_csdmard==.
lab define csdmard_6m 1 "Yes" 0 "No", modify
lab val csdmard_6m csdmard_6m
lab var csdmard_6m "csDMARD in primary care within 6 months" 
tab csdmard_6m, missing 

**What was first csDMARD in GP record - with time restriction - may need to remove leflunomide (for OpenSAFELY report) due to small counts at more granular time periods
gen first_csD=""
foreach var of varlist hydroxychloroquine_date mtx_date sulfasalazine_date leflunomide_date {
	replace first_csD="`var'" if csdmard_date==`var' & csdmard_date!=. & (`var'<=(rheum_appt_date+183)) & time_to_csdmard!=.
	}
gen first_csDMARD = substr(first_csD, 1, length(first_csD) - 5) if first_csD!="" 
drop first_csD
replace first_csDMARD="Methotrexate" if first_csDMARD=="mtx"
replace first_csDMARD="Sulfasalazine" if first_csDMARD=="sulfasalazine"
replace first_csDMARD="Hydroxychloroquine" if first_csDMARD=="hydroxychloroquine" 
replace first_csDMARD="Leflunomide" if first_csDMARD=="leflunomide" 
tab first_csDMARD if rheumatoid_inc==1 //for RA patients
tab first_csDMARD if psa_inc==1 //for PsA patients
tab first_csDMARD if axialspa_inc==1 //for axSpA patients
tab first_csDMARD if undiffia_inc==1 //for undiffia IA patients

**What was first csDMARD in GP record - without time restriction
gen first_csD_unr=""
foreach var of varlist hydroxychloroquine_date mtx_date sulfasalazine_date leflunomide_date {
	replace first_csD_unr="`var'" if csdmard_date==`var' & csdmard_date!=.
	}
gen first_csDMARD_unr = substr(first_csD_unr, 1, length(first_csD_unr) - 5) if first_csD_unr!="" 
drop first_csD_unr
replace first_csDMARD_unr="Methotrexate" if first_csDMARD_unr=="mtx"
replace first_csDMARD_unr="Sulfasalazine" if first_csDMARD_unr=="sulfasalazine"
replace first_csDMARD_unr="Hydroxychloroquine" if first_csDMARD_unr=="hydroxychloroquine" 
replace first_csDMARD_unr="Leflunomide" if first_csDMARD_unr=="leflunomide" 
tab first_csDMARD_unr if rheumatoid_inc==1 //for RA patients
tab first_csDMARD_unr if psa_inc==1 //for PsA patients
tab first_csDMARD_unr if axialspa_inc==1 //for axSpA patients
tab first_csDMARD_unr if undiffia_inc==1 //for undiffia IA patients

**Methotrexate use; Nb. this is just a check; need time-to-MTX instead (below)
gen mtx_6m = 1 if mtx==1 & rheum_appt==1 & (mtx_date<=rheum_appt_date+183) 
recode mtx_6m .=0
gen mtx_12m = 1 if mtx==1 & rheum_appt==1 & (mtx_date<=rheum_appt_date+365)
recode mtx_12m .=0

tab mtx if rheumatoid_inc==1 //for RA patients
tab mtx_6m if rheumatoid_inc==1 //with 6-month limit
tab mtx_12m if rheumatoid_inc==1 //with 12-month limit
tab mtx if psa_inc==1 //for PsA patients
tab mtx_6m if psa_inc==1 //with 6-month limit
tab mtx_12m if psa_inc==1 //with 12-month limit
tab mtx if undiffia_inc==1 //for undiffia IA patients
tab mtx_6m if undiffia_inc==1 //with 6-month limit
tab mtx_12m if undiffia_inc==1 //with 12-month limit

**Check if medication issued >once
gen mtx_shared=1 if mtx==1 & (methotrexate_oral_count>1 | methotrexate_inj_count>1)
recode mtx_shared .=0
tab mtx_shared

**Methotrexate use (shared care)
tab mtx_shared if rheumatoid_inc==1 //for RA patients; Nb. this is just a check; need time-to-MTX instead (below)
tab mtx_shared if rheumatoid_inc==1 & (mtx_date<=rheum_appt_date+183) //with 6-month limit
tab mtx_shared if psa_inc==1 //for PsA patients
tab mtx_shared if psa_inc==1 & (mtx_date<=rheum_appt_date+183) //with 6-month limit
tab mtx_shared if undiffia_inc==1 //for undiffia IA patients
tab mtx_shared if undiffia_inc==1 & (mtx_date<=rheum_appt_date+183) //with 6-month limit

**Check medication issue number
gen mtx_issue=0 if mtx==1 & (methotrexate_oral_count==0 | methotrexate_inj_count==0)
replace mtx_issue=1 if mtx==1 & (methotrexate_oral_count==1 | methotrexate_inj_count==1)
replace mtx_issue=2 if mtx==1 & (methotrexate_oral_count>1 | methotrexate_inj_count>1)
tab mtx_issue

**Time to first methotrexate script for RA patients - with time restriction
gen time_to_mtx=(mtx_date-rheum_appt_date) if mtx==1 & rheum_appt_date!=. & (mtx_date<=rheum_appt_date+183)
tabstat time_to_mtx if rheumatoid_inc==1, stats (n mean p50 p25 p75)

**Time to first methotrexate script for PsA patients 
tabstat time_to_mtx if psa_inc==1, stats (n mean p50 p25 p75)

**Time to first methotrexate script for undiffia IA patients (not including high cost MTX prescriptions)
tabstat time_to_mtx if undiffia_inc==1, stats (n mean p50 p25 p75)

**Methotrexate time categories - those with prescription date after 6 months (i.e. missing) are still counted
gen mtx_time=1 if time_to_mtx<=90 & time_to_mtx!=. 
replace mtx_time=2 if time_to_mtx>90 & time_to_mtx<=183 & time_to_mtx!=.
replace mtx_time=3 if time_to_mtx>183 | time_to_mtx==.
lab define mtx_time 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months", modify
lab val mtx_time mtx_time
lab var mtx_time "Methotrexate in primary care" 
tab mtx_time if rheumatoid_inc==1, missing 
tab mtx_time if psa_inc==1, missing
tab mtx_time if undiffia_inc==1, missing 

**Sulfasalazine use
gen ssz=1 if sulfasalazine==1
recode ssz .=0
gen ssz_6m = 1 if sulfasalazine==1 & rheum_appt==1 & (sulfasalazine_date<=rheum_appt_date+183) 
recode ssz_6m .=0
gen ssz_12m = 1 if sulfasalazine==1 & rheum_appt==1 & (sulfasalazine_date<=rheum_appt_date+365)
recode ssz_12m .=0

**Time to first sulfasalazine script for RA patients
gen time_to_ssz=(sulfasalazine_date-rheum_appt_date) if sulfasalazine_date!=. & rheum_appt_date!=. & (sulfasalazine_date<=rheum_appt_date+183)
tabstat time_to_ssz if rheumatoid_inc==1, stats (n mean p50 p25 p75)
tabstat time_to_ssz if psa_inc==1, stats (n mean p50 p25 p75)

**Sulfasalazine time categories  
gen ssz_time=1 if time_to_ssz<=90 & time_to_ssz!=. 
replace ssz_time=2 if time_to_ssz>90 & time_to_ssz<=183 & time_to_ssz!=.
replace ssz_time=3 if time_to_ssz>183 | time_to_ssz==.
lab define ssz_time 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months", modify
lab val ssz_time ssz_time
lab var ssz_time "Sulfasalazine in primary care" 
tab ssz_time if rheumatoid_inc==1, missing 
tab ssz_time if psa_inc==1, missing
tab ssz_time if undiffia_inc==1, missing 

**Check if medication issued >once
gen ssz_shared=1 if ssz==1 & sulfasalazine_count>1
recode ssz_shared .=0
tab ssz_shared

**sulfasalazine use (shared care)
tab ssz_shared if rheumatoid_inc==1 
tab ssz_shared if rheumatoid_inc==1 & (sulfasalazine_date<=rheum_appt_date+183)
tab ssz_shared if psa_inc==1 
tab ssz_shared if psa_inc==1 & (sulfasalazine_date<=rheum_appt_date+183) 
tab ssz_shared if undiffia_inc==1
tab ssz_shared if undiffia_inc==1 & (sulfasalazine_date<=rheum_appt_date+183)

**Check medication issue number
gen ssz_issue=0 if ssz==1 & sulfasalazine_count==0 
replace ssz_issue=1 if ssz==1 & sulfasalazine_count==1 
replace ssz_issue=2 if ssz==1 & sulfasalazine_count>1
tab ssz_issue

**Hydroxychloroquine use
gen hcq=1 if hydroxychloroquine==1
recode hcq .=0
gen hcq_6m = 1 if hydroxychloroquine==1 & rheum_appt==1 & (hydroxychloroquine_date<=rheum_appt_date+183) 
recode hcq_6m .=0
gen hcq_12m = 1 if hydroxychloroquine==1 & rheum_appt==1 & (hydroxychloroquine_date<=rheum_appt_date+365)
recode hcq_12m .=0 

**Time to first hydroxychloroquine script for RA patients
gen time_to_hcq=(hydroxychloroquine_date-rheum_appt_date) if hydroxychloroquine_date!=. & rheum_appt_date!=. & (hydroxychloroquine_date<=rheum_appt_date+183)
tabstat time_to_hcq if rheumatoid_inc==1, stats (n mean p50 p25 p75)
tabstat time_to_hcq if psa_inc==1, stats (n mean p50 p25 p75)

**Hydroxychloroquine time categories  
gen hcq_time=1 if time_to_hcq<=90 & time_to_hcq!=. 
replace hcq_time=2 if time_to_hcq>90 & time_to_hcq<=183 & time_to_hcq!=.
replace hcq_time=3 if time_to_hcq>183 | time_to_hcq==.
lab define hcq_time 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months", modify
lab val hcq_time hcq_time
lab var hcq_time "Hydroxychloroquine in primary care" 
tab hcq_time if rheumatoid_inc==1, missing 
tab hcq_time if psa_inc==1, missing
tab hcq_time if undiffia_inc==1, missing 

**Check if medication issued >once
gen hcq_shared=1 if hcq==1 & hydroxychloroquine_count>1
recode hcq_shared .=0
tab hcq_shared

**hydroxychloroquine use (shared care)
tab hcq_shared if rheumatoid_inc==1 
tab hcq_shared if rheumatoid_inc==1 & (hydroxychloroquine_date<=rheum_appt_date+183)
tab hcq_shared if psa_inc==1 
tab hcq_shared if psa_inc==1 & (hydroxychloroquine_date<=rheum_appt_date+183) 
tab hcq_shared if undiffia_inc==1
tab hcq_shared if undiffia_inc==1 & (hydroxychloroquine_date<=rheum_appt_date+183)

**Check medication issue number
gen hcq_issue=0 if hcq==1 & hydroxychloroquine_count==0 
replace hcq_issue=1 if hcq==1 & hydroxychloroquine_count==1 
replace hcq_issue=2 if hcq==1 & hydroxychloroquine_count>1
tab hcq_issue

**Leflunomide use
gen lef=1 if leflunomide==1
recode lef .=0 
gen lef_6m = 1 if leflunomide==1 & rheum_appt==1 & (leflunomide_date<=rheum_appt_date+183) 
recode lef_6m .=0
gen lef_12m = 1 if leflunomide==1 & rheum_appt==1 & (leflunomide_date<=rheum_appt_date+365)
recode lef_12m .=0 

**Time to first leflunomide script for RA patients
gen time_to_lef=(leflunomide_date-rheum_appt_date) if leflunomide_date!=. & rheum_appt_date!=. & (leflunomide_date<=rheum_appt_date+183)
tabstat time_to_lef if rheumatoid_inc==1, stats (n mean p50 p25 p75)
tabstat time_to_lef if psa_inc==1, stats (n mean p50 p25 p75)

**Leflunomide time categories  
gen lef_time=1 if time_to_lef<=90 & time_to_lef!=. 
replace lef_time=2 if time_to_lef>90 & time_to_lef<=183 & time_to_lef!=.
replace lef_time=3 if time_to_lef>183 | time_to_lef==.
lab define lef_time 1 "Within 3 months" 2 "3-6 months" 3 "No prescription within 6 months", modify
lab val lef_time lef_time
lab var lef_time "Leflunomide in primary care" 
tab lef_time if rheumatoid_inc==1, missing 
tab lef_time if psa_inc==1, missing
tab lef_time if undiffia_inc==1, missing 

**Check if medication issued >once
gen lef_shared=1 if lef==1 & leflunomide_count>1
recode lef_shared .=0
tab lef_shared

**leflunomide use (shared care)
tab lef_shared if rheumatoid_inc==1 
tab lef_shared if rheumatoid_inc==1 & (leflunomide_date<=rheum_appt_date+183)
tab lef_shared if psa_inc==1 
tab lef_shared if psa_inc==1 & (leflunomide_date<=rheum_appt_date+183) 
tab lef_shared if undiffia_inc==1
tab lef_shared if undiffia_inc==1 & (leflunomide_date<=rheum_appt_date+183)

**Check medication issue number
gen lef_issue=0 if lef==1 & leflunomide_count==0 
replace lef_issue=1 if lef==1 & leflunomide_count==1 
replace lef_issue=2 if lef==1 & leflunomide_count>1
tab lef_issue

**For all csDMARDs, check if issued more than once 
gen csdmard_shared=1 if lef_shared==1 | mtx_shared==1 | hcq_shared==1 | ssz_shared==1 
recode csdmard_shared .=0
tab csdmard_shared
tab csdmard //for comparison

**Generate number of csDMARDs by time-points
gen csdmard_num_6m =.
replace csdmard_num_6m = 0 if (mtx_6m + ssz_6m + hcq_6m + lef_6m ==0)
replace csdmard_num_6m = 1 if (mtx_6m + ssz_6m + hcq_6m + lef_6m ==1)
replace csdmard_num_6m = 2 if (mtx_6m + ssz_6m + hcq_6m + lef_6m ==2)
replace csdmard_num_6m = 3 if (mtx_6m + ssz_6m + hcq_6m + lef_6m >2)
lab var csdmard_num_6m "Number of csDMARDs by 6 months"
lab define csdmard_num_6m 0 "0" 1 "1" 2 "2" 3 "3 or more", modify
lab val csdmard_num_6m csdmard_num_6m
tab csdmard_num_6m, missing

gen csdmard_num_12m =.
replace csdmard_num_12m = 0 if (mtx_12m + ssz_12m + hcq_12m + lef_12m ==0)
replace csdmard_num_12m = 1 if (mtx_12m + ssz_12m + hcq_12m + lef_12m ==1)
replace csdmard_num_12m = 2 if (mtx_12m + ssz_12m + hcq_12m + lef_12m ==2)
replace csdmard_num_12m = 3 if (mtx_12m + ssz_12m + hcq_12m + lef_12m >2)
lab var csdmard_num_12m "Number of csDMARDs by 12 months"
lab define csdmard_num_12m 0 "0" 1 "1" 2 "2" 3 "3 or more", modify
lab val csdmard_num_12m csdmard_num_12m
tab csdmard_num_12m, missing

**Generate categories of csDMARDs by time-points
gen csdmard_comb_6m =.
replace csdmard_comb_6m = 0 if (mtx_6m + ssz_6m + hcq_6m + lef_6m ==0)
replace csdmard_comb_6m = 1 if (mtx_6m==1 & ssz_6m!=1 & hcq_6m!=1 & lef_6m!=1)
replace csdmard_comb_6m = 2 if (mtx_6m==1 & (ssz_6m==1 | hcq_6m==1 | lef_6m==1))
replace csdmard_comb_6m = 3 if (mtx_6m!=1 & (ssz_6m==1 | hcq_6m==1 | lef_6m==1))
lab var csdmard_comb_6m "csDMARDs by 6 months"
lab define csdmard_comb_6m 0 "No csDMARDs" 1 "Methotrexate monotherapy" 2 "Methotrexate combination therapy" 3 "Non-methotrexate csDMARD(s)", modify
lab val csdmard_comb_6m csdmard_comb_6m
tab csdmard_comb_6m, missing

gen csdmard_comb_12m =.
replace csdmard_comb_12m = 0 if (mtx_12m + ssz_12m + hcq_12m + lef_12m ==0)
replace csdmard_comb_12m = 1 if (mtx_12m==1 & ssz_12m!=1 & hcq_12m!=1 & lef_12m!=1)
replace csdmard_comb_12m = 2 if (mtx_12m==1 & (ssz_12m==1 | hcq_12m==1 | lef_12m==1))
replace csdmard_comb_12m = 3 if (mtx_12m!=1 & (ssz_12m==1 | hcq_12m==1 | lef_12m==1))
lab var csdmard_comb_12m "csDMARDs by 12 months"
lab define csdmard_comb_12m 0 "No csDMARDs" 1 "Methotrexate monotherapy" 2 "Methotrexate combination therapy" 3 "Non-methotrexate csDMARD(s)", modify
lab val csdmard_comb_12m csdmard_comb_12m
tab csdmard_comb_12m, missing

**Corticosteroid use in primary care within first 12 months of diagnosis (PO, IM or IV), including those where received up to 60 days before diagnostic code
gen steroid_12m = 1 if steroid_12m_first==1
recode steroid_12m .=0
lab define steroid_12m 0 "No" 1 "Yes"
lab val steroid_12m steroid_12m
lab var steroid_12m "Corticosteroids within 12m of diagnosis"
tab steroid_12m, missing
tab eia_diagnosis steroid_12m, missing row

lab var steroid_12m_count "Corticosteroid prescription count within 12m of diagnosis"
bys eia_diagnosis: tabstat steroid_12m_count, stats (n mean p50 p25 p75)

gen steroid_12m_cat=0 if steroid_12m_count==0
replace steroid_12m_cat=1 if steroid_12m_count==1
replace steroid_12m_cat=2 if steroid_12m_count==2
replace steroid_12m_cat=3 if steroid_12m_count>=3
lab var steroid_12m_cat "Corticosteroid prescription count within 12m of diagnosis"
tab steroid_12m_cat, missing
tab eia_diagnosis steroid_12m_cat, missing row

**Time to first steroid in primary care, with respect to first rheum appt (from -60 days to +365 days from EIA code date)
gen time_to_steroid_12m = (steroid_12m_first_date-rheum_appt_date) if steroid_12m_first_date!=. & rheum_appt_date!=.
tabstat time_to_steroid_12m, stats (n mean p50 p25 p75)
bys eia_diagnosis: tabstat time_to_steroid_12m, stats (n mean p50 p25 p75)

gen time_to_steroid_cat = 1 if time_to_steroid_12m>=-60 & time_to_steroid_12m<0
replace time_to_steroid_cat = 2 if time_to_steroid_12m>=0 & time_to_steroid_12m<30
replace time_to_steroid_cat = 3 if time_to_steroid_12m>=30 & time_to_steroid_12m<183
replace time_to_steroid_cat = 4 if time_to_steroid_12m>=183 & time_to_steroid_12m<365
replace time_to_steroid_cat = 5 if time_to_steroid_12m>=365 | time_to_steroid_12m==.

lab define time_to_steroid_cat 1 "Up to 60 days before diagnosis" 2 "Up to 30 days after diagnosis" 3 "Between 30 days and 6m after diagnosis" 4 "Between 6m and 12m after diagnosis" 5 "No steroid within 12m of diagnosis"
lab val time_to_steroid_cat time_to_steroid_cat
lab var time_to_steroid_cat "Timing of first primary care steroid"
tab time_to_steroid_cat, missing
tab eia_diagnosis time_to_steroid_cat, missing row

**Time to first biologic script; high_cost drug data available to Nov 2020. Not for analysis currently due to small numbers======================================================================*/

/* 
*Below analyses are only for patients with at least 12 months of follow-up available after rheum appt
gen time_to_biologic=(biologic_date-rheum_appt_date) if biologic==1 & rheum_appt_date!=. & (biologic_date<=rheum_appt_date+365)
tabstat time_to_biologic, stats (n mean p50 p25 p75) //for all EIA patients


**What was first biologic
gen first_bio=""
foreach var of varlist abatacept_date adalimumab_date baricitinib_date certolizumab_date etanercept_date golimumab_date guselkumab_date infliximab_date ixekizumab_date rituximab_date sarilumab_date secukinumab_date tocilizumab_date tofacitinib_date upadacitinib_date ustekinumab_date {
	replace first_bio="`var'" if biologic_date==`var' & biologic_date!=.
	}
gen first_biologic = substr(first_bio, 1, length(first_bio) - 5)	
drop first_bio
tab first_biologic //for all EIA patients

**Biologic time categories (for all patients)
gen biologic_time=1 if time_to_biologic<=183 & time_to_biologic!=. 
replace biologic_time=2 if time_to_biologic>183 & time_to_biologic<=365 & time_to_biologic!=.
replace biologic_time=3 if time_to_biologic>365 | time_to_biologic==.
lab define biologic_time 1 "Within 6 months" 2 "6-12 months" 3 "No prescription within 12 months", modify
lab val biologic_time biologic_time
lab var biologic_time "bDMARD/tsDMARD prescription" 
tab biologic_time

**Biologic time categories (by year)
bys diagnosis_6m: tab biologic_time
*/

save "$projectdir/output/data/file_eia_all", replace

log close
