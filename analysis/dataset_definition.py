from ehrql import create_dataset, days, months, years, case, when
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, addresses, ons_deaths, appointments, opa, wl_clockstops
from datetime import date
import codelists_ehrQL as codelists

# Dates for study
start_date = "2019-04-01"
end_date = "2023-10-01"

dataset = create_dataset()

dataset.configure_dummy_data(population_size=700000)

# First EIA code in primary care record
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

# Demographics
dataset.age = patients.age_on(dataset.eia_code_date)

dataset.sex = patients.sex

dataset.ethnicity = clinical_events.where(
    clinical_events.ctv3_code.is_in(codelists.ethnicity_codes)
    ).where(
        clinical_events.date.is_on_or_before(end_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient(
    ).ctv3_code.to_category(codelists.ethnicity_codes)

imd_rank = addresses.for_patient_on(dataset.eia_code_date).imd_rounded
dataset.imd = case(
    when((imd_rank >=0) & (imd_rank < int(32844 * 1 / 5))).then("1"),
    when(imd_rank < int(32844 * 2 / 5)).then("2"),
    when(imd_rank < int(32844 * 3 / 5)).then("3"),
    when(imd_rank < int(32844 * 4 / 5)).then("4"),
    when(imd_rank < int(32844 * 5 / 5)).then("5"),
    default=".u"
)

# Practice registration
## Registrations where start date >12m before eia_code_date + end date not before eia_code_date
spanning_regs = practice_registrations.where(
        practice_registrations.start_date <= (dataset.eia_code_date - months(12))
    ).except_where(
        practice_registrations.end_date < dataset.eia_code_date
)
## If registered with multiple practices, sort by most recent then longest duration then practice ID
ordered_regs = spanning_regs.sort_by(
        practice_registrations.start_date,
        practice_registrations.end_date,
        practice_registrations.practice_pseudo_id,
    ).last_for_patient()

dataset.curr_reg_start = ordered_regs.start_date
dataset.curr_reg_end = ordered_regs.end_date
dataset.has_follow_up = ordered_regs.exists_for_patient()

## Practice region
dataset.region = ordered_regs.practice_nuts1_region_name
dataset.stp = ordered_regs.practice_stp

# Death
dataset.died_date=patients.date_of_death
dataset.died_date_ons = ons_deaths.date

# Date of comorbidities (first match before EIA code)
def first_comorbidity_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.ctv3_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.chronic_cardiac_disease=first_comorbidity_in_period(codelists.chronic_cardiac_disease_codes).date
dataset.diabetes=first_comorbidity_in_period(codelists.diabetes_codes).date
dataset.hypertension=first_comorbidity_in_period(codelists.hypertension_codes).date
dataset.chronic_respiratory_disease=first_comorbidity_in_period(codelists.chronic_respiratory_disease_codes).date
dataset.copd=first_comorbidity_in_period(codelists.copd_codes).date
dataset.chronic_liver_disease=first_comorbidity_in_period(codelists.chronic_liver_disease_codes).date
dataset.stroke=first_comorbidity_in_period(codelists.stroke_codes).date
dataset.lung_cancer=first_comorbidity_in_period(codelists.lung_cancer_codes).date
dataset.haem_cancer=first_comorbidity_in_period(codelists.haem_cancer_codes).date
dataset.other_cancer=first_comorbidity_in_period(codelists.other_cancer_codes).date
dataset.esrf=first_comorbidity_in_period(codelists.ckd_codes).date

# Relevant blood tests (last match before EIA code)
def last_test_in_period(dx_codelist):
    return clinical_events.where(
        clinical_events.ctv3_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= dataset.eia_code_date
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.hba1c_mmol_per_mol=last_test_in_period(codelists.hba1c_new_codes).numeric_value
dataset.hba1c_mmol_per_mol_date=last_test_in_period(codelists.hba1c_new_codes).date

dataset.hba1c_percentage=last_test_in_period(codelists.hba1c_old_codes).numeric_value
dataset.hba1c_percentage_date=last_test_in_period(codelists.hba1c_old_codes).date

dataset.creatinine=last_test_in_period(codelists.creatinine_codes).numeric_value
dataset.creatinine_date=last_test_in_period(codelists.creatinine_codes).date

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

dataset.bmi = bmi_record.numeric_value
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
    default="M"
)

# Rheumatology outpatient appointments

## Date of first rheum appointment in the 1 year before EIA code (with first attendance options selected)
rheum_appt = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410") &
        ((opa.first_attendance == "1") | (opa.first_attendance == "3"))
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_date = rheum_appt.appointment_date

## Medium of rheumatology outpatient e.g. telemedicine (with first attendance option selected)
### This returns an unusual string in dummy data - should be an integer
dataset.rheum_appt_medium = rheum_appt.consultation_medium_used

## Rheum appointment count in the 1 year before EIA code (without first attendance option selected)
dataset.rheum_appt_count = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).count_for_patient()

## Date of first rheum appointment in the 1 year before EIA code (without first attendance option selected)
dataset.rheum_appt_any_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(1))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Date of first rheum appointment in the 6 months before EIA code (without first attendance option selected)
dataset.rheum_appt2_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - months(6))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Date of first rheum appointment in the 2 years before EIA code (without first attendance option selected)
dataset.rheum_appt3_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(2))) &
        (opa.appointment_date <= dataset.eia_code_date + days(60)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

## Date of first rheum appointment in the 2 years before EIA code and up to 1 year after (without first attendance option selected)
dataset.rheum_appt4_date = opa.where(
        (opa.appointment_date >= (dataset.eia_code_date - years(2))) &
        (opa.appointment_date <= dataset.eia_code_date + years(1)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient().appointment_date

# Rheumatology referrals
## Last referral in the 2 years before rheumatology outpatient
dataset.referral_rheum_prerheum = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.rheum_appt_date - years(2))) & (clinical_events.date <= dataset.rheum_appt_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

## Last referral in the 2 years before EIA code
dataset.referral_rheum_precode = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.eia_code_date - years(2))) & (clinical_events.date <= dataset.eia_code_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date

# GP consultations
## This replicates status codes used in cohort_extractor for consultations that occurred
cohort_extractor_appointment_statuses = [
    #"Booked",
    "Arrived",
    #"Did Not Attend",
    "In Progress",
    "Finished",
    #"Requested",
    #"Blocked",
    "Visit",
    "Waiting",
    #"Cancelled by Patient",
    #"Cancelled by Unit",
    #"Cancelled by Other Service",
    #"No Access Visit",
    #"Cancelled Due To Death",
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

## Last GP consultation in the 2 years before EIA code
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
        (appointments.start_date >= (dataset.referral_rheum_prerheum - years(2))) &
        (appointments.start_date <= dataset.referral_rheum_prerheum)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

## Last GP consultation in the 2 years before rheum ref pre-code
dataset.last_gp_refcode_date = appointments.where(
        (appointments.status.is_in(cohort_extractor_appointment_statuses)) &
        (appointments.start_date >= (dataset.referral_rheum_precode - years(2))) &
        (appointments.start_date <= dataset.referral_rheum_precode)
    ).sort_by(
        appointments.start_date
    ).last_for_patient().start_date

# Follow-up registration (6m/12m after rheumatology appointment)
dataset.has_6m_follow_up = practice_registrations.where(
        ((ordered_regs.end_date.is_not_null()) & (ordered_regs.end_date >= (dataset.rheum_appt_date + months(6))) & ((dataset.rheum_appt_date + months(6)) <= end_date)) |
        ((ordered_regs.end_date.is_null()) & ((dataset.rheum_appt_date + months(6)) <= end_date))
    ).exists_for_patient()

dataset.has_12m_follow_up = practice_registrations.where(
        ((ordered_regs.end_date.is_not_null()) & (ordered_regs.end_date >= (dataset.rheum_appt_date + months(12))) & ((dataset.rheum_appt_date + months(12)) <= end_date)) |
        ((ordered_regs.end_date.is_null()) & ((dataset.rheum_appt_date + months(12)) <= end_date))
    ).exists_for_patient()

# Medications
## Date of first prescription before end date
def medication_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(end_date)
    ).sort_by(
            medications.date
    ).first_for_patient()

dataset.leflunomide_date = medication_dates_dmd(codelists.leflunomide_codes).date
dataset.methotrexate_date = medication_dates_dmd(codelists.methotrexate_codes).date
dataset.methotrexate_inj_date = medication_dates_dmd(codelists.methotrexate_inj_codes).date
dataset.sulfasalazine_date = medication_dates_dmd(codelists.sulfasalazine_codes).date
dataset.hydroxychloroquine_date = medication_dates_dmd(codelists.hydroxychloroquine_codes).date

## Count of prescriptions issued before end date - could merge with above if don't change date range
def get_medcounts_for_dates (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(end_date)
    ).sort_by(
            medications.date
    ).count_for_patient()

dataset.leflunomide_count = get_medcounts_for_dates(codelists.leflunomide_codes)
dataset.methotrexate_count = get_medcounts_for_dates(codelists.methotrexate_codes)
dataset.methotrexate_inj_count = get_medcounts_for_dates(codelists.methotrexate_inj_codes)
dataset.sulfasalazine_count = get_medcounts_for_dates(codelists.sulfasalazine_codes)
dataset.hydroxychloroquine_count = get_medcounts_for_dates(codelists.hydroxychloroquine_codes)

## Will also need a high_cost_drugs function (MM-YY)

# RTT dates -  all completed referral-to-treatment (RTT) pathways with a "clock stop" date between May 2021 and May 2022

## Search for first rheumatology RTT between 1 year before and 60 days after EIA code date
# rtt = wl_clockstops.where(
#         (wl_clockstops.referral_to_treatment_period_start_date >= (dataset.eia_code_date - years(1))) & 
#         (wl_clockstops.referral_to_treatment_period_start_date <= (dataset.eia_code_date + days(60))) &
#         (wl_clockstops.activity_treatment_function_code.is_in(["410"]))
#     ).sort_by(
#         wl_clockstops.referral_to_treatment_period_start_date,
#     ).first_for_patient()

## Also consider need for these limits if we only need start date - exclude rows with missing dates/dates outside study period/end date before start date
# clockstops = wl_clockstops.where(
#         wl_clockstops.referral_to_treatment_period_end_date.is_on_or_between("2021-05-01", "2022-05-01")
#         & wl_clockstops.referral_to_treatment_period_start_date.is_on_or_before(wl_clockstops.referral_to_treatment_period_end_date)
#         & wl_clockstops.week_ending_date.is_on_or_between("2021-05-01", "2022-05-01")
#         & wl_clockstops.waiting_list_type.is_in(["IRTT","ORTT","PTLO","PTLI","PLTI","RTTO","RTTI","PTL0","PTL1"])
#     )

# dataset.rtt_start_date = rtt.referral_to_treatment_period_start_date
# dataset.rtt_ref_rec_date = rtt.referral_request_received_date
# dataset.rtt_end_date = rtt.referral_to_treatment_period_end_date
# dataset.wait_time = (dataset.rtt_end_date - dataset.rtt_start_date).days

## And RTT open pathways - snapshot May 2022

# Define population
dataset.define_population(
    ((dataset.eia_code_date >= start_date) & (dataset.eia_code_date < end_date)) &
    ((dataset.age >= 18) & (dataset.age <= 110)) &
    (dataset.has_follow_up) &
    ((dataset.sex == "male") | (dataset.sex == "female"))
)
