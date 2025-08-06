from ehrql import create_dataset, days, months, years, case, when
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, addresses, appointments, opa, wl_clockstops, wl_openpathways
from datetime import date
import codelists_ehrQL as codelists
from analysis.dataset_definition_incidence import create_dataset_with_variables, get_population

dataset = create_dataset_with_variables()

# Dates for study
index_date = "2016-04-01"
end_date = "2025-03-31"
fup_date = "2025-07-31"

# Seropositive/erosive diagnostic code (last match before study end date)
def last_code_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date.is_on_or_before(fup_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.rf_code_date = last_code_in_period(codelists.rf_codes).date
dataset.ccp_code_date = last_code_in_period(codelists.ccp_codes).date
dataset.seropositive_code_date = last_code_in_period(codelists.seropositive_codes).date
dataset.erosive_ra_code_date = last_code_in_period(codelists.erosive_codes).date

# Relevant blood tests for rheumatoid factor or CCP (last recorded value in study period)
def any_test_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date.is_on_or_before(fup_date)        
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.rf_test_value=any_test_in_period(codelists.rf_tests).numeric_value
dataset.rf_test_date=any_test_in_period(codelists.rf_tests).date

dataset.ccp_test_value=any_test_in_period(codelists.ccp_tests).numeric_value
dataset.ccp_test_date=any_test_in_period(codelists.ccp_tests).date

# Baseline comorbidities (first match before rheum diagnostic code; uses NHSE Ref Sets)
def baseline_comorbidity_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= getattr(dataset, "eia_inc_date")
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.chd_before_date=baseline_comorbidity_in_period(codelists.chd_codes).date
dataset.dm_before_date=baseline_comorbidity_in_period(codelists.diabetes_codes).date
dataset.ild_before_date=baseline_comorbidity_in_period(codelists.ild_codes).date
dataset.copd_before_date=baseline_comorbidity_in_period(codelists.copd_codes).date
dataset.cva_before_date=baseline_comorbidity_in_period(codelists.cva_codes).date
dataset.lung_ca_before_date=baseline_comorbidity_in_period(codelists.lung_cancer_codes).date
dataset.solid_ca_before_date=baseline_comorbidity_in_period(codelists.solid_cancer_codes).date
dataset.haem_ca_before_date=baseline_comorbidity_in_period(codelists.haem_cancer_codes).date
dataset.ckd_before_date=baseline_comorbidity_in_period(codelists.ckd_codes).date
dataset.depr_before_date=baseline_comorbidity_in_period(codelists.depression_codes).date
dataset.osteop_before_date=baseline_comorbidity_in_period(codelists.osteoporosis_codes).date
dataset.frac_before_date=baseline_comorbidity_in_period(codelists.fracture_codes).date
dataset.dem_before_date=baseline_comorbidity_in_period(codelists.dementia_codes).date

# New comorbidities (first match after rheum diagnostic code and before study end date; uses NHSE Ref Sets)
def new_comorbidity_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        (clinical_events.date > getattr(dataset, "eia_inc_date")) & (clinical_events.date.is_on_or_before(fup_date))
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.chd_after_date=new_comorbidity_in_period(codelists.chd_codes).date
dataset.dm_after_date=new_comorbidity_in_period(codelists.diabetes_codes).date
dataset.ild_after_date=new_comorbidity_in_period(codelists.ild_codes).date
dataset.copd_after_date=new_comorbidity_in_period(codelists.copd_codes).date
dataset.cva_after_date=new_comorbidity_in_period(codelists.cva_codes).date
dataset.lung_ca_after_date=new_comorbidity_in_period(codelists.lung_cancer_codes).date
dataset.solid_ca_after_date=new_comorbidity_in_period(codelists.solid_cancer_codes).date
dataset.haem_ca_after_date=new_comorbidity_in_period(codelists.haem_cancer_codes).date
dataset.ckd_after_date=new_comorbidity_in_period(codelists.ckd_codes).date
dataset.depr_after_date=new_comorbidity_in_period(codelists.depression_codes).date
dataset.osteop_after_date=new_comorbidity_in_period(codelists.osteoporosis_codes).date
dataset.frac_after_date=new_comorbidity_in_period(codelists.fracture_codes).date
dataset.dem_after_date=new_comorbidity_in_period(codelists.dementia_codes).date

# Relevant blood tests at baseline (last match before rheum diagnostic code)
def last_test_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= getattr(dataset, "eia_inc_date")
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.creatinine_value=last_test_in_period(codelists.creatinine_codes).numeric_value
dataset.creatinine_date=last_test_in_period(codelists.creatinine_codes).date

# BMI within 10 years prior to diagnosis date
bmi_record = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.bmi_codes)
    ).where(
        clinical_events.date >= (patients.date_of_birth + years(16))
    ).where(
        (clinical_events.date >= (getattr(dataset, "eia_inc_date") - years(10))) & (clinical_events.date <= getattr(dataset, "eia_inc_date"))
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.bmi_value = bmi_record.numeric_value
dataset.bmi_date = bmi_record.date

# Smoking status at or before diagnosis
dataset.most_recent_smoking_code=clinical_events.where(
        clinical_events.ctv3_code.is_in(codelists.clear_smoking_codes)
    ).where(
        clinical_events.date <= getattr(dataset, "eia_inc_date")
    ).sort_by(
        clinical_events.date
    ).last_for_patient().ctv3_code.to_category(codelists.clear_smoking_codes)

def filter_codes_by_category(codelist, include):
    return {k:v for k,v in codelist.items() if v in include}

dataset.ever_smoked=clinical_events.where(
        clinical_events.ctv3_code.is_in(filter_codes_by_category(codelists.clear_smoking_codes, include=["S", "E"]))
    ).where(
        clinical_events.date <= getattr(dataset, "eia_inc_date")
    ).exists_for_patient()

dataset.smoking_status=case(
    when(dataset.most_recent_smoking_code == "S").then("S"),
    when((dataset.most_recent_smoking_code == "E") | ((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == True))).then("E"),
    when((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == False)).then("N"),
    otherwise="M"
)

# Rheumatology outpatient appointments
## Date of first rheum appointment in the 1 year before or after rheum diagnostic code (with first attendance options selected)
rheum_appt = opa.where(
        (opa.appointment_date >= (getattr(dataset, "eia_inc_date") - years(1))) &
        (opa.appointment_date <= (getattr(dataset, "eia_inc_date") + years(1))) &
        (opa.appointment_date.is_on_or_before(fup_date)) &
        (opa.treatment_function_code == "410") &
        ((opa.first_attendance == "1") | (opa.first_attendance == "3"))
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_date = rheum_appt.appointment_date
dataset.rheum_appt_medium = rheum_appt.consultation_medium_used

## Date of first rheum appointment in the 1 year before or after rheum diagnostic code (without first attendance option selected)
rheum_appt_any = opa.where(
        (opa.appointment_date >= (getattr(dataset, "eia_inc_date") - years(1))) &
        (opa.appointment_date <= (getattr(dataset, "eia_inc_date") + years(1))) &
        (opa.appointment_date.is_on_or_before(fup_date)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_any_date = rheum_appt_any.appointment_date

## Rheum appointment count in the 1 year after first rheum appt (without first attendance option selected)
dataset.rheum_appt_count = opa.where(
        (opa.appointment_date >= dataset.rheum_appt_date) &
        (opa.appointment_date <= (dataset.rheum_appt_date + years(1))) &
        (opa.appointment_date.is_on_or_before(fup_date)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).count_for_patient()

# Rheumatology referrals
## Rheumatology referral date using HES OP data
dataset.rheum_appt_ref_date = rheum_appt.referral_request_received_date
dataset.rheum_any_ref_date = rheum_appt_any.referral_request_received_date

## Last referral in the 12 months before rheumatology outpatient appt
dataset.ref_12m_preappt_date = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.rheum_appt_date - years(1))) & (clinical_events.date <= dataset.rheum_appt_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

## Last referral in the 6 months before rheumatology outpatient appt
dataset.ref_6m_preappt_date = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.rheum_appt_date - months(6))) & (clinical_events.date <= dataset.rheum_appt_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

# GP consultations removed

# Most recent practice registration that lasted more than 12 months prior to rheum diagnosis
def preceding_registration(dx_date):
    return practice_registrations.where(
        practice_registrations.start_date.is_on_or_before(dx_date - months(12))
    ).except_where(
        practice_registrations.end_date.is_on_or_before(dx_date)
    ).sort_by(
        practice_registrations.start_date,
        practice_registrations.end_date,
        practice_registrations.practice_pseudo_id,
    ).last_for_patient()

dataset.reg_end_date = preceding_registration(getattr(dataset, "eia_inc_date")).end_date

# Practice region
dataset.region = preceding_registration(getattr(dataset, "eia_inc_date")).practice_nuts1_region_name

# Medications
## Dates and counts of csDMARD prescriptions before end date (individuals with prescriptions of csDMARDs before first rheum code are excluded in data processing stages)
def medication_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(fup_date)
    ).sort_by(
            medications.date
    )

### First prescriptions
dataset.leflunomide_date = medication_dates_dmd(codelists.leflunomide_codes).first_for_patient().date
dataset.methotrexate_oral_date = medication_dates_dmd(codelists.methotrexate_codes).first_for_patient().date
dataset.methotrexate_inj_date = medication_dates_dmd(codelists.methotrexate_inj_codes).first_for_patient().date
dataset.sulfasalazine_date = medication_dates_dmd(codelists.sulfasalazine_codes).first_for_patient().date
dataset.hydroxychloroquine_date = medication_dates_dmd(codelists.hydroxychloroquine_codes).first_for_patient().date

### Last prescriptions before end date
dataset.lef_last_date = medication_dates_dmd(codelists.leflunomide_codes).last_for_patient().date
dataset.mtx_oral_last_date = medication_dates_dmd(codelists.methotrexate_codes).last_for_patient().date
dataset.mtx_inj_last_date = medication_dates_dmd(codelists.methotrexate_inj_codes).last_for_patient().date
dataset.ssz_last_date = medication_dates_dmd(codelists.sulfasalazine_codes).last_for_patient().date
dataset.hcq_last_date = medication_dates_dmd(codelists.hydroxychloroquine_codes).last_for_patient().date

### Count of prescriptions before end date - need to amend this to within a 12-month period (after diagnosis vs. first script)
dataset.leflunomide_count = medication_dates_dmd(codelists.leflunomide_codes).count_for_patient()
dataset.methotrexate_oral_count = medication_dates_dmd(codelists.methotrexate_codes).count_for_patient()
dataset.methotrexate_inj_count = medication_dates_dmd(codelists.methotrexate_inj_codes).count_for_patient()
dataset.sulfasalazine_count = medication_dates_dmd(codelists.sulfasalazine_codes).count_for_patient()
dataset.hydroxychloroquine_count = medication_dates_dmd(codelists.hydroxychloroquine_codes).count_for_patient()

## Dates and count of steroid prescriptions (oral, IM, IV) within 60 days before rheum code date and before end date
def steroid_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(fup_date)
    ).except_where( 
            medications.date < (getattr(dataset, "eia_inc_date") - days(60))
    ).sort_by(
            medications.date
    )

dataset.steroid_first_date = steroid_dates_dmd(codelists.steroid_codes).first_for_patient().date
dataset.steroid_last_date = steroid_dates_dmd(codelists.steroid_codes).last_for_patient().date
dataset.steroid_count = steroid_dates_dmd(codelists.steroid_codes).count_for_patient()

### Same as the above, but limited up to 12 months after diagnosis date
def steroid_12m_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(fup_date) &  
            medications.date.is_on_or_before(getattr(dataset, "eia_inc_date") + years(1))  
    ).except_where( 
            medications.date < (getattr(dataset, "eia_inc_date") - days(60))
    ).sort_by(
            medications.date
    )

dataset.steroid_12m_first_date = steroid_12m_dates_dmd(codelists.steroid_codes).first_for_patient().date
dataset.steroid_12m_last_date = steroid_12m_dates_dmd(codelists.steroid_codes).last_for_patient().date
dataset.steroid_12m_count = steroid_12m_dates_dmd(codelists.steroid_codes).count_for_patient()

incidence_dataset_population = get_population(dataset)

# Define study population
dataset.define_population(
    incidence_dataset_population &
    (getattr(dataset, "eia_inc_case")) &
    ((getattr(dataset, "eia_age") >= 18) & (getattr(dataset, "eia_age") <= 110)) &
    (getattr(dataset, "eia_pre_reg")) &
    (getattr(dataset, "eia_alive_inc"))
)