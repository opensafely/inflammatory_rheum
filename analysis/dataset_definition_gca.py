from ehrql import create_dataset, days, months, years, case, when, get_parameter
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, addresses, appointments, opa, wl_clockstops, wl_openpathways
from datetime import date
import codelists_ehrQL as codelists
from analysis.dataset_definition_incidence import create_dataset_with_variables, get_population

dataset = create_dataset_with_variables()

# Read parameters from project.yaml
studystart_date = get_parameter("studystart_date")
studyend_date = get_parameter("studyend_date")
studyfup_date = get_parameter("studyfup_date")
diseases_list = get_parameter("diseases_list")
registration_months = int(get_parameter("registration_months"))

# Define primary diagnosis date
diag_date = getattr(dataset, "gca_inc_date")

# Baseline comorbidities (first match before rheum diagnostic code)
def first_comorbidity_before_diagnosis(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date <= diag_date
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.ocular_before_date=first_comorbidity_before_diagnosis(codelists.ocular_codes).date
dataset.aortic_before_date=first_comorbidity_before_diagnosis(codelists.aortic_codes).date
dataset.chd_before_date=first_comorbidity_before_diagnosis(codelists.chd_codes).date
dataset.cva_before_date=first_comorbidity_before_diagnosis(codelists.cva_codes).date
dataset.osteop_before_date=first_comorbidity_before_diagnosis(codelists.osteoporosis_codes).date
dataset.frac_before_date=first_comorbidity_before_diagnosis(codelists.fracture_codes).date
dataset.pmr_before_date=first_comorbidity_before_diagnosis(codelists.pmr_codes).date

dataset.dm_before_date=first_comorbidity_before_diagnosis(codelists.diabetes_codes).date
dataset.ild_before_date=first_comorbidity_before_diagnosis(codelists.ild_codes).date
dataset.copd_before_date=first_comorbidity_before_diagnosis(codelists.copd_codes).date
dataset.lung_ca_before_date=first_comorbidity_before_diagnosis(codelists.lung_cancer_codes).date
dataset.solid_ca_before_date=first_comorbidity_before_diagnosis(codelists.solid_cancer_codes).date
dataset.haem_ca_before_date=first_comorbidity_before_diagnosis(codelists.haem_cancer_codes).date
dataset.ckd_before_date=first_comorbidity_before_diagnosis(codelists.ckd_codes).date
dataset.depr_before_date=first_comorbidity_before_diagnosis(codelists.depression_codes).date
dataset.htn_before_date=first_comorbidity_before_diagnosis(codelists.htn_codes).date
dataset.ccf_before_date=first_comorbidity_before_diagnosis(codelists.ccf_codes).date

# New comorbidities (first match after rheum diagnostic code and before study end date)
def first_comorbidity_after_diagnosis(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        (clinical_events.date > diag_date) & (clinical_events.date.is_on_or_before(studyfup_date))
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

dataset.ocular_after_date=first_comorbidity_after_diagnosis(codelists.ocular_codes).date
dataset.aortic_after_date=first_comorbidity_after_diagnosis(codelists.aortic_codes).date
dataset.chd_after_date=first_comorbidity_after_diagnosis(codelists.chd_codes).date
dataset.cva_after_date=first_comorbidity_after_diagnosis(codelists.cva_codes).date
dataset.osteop_after_date=first_comorbidity_after_diagnosis(codelists.osteoporosis_codes).date
dataset.frac_after_date=first_comorbidity_after_diagnosis(codelists.fracture_codes).date
dataset.pmr_after_date=first_comorbidity_after_diagnosis(codelists.pmr_codes).date

dataset.dm_after_date=first_comorbidity_after_diagnosis(codelists.diabetes_codes).date
dataset.ild_after_date=first_comorbidity_after_diagnosis(codelists.ild_codes).date
dataset.copd_after_date=first_comorbidity_after_diagnosis(codelists.copd_codes).date
dataset.lung_ca_after_date=first_comorbidity_after_diagnosis(codelists.lung_cancer_codes).date
dataset.solid_ca_after_date=first_comorbidity_after_diagnosis(codelists.solid_cancer_codes).date
dataset.haem_ca_after_date=first_comorbidity_after_diagnosis(codelists.haem_cancer_codes).date
dataset.ckd_after_date=first_comorbidity_after_diagnosis(codelists.ckd_codes).date
dataset.depr_after_date=first_comorbidity_after_diagnosis(codelists.depression_codes).date
dataset.dem_after_date=first_comorbidity_after_diagnosis(codelists.dementia_codes).date
dataset.htn_after_date=first_comorbidity_after_diagnosis(codelists.htn_codes).date
dataset.ccf_after_date=first_comorbidity_after_diagnosis(codelists.ccf_codes).date

# Relevant blood tests at baseline (last match before rheum diagnostic code as long as within 2 years before diagnosis)
def last_test_before_diagnosis(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        (clinical_events.date >= (diag_date - years(2))) & (clinical_events.date <= diag_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.creatinine_bl_value=last_test_before_diagnosis(codelists.creatinine_codes).numeric_value
dataset.creatinine_bl_date=last_test_before_diagnosis(codelists.creatinine_codes).date
dataset.hba1c_bl_value=last_test_before_diagnosis(codelists.hba1c_codes).numeric_value
dataset.hba1c_bl_date=last_test_before_diagnosis(codelists.hba1c_codes).date

# Last blood tests after diagnosis and before end of study period
def last_test_after_diagnosis(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        (clinical_events.date > (diag_date)) & (clinical_events.date.is_on_or_before(studyfup_date))
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.creatinine_last_value=last_test_after_diagnosis(codelists.creatinine_codes).numeric_value
dataset.creatinine_last_date=last_test_after_diagnosis(codelists.creatinine_codes).date
dataset.hba1c_last_value=last_test_after_diagnosis(codelists.hba1c_codes).numeric_value
dataset.hba1c_last_date=last_test_after_diagnosis(codelists.hba1c_codes).date

# BMI within 10 years prior to diagnosis date
bmi_record = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.bmi_codes)
    ).where(
        clinical_events.date >= (patients.date_of_birth + years(16))
    ).where(
        (clinical_events.date >= (diag_date - years(10))) & (clinical_events.date <= diag_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient()

dataset.bmi_value = bmi_record.numeric_value
dataset.bmi_date = bmi_record.date

# Smoking status at or before diagnosis
dataset.most_recent_smoking_code=clinical_events.where(
        clinical_events.ctv3_code.is_in(codelists.clear_smoking_codes)
    ).where(
        clinical_events.date <= diag_date
    ).sort_by(
        clinical_events.date
    ).last_for_patient().ctv3_code.to_category(codelists.clear_smoking_codes)

def filter_codes_by_category(codelist, include):
    return {k:v for k,v in codelist.items() if v in include}

dataset.ever_smoked=clinical_events.where(
        clinical_events.ctv3_code.is_in(filter_codes_by_category(codelists.clear_smoking_codes, include=["S", "E"]))
    ).where(
        clinical_events.date <= diag_date
    ).exists_for_patient()

dataset.smoking_status=case(
    when(dataset.most_recent_smoking_code == "S").then("S"),
    when((dataset.most_recent_smoking_code == "E") | ((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == True))).then("E"),
    when((dataset.most_recent_smoking_code == "N") & (dataset.ever_smoked == False)).then("N"),
    otherwise="M"
)

## First rheum outpatient appointment in the 1 year before or after rheum diagnostic code (with first attendance options selected)
rheum_appt = opa.where(
        (opa.appointment_date >= (diag_date - years(1))) &
        (opa.appointment_date <= (diag_date + years(1))) &
        (opa.appointment_date.is_on_or_before(studyfup_date)) &
        (opa.treatment_function_code == "410") &
        ((opa.first_attendance == "1") | (opa.first_attendance == "3"))
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_date = rheum_appt.appointment_date
dataset.rheum_appt_medium = rheum_appt.consultation_medium_used

## First rheum appointment in the 1 year before or after rheum diagnostic code (without first attendance option selected)
rheum_appt_any = opa.where(
        (opa.appointment_date >= (diag_date - years(1))) &
        (opa.appointment_date <= (diag_date + years(1))) &
        (opa.appointment_date.is_on_or_before(studyfup_date)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).first_for_patient()

dataset.rheum_appt_any_date = rheum_appt_any.appointment_date

## Rheum appointment count in the 1 year after first rheum appt (without first attendance option selected)
dataset.rheum_appt_count = opa.where(
        (opa.appointment_date >= dataset.rheum_appt_date) &
        (opa.appointment_date <= (dataset.rheum_appt_date + years(1))) &
        (opa.appointment_date.is_on_or_before(studyfup_date)) &
        (opa.treatment_function_code == "410")
    ).sort_by(
        opa.appointment_date
    ).count_for_patient()

## Rheumatology referral date using HES OP data
dataset.rheum_appt_ref_date = rheum_appt.referral_request_received_date
dataset.rheum_any_ref_date = rheum_appt_any.referral_request_received_date

## Last referral in the 12 months before rheumatology outpatient appt (using primary care referrals)
dataset.ref_12m_preappt_date = clinical_events.where(
        clinical_events.snomedct_code.is_in(codelists.referral_rheumatology)
    ).where(
        (clinical_events.date >= (dataset.rheum_appt_date - years(1))) & (clinical_events.date <= dataset.rheum_appt_date)
    ).sort_by(
        clinical_events.date
    ).last_for_patient().date


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

dataset.reg_end_date = preceding_registration(diag_date).end_date

# Practice region
dataset.region = preceding_registration(diag_date).practice_nuts1_region_name

# IMD at time of primary diagnosis
address_per_patient_diag = addresses.for_patient_on(diag_date)
imd_rounded_diag = address_per_patient_diag.imd_rounded
dataset.imd_quintile_diag = case(
    when((imd_rounded_diag >= 0) & (imd_rounded_diag < int(32844 * 1 / 5))).then("1 (most deprived)"),
    when(imd_rounded_diag < int(32844 * 2 / 5)).then("2"),
    when(imd_rounded_diag < int(32844 * 3 / 5)).then("3"),
    when(imd_rounded_diag < int(32844 * 4 / 5)).then("4"),
    when(imd_rounded_diag < int(32844 * 5 / 5)).then("5 (least deprived)"),
    otherwise="Unknown",
)

# Medications
## Dates and counts of prednisolone and csDMARD prescriptions from 90 days before diagnosis date and before end date
def medication_dates_dmd (dx_codelist):
    return medications.where(
            medications.dmd_code.is_in(dx_codelist)
    ).where(
            medications.date.is_on_or_before(studyfup_date)
    ).except_where( 
            medications.date < (diag_date - days(90))
    ).sort_by(
            medications.date
    )

### First prescriptions
dataset.prednisolone_first_date = medication_dates_dmd(codelists.steroid_codes).first_for_patient().date
dataset.leflunomide_date = medication_dates_dmd(codelists.leflunomide_codes).first_for_patient().date
dataset.methotrexate_oral_date = medication_dates_dmd(codelists.methotrexate_codes).first_for_patient().date
dataset.methotrexate_inj_date = medication_dates_dmd(codelists.methotrexate_inj_codes).first_for_patient().date

### Last prescriptions before end date
dataset.prednisolone_last_date = medication_dates_dmd(codelists.steroid_codes).last_for_patient().date
dataset.lef_last_date = medication_dates_dmd(codelists.leflunomide_codes).last_for_patient().date
dataset.mtx_oral_last_date = medication_dates_dmd(codelists.methotrexate_codes).last_for_patient().date
dataset.mtx_inj_last_date = medication_dates_dmd(codelists.methotrexate_inj_codes).last_for_patient().date

### Count of prescriptions before end date
dataset.prednisolone_count = medication_dates_dmd(codelists.steroid_codes).count_for_patient()
dataset.leflunomide_count = medication_dates_dmd(codelists.leflunomide_codes).count_for_patient()
dataset.methotrexate_oral_count = medication_dates_dmd(codelists.methotrexate_codes).count_for_patient()
dataset.methotrexate_inj_count = medication_dates_dmd(codelists.methotrexate_inj_codes).count_for_patient()

# Define study population
incidence_dataset_population = get_population(dataset)

dataset.define_population(
    incidence_dataset_population &
    (getattr(dataset, "gca_inc_case")) &
    ((getattr(dataset, "gca_age") >= 18) & (getattr(dataset, "gca_age") <= 110)) &
    (getattr(dataset, "gca_pre_reg")) &
    (getattr(dataset, "gca_alive_inc"))
)