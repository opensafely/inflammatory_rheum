version 16

/*==============================================================================
DO FILE NAME:			Produce data tables from GCA dataset
PROJECT:				Inflammatory Rheum OpenSAFELY project
DATE: 					20/05/2025
AUTHOR:					M Russell									
DESCRIPTION OF FILE:	Data tables for GCA cohort 
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
global comorbidities "ocular aortic chd cva osteop frac pmr dm ckd htn ccf depr dem"

*Define medications of interest
global medications "steroid prednisolone methotrexate leflunomide"

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
	global studyfup_date "2026-03-31"
}

di "$studystart_date"
di "$studyend_date"
di "$studyfup_date"

set type double

set scheme plotplainblind

*Open a log file
global logdir "$projectdir/logs"
cap log close
log using "$logdir/${disease}_datatables.log", replace

*Function to generate a rounded and redacted data table for binary variables of interest, collapsed by year, for full cohort ======================*/
program define rounded_datatable
    syntax varlist(min=1 max=1), timevar(name)
	local var `varlist'
	local time_variable `timevar'
		
	preserve	
		**Store variable label
		local v : variable label `var'
		
		**Collapse dataset by variable of interest (have to be binary variables: yes 1 and no 0)
		collapse (sum) count_un=`var' (count) total_un=`var', by(`time_variable')

		**Round and redact counts
		*gen count_all=count_un
		gen count_all=round(count_un, 5)
		replace count_all = . if count_all<=7
		drop count_un
		*gen total_all=total_un
		gen total_all=round(total_un, 5)
		replace total_all = . if count_all==.
		drop total_un
		gen prop_all = count_all/total_all

		**Save variable name and labels
		gen outcome_name = "`var'"
		gen outcome_desc = "`v'"
		order outcome_name, first
		order outcome_desc, after(outcome_name)
		rename `time_variable' month_year

		**Save temporary dataset
		capture append using "$projectdir/output/data/data_table.dta"
		save "$projectdir/output/data/data_table.dta", replace	
	restore
end

*Baseline data table (no additional inclusion criteria) =================================*/

**Erase any existing data file
capture erase "$projectdir/output/data/data_table.dta"

**Import cleaned/processed cohort
use "$projectdir/output/data/gca_processed.dta", clear

**Set time variable
local time_variable "${disease}_year"
di "`time_variable'"

**Store variables of interest
local comorbidity_bl

foreach var of global comorbidities {
    local comorbidity_bl "`comorbidity_bl' `var'_bl"
}

local medication_bl

foreach var of global medications {
    local medication_bl "`medication_bl' `var'_bl"
}

**Loop through outcomes of interest for full cohort (have to be binary variables: yes 1 and no 0)
foreach var of varlist `comorbidity_bl' `medication_bl' rheum_appt rheum_appt_any has_12m_fup {
	rounded_datatable `var', timevar(`time_variable')
}

**Export rounded/redacted data table
use "$projectdir/output/data/data_table.dta", clear
export delimited using "$projectdir/output/tables/gca_datatable_baseline.csv", replace

*Events occurring after diagnosis (restricted to those with t months follow-up) =================================*/

**Erase any existing data file
capture erase "$projectdir/output/data/data_table.dta"

**Loop through time periods of interest
foreach t in 12 {
	
	**Import cleaned/processed cohort
	use "$projectdir/output/data/gca_processed.dta", clear

	**Set inclusion criteria - limited to those who had at least t months duration of follow-up post-diagnosis
	keep if has_`t'm_fup==1

	**Set time variable
	local time_variable "${disease}_year"
	
	**Store variables of interest
	local comorbidity_new12m

	foreach var of global comorbidities {
		local comorbidity_new12m "`comorbidity_new12m' `var'_new12m"
	}
	
	local comorbidity_after12m

	foreach var of global comorbidities {
		local comorbidity_after12m "`comorbidity_after12m' `var'_after12m"
	}
	
	local medication_12m

	foreach var of global medications {
		local medication_12m "`medication_12m' `var'_12m"
	}

	
	**Loop through outcomes of interest for full cohort (have to be binary variables: yes 1 and no 0)
	foreach var of varlist death_new12m `comorbidity_new12m' `comorbidity_after12m' `medication_12m' {
		rounded_datatable `var', timevar(`time_variable')
	}
	
}

**Export rounded/redacted data table
use "$projectdir/output/data/data_table.dta", clear
export delimited using "$projectdir/output/tables/gca_datatable_postdiagnosis.csv", replace

log close
