from ehrql import create_dataset, days, months, years, case, when
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, addresses, appointments, opa, wl_clockstops, wl_openpathways
from datetime import date
import codelists_ehrQL as codelists

# Dates for study
start_date = "2016-04-01"
end_date = "2025-03-31"

dataset = create_dataset()

dataset.configure_dummy_data(population_size=10000, legacy=True)

# First rheum diagnostic code in primary care record
def first_code_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

## Combined diagnoses
dataset.eia_code_date = first_code_in_period(codelists.eia_diagnosis_codes).date
dataset.eia_code_snomed = first_code_in_period(codelists.eia_diagnosis_codes).snomedct_code

## Individual diagnoses
dataset.ra_code_date = first_code_in_period(codelists.rheumatoid_arthritis_codes).date
dataset.psa_code_date = first_code_in_period(codelists.psoriatic_arthritis_codes).date
dataset.anksp_code_date = first_code_in_period(codelists.ankylosing_spondylitis_codes).date
dataset.undiff_code_date = first_code_in_period(codelists.undifferentiated_arthritis_codes).date

## RF, CCP and/or seropositive RA codes
dataset.rf_code_date = first_code_in_period(codelists.rf_codes).date
dataset.ccp_code_date = first_code_in_period(codelists.ccp_codes).date
dataset.seropositive_code_date = first_code_in_period(codelists.seropositive_codes).date

## Erosive RA codes
dataset.erosive_ra_code_date = first_code_in_period(codelists.erosive_codes).date

# Count of diagnostic codes in primary care record - could be used for sensitivity of those with 2+ codes
def count_code_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date.is_on_or_before(end_date)
    ).except_where(
        clinical_events.date.is_before(start_date)
    ).count_for_patient()

# Count for combined and individual diagnoses
dataset.eia_code_count = count_code_in_period(codelists.eia_diagnosis_codes)
dataset.ra_code_count = count_code_in_period(codelists.rheumatoid_arthritis_codes)
dataset.psa_code_count = count_code_in_period(codelists.psoriatic_arthritis_codes)
dataset.anksp_code_count = count_code_in_period(codelists.ankylosing_spondylitis_codes)
dataset.undiff_code_count = count_code_in_period(codelists.undifferentiated_arthritis_codes)

# Date of death
dataset.date_of_death = patients.date_of_death

# Demographics
dataset.age = patients.age_on(dataset.eia_code_date)

dataset.sex = patients.sex

latest_ethnicity_code = (
    clinical_events.where(clinical_events.snomedct_code.is_in(codelists.ethnicity_codes))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient().snomedct_code.to_category(codelists.ethnicity_codes)
)

dataset.ethnicity = case(
    when(latest_ethnicity_code == "1").then("White"),
    when(latest_ethnicity_code == "2").then("Mixed"),
    when(latest_ethnicity_code == "3").then("Asian or Asian British"),
    when(latest_ethnicity_code == "4").then("Black or Black British"),
    when(latest_ethnicity_code == "5").then("Chinese or Other Ethnic Groups"),
    otherwise="Unknown",
)

latest_address_per_patient = addresses.sort_by(addresses.start_date).last_for_patient()
imd_rounded = latest_address_per_patient.imd_rounded
dataset.imd_quintile = case(
    when((imd_rounded >= 0) & (imd_rounded < int(32844 * 1 / 5))).then("1 (most deprived)"),
    when(imd_rounded < int(32844 * 2 / 5)).then("2"),
    when(imd_rounded < int(32844 * 3 / 5)).then("3"),
    when(imd_rounded < int(32844 * 4 / 5)).then("4"),
    when(imd_rounded < int(32844 * 5 / 5)).then("5 (least deprived)"),
    otherwise="Unknown",
)

# Practice registration for more than 12 months prior to inflamm rheum diagnosis
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

dataset.pre_reg = preceding_registration(dataset.eia_code_date).exists_for_patient()

# Practice region
dataset.region = preceding_registration(dataset.eia_code_date).practice_nuts1_region_name

# Define study population
dataset.define_population(
    ((dataset.eia_code_date >= start_date) & (dataset.eia_code_date <= end_date)) &
    ((dataset.age >= 18) & (dataset.age <= 110)) &
    (dataset.pre_reg) &
    (dataset.sex.is_in(["male", "female"]))
)

# Baseline comorbidities (first match before rheum diagnostic code); uses NHSE Ref Sets
def first_comorbidity_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.chd_before_date=first_comorbidity_in_period(codelists.chd_codes).date
dataset.dm_before_date=first_comorbidity_in_period(codelists.diabetes_codes).date
dataset.ild_before_date=first_comorbidity_in_period(codelists.ild_codes).date
dataset.copd_before_date=first_comorbidity_in_period(codelists.copd_codes).date
dataset.cva_before_date=first_comorbidity_in_period(codelists.cva_codes).date
dataset.lung_ca_before_date=first_comorbidity_in_period(codelists.lung_cancer_codes).date
dataset.solid_ca_before_date=first_comorbidity_in_period(codelists.solid_cancer_codes).date
dataset.haem_ca_before_date=first_comorbidity_in_period(codelists.haem_cancer_codes).date
dataset.ckd_before_date=first_comorbidity_in_period(codelists.ckd_codes).date
dataset.depr_before_date=first_comorbidity_in_period(codelists.depression_codes).date
dataset.osteop_before_date=first_comorbidity_in_period(codelists.osteoporosis_codes).date
dataset.frac_before_date=first_comorbidity_in_period(codelists.fracture_codes).date
dataset.dem_before_date=first_comorbidity_in_period(codelists.dementia_codes).date

# Subsequent comorbidities (first match after rheum diagnostic code); uses NHSE Ref Sets
def new_comorbidity_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date > dataset.eia_code_date
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

# Relevant blood tests (last match before rheum diagnostic code)
def last_test_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.creatinine_value=last_test_in_period(codelists.creatinine_codes).numeric_value
dataset.creatinine_date=last_test_in_period(codelists.creatinine_codes).date

# Relevant blood tests for rheumatoid factor or CCP (no time restriction; takes last recorded value in study period)
def any_test_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.rf_test_value=any_test_in_period(codelists.rf_tests).numeric_value
dataset.rf_test_date=any_test_in_period(codelists.rf_tests).date

dataset.ccp_test_value=any_test_in_period(codelists.ccp_tests).numeric_value
dataset.ccp_test_date=any_test_in_period(codelists.ccp_tests).date

# BMI
bmi_record = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.bmi_codes)
    ).where(
        clinical_events.date >= (patients.date_of_birth + years(16))
    ).where(
        (clinical_events.date >= (dataset.eia_code_date - years(10))) & (clinical_events.date <= dataset.eia_code_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.bmi_value = bmi_record.numeric_value
dataset.bmi_date = bmi_record.date

## Smoking status
dataset.most_recent_smoking_code=clinical_events.where(
        clinical_events.ctv3_code.is_in(codelists.clear_smoking_codes)
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).sort_by(
        clinical_events.date
    ).last_for_patient().ctv3_code.to_category(codelists.clear_smoking_codes)

def filter_codes_by_category(codelist, include):
    return {k:v for k,v in codelist.items() if v in include}

dataset.ever_smoked=clinical_events.where(
        clinical_events.ctv3_code.is_in(filter_codes_by_category(codelists.clear_smoking_codes, include=["S", "E"]))
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).exists_for_patient()

dataset.smoking_status=case(
    when(dataset.most_recent_smoking_code == "S").then("S"),
    when((dataset.most_recent_smoking_code == "E") | ((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == True))).then("E"),
    when((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == False)).then("N"),
    otherwise="M"
)

# Rheumatology outpatient appointments
## Date of first rheum appointment in the 1 year before rheum diagnostic code (with first attendance options selected)
rheum_appt = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410") &
        ((opa.first_attendance == "1") | (opa.first_attendance == "3"))
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_date = rheum_appt.appointment_date
dataset.rheum_appt_medium = rheum_appt.consultation_medium_used
dataset.rheum_appt_ref_date = rheum_appt.referral_request_received_date

## Date of first rheum appointment in the 1 year before rheum diagnostic code (without first attendance option selected)
dataset.rheum_appt_any_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Rheum appointment count in the 1 year before rheum diagnostic code (without first attendance option selected)
dataset.rheum_appt_count = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).count_for_patient()

## Date of first rheum appointment in the 6 months before rheum diagnostic code (without first attendance option selected)
dataset.rheum_appt2_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - months(6))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Date of first rheum appointment in the 2 years before rheum diagnostic code (without first attendance option selected)
dataset.rheum_appt3_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(2))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Date of first rheum appointment in the 2 years before rheum diagnostic code and up to 1 year after (without first attendance option selected)
dataset.rheum_appt4_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(2))) &
        (opa.appointment_date <= dataset.eia_code_date + years(1)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

# Rheumatology referrals
## Last referral in the 2 years before rheumatology outpatient
dataset.rheum_ref_gp_preappt_date = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.rheum_appt_date - years(2))) & (clinical_events.date <= dataset.rheum_appt_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

## Last referral in the 2 years before rheum diagnostic code
dataset.rheum_ref_gp_precode_date = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.eia_code_date - years(2))) & (clinical_events.date <= dataset.eia_code_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

# GP consultations
## This replicates status codes used in cohort_extractor for consultations that occurred
cohort_extractor_appointment_statuses = [
    "Arrived",
    "In Progress",
    "Finished",
    "Visit",
    "Waiting",
    "Patient Walked Out",
]

## Last GP consultation in the 2 years before rheumatology outpatient appt
dataset.last_gp_prerheum_date = appointments.where(
        (appointments.status.is_in(cohort_extractor_appointment_statuses)) &
        (appointments.start_date >= (dataset.rheum_appt_date - years(2))) &
        (appointments.start_date <= dataset.rheum_appt_date)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

## Last GP consultation in the 2 years before rheum diagnostic code
dataset.last_gp_precode_date = appointments.where(
        (appointments.status.is_in(cohort_extractor_appointment_statuses)) &
        (appointments.start_date >= (dataset.eia_code_date - years(2))) &
        (appointments.start_date <= dataset.eia_code_date)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

## Last GP consultation in the 2 years before rheum ref pre-appt
dataset.last_gp_refrheum_date = appointments.where(
        (appointments.status.is_in(cohort_extractor_appointment_statuses)) &
        (appointments.start_date >= (dataset.rheum_ref_gp_preappt_date - years(2))) &
        (appointments.start_date <= dataset.rheum_ref_gp_preappt_date)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

## Last GP consultation in the 2 years before rheum ref pre-code
dataset.last_gp_refcode_date = appointments.where(
        (appointments.status.is_in(cohort_extractor_appointment_statuses)) &
        (appointments.start_date >= (dataset.rheum_ref_gp_precode_date - years(2))) &
        (appointments.start_date <= dataset.rheum_ref_gp_precode_date)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

# Follow-up registration (6m/12m after rheumatology appointment)
dataset.has_6m_follow_up = practice_registrations.where(
        ((preceding_registration(dataset.eia_code_date).end_date.is_not_null()) & (preceding_registration(dataset.eia_code_date).end_date >= (dataset.rheum_appt_date + months(6))) & ((dataset.rheum_appt_date + months(6)) <= end_date)) |
        ((preceding_registration(dataset.eia_code_date).end_date.is_null()) & ((dataset.rheum_appt_date + months(6)) <= end_date))
    ).exists_for_patient()

dataset.has_12m_follow_up = practice_registrations.where(
        ((preceding_registration(dataset.eia_code_date).end_date.is_not_null()) & (preceding_registration(dataset.eia_code_date).end_date >= (dataset.rheum_appt_date + months(12))) & ((dataset.rheum_appt_date + months(12)) <= end_date)) |
        ((preceding_registration(dataset.eia_code_date).end_date.is_null()) & ((dataset.rheum_appt_date + months(12)) <= end_date))
    ).exists_for_patient()

# Medications
## Dates and counts of csDMARD prescriptions before end date (those with prescriptions of csDMARDs more than 60 days before first EIA code are excluded in data processing stages)
def medication_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(end_date)
    ).sort_by(
            medications.date
    )

### First prescriptions
dataset.leflunomide_date = medication_dates_dmd(codelists.leflunomide_codes).first_for_patient().date
dataset.methotrexate_oral_date = medication_dates_dmd(codelists.methotrexate_codes).first_for_patient().date
dataset.methotrexate_inj_date = medication_dates_dmd(codelists.methotrexate_inj_codes).first_for_patient().date
dataset.sulfasalazine_date = medication_dates_dmd(codelists.sulfasalazine_codes).first_for_patient().date
dataset.hydroxychloroquine_date = medication_dates_dmd(codelists.hydroxychloroquine_codes).first_for_patient().date

## Last prescriptions before end date
dataset.lef_last_date = medication_dates_dmd(codelists.leflunomide_codes).last_for_patient().date
dataset.mtx_oral_last_date = medication_dates_dmd(codelists.methotrexate_codes).last_for_patient().date
dataset.mtx_inj_last_date = medication_dates_dmd(codelists.methotrexate_inj_codes).last_for_patient().date
dataset.ssz_last_date = medication_dates_dmd(codelists.sulfasalazine_codes).last_for_patient().date
dataset.hcq_last_date = medication_dates_dmd(codelists.hydroxychloroquine_codes).last_for_patient().date

## Count of prescriptions before end date
dataset.leflunomide_count = medication_dates_dmd(codelists.leflunomide_codes).count_for_patient()
dataset.methotrexate_oral_count = medication_dates_dmd(codelists.methotrexate_codes).count_for_patient()
dataset.methotrexate_inj_count = medication_dates_dmd(codelists.methotrexate_inj_codes).count_for_patient()
dataset.sulfasalazine_count = medication_dates_dmd(codelists.sulfasalazine_codes).count_for_patient()
dataset.hydroxychloroquine_count = medication_dates_dmd(codelists.hydroxychloroquine_codes).count_for_patient()

## Steroids
### Dates and count of steroid prescriptions (oral, IM, IV) within 60 days before EIA code date and before end date
def steroid_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(end_date)
    ).except_where( 
            medications.date < (dataset.eia_code_date - days(60))
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
            medications.date.is_on_or_before(end_date) &  
            medications.date.is_on_or_before(dataset.eia_code_date + years(1))  
    ).except_where( 
            medications.date < (dataset.eia_code_date - days(60))
    ).sort_by(
            medications.date
    )

dataset.steroid_12m_first_date = steroid_12m_dates_dmd(codelists.steroid_codes).first_for_patient().date
dataset.steroid_12m_last_date = steroid_12m_dates_dmd(codelists.steroid_codes).last_for_patient().date
dataset.steroid_12m_count = steroid_12m_dates_dmd(codelists.steroid_codes).count_for_patient()

## Will also need a high_cost_drugs function (MM-YY)

# RTT dates -  all completed referral-to-treatment (RTT) pathways with a "clock stop" date between May 2021 and May 2022
## Search for first rheumatology RTT from 1 year before EIA code date
rtt_closed = wl_clockstops.where(
        (wl_clockstops.referral_to_treatment_period_start_date >= (dataset.eia_code_date - years(1))) & 
        #(wl_clockstops.referral_to_treatment_period_start_date <= (dataset.eia_code_date + days(60))) &
        (wl_clockstops.activity_treatment_function_code.is_in(["410"]))
    ).sort_by(
        wl_clockstops.referral_to_treatment_period_start_date,
    ).first_for_patient()

# # Also consider need for these limits if we only need start date - exclude rows with missing dates/dates outside study period/end date before start date
# clockstops = wl_clockstops.where(
#         wl_clockstops.referral_to_treatment_period_end_date.is_on_or_between("2021-05-01", "2022-05-01")
#         & wl_clockstops.referral_to_treatment_period_start_date.is_on_or_before(wl_clockstops.referral_to_treatment_period_end_date)
#         & wl_clockstops.week_ending_date.is_on_or_between("2021-05-01", "2022-05-01")
#         & wl_clockstops.waiting_list_type.is_in(["IRTT","ORTT","PTLO","PTLI","PLTI","RTTO","RTTI","PTL0","PTL1"])
    # )

dataset.rtt_cl_start_date = rtt_closed.referral_to_treatment_period_start_date
dataset.rtt_cl_ref_date = rtt_closed.referral_request_received_date
dataset.rtt_cl_end_date = rtt_closed.referral_to_treatment_period_end_date
dataset.rtt_cl_wait = (dataset.rtt_cl_end_date - dataset.rtt_cl_start_date).days

# And RTT open pathways - snapshot May 2022
rtt_open = wl_openpathways.where(
        (wl_openpathways.referral_to_treatment_period_start_date >= (dataset.eia_code_date - years(1))) & 
        #(wl_openpathways.referral_to_treatment_period_start_date <= (dataset.eia_code_date + days(60))) &
        (wl_openpathways.activity_treatment_function_code.is_in(["410"]))
    ).sort_by(
        wl_openpathways.referral_to_treatment_period_start_date,
    ).first_for_patient()

dataset.rtt_op_start_date = rtt_open.referral_to_treatment_period_start_date
dataset.rtt_op_ref_date = rtt_open.referral_request_received_date
dataset.rtt_op_end_date = rtt_open.referral_to_treatment_period_end_date
dataset.rtt_op_wait = (dataset.rtt_op_end_date - dataset.rtt_op_start_date).days