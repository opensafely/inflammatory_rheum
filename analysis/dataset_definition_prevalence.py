from ehrql import create_dataset, days, months, years, case, when, minimum_of, maximum_of, get_parameter
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, apcs, addresses, ethnicity_from_sus 
from ehrql.codes import ICD10Code
from datetime import date, datetime
from functools import reduce
import codelists_ehrQL as codelists

# Read parameters from project.yaml
studystart_date = get_parameter("studystart_date")
studyend_date = get_parameter("studyend_date")
studyfup_date = get_parameter("studyfup_date")
diseases_list = get_parameter("diseases_list")

diseases = diseases_list if isinstance(diseases_list, list) else [diseases_list]
print("Diseases:", diseases)

# Define codelist types
codelist_types = ["snomed", "icd"]

dataset = create_dataset()
dataset.configure_dummy_data(population_size=1000)

# Any practice registration before study end date
any_registration = practice_registrations.where(
            practice_registrations.start_date <= studyend_date
        ).except_where(
            practice_registrations.end_date < studystart_date    
        ).exists_for_patient()

# Incident diagnostic code in primary care record (SNOMED) (assuming before study end date)
def first_code_in_period_snomed(dx_codelist):
    return clinical_events.where(
        clinical_events.snomedct_code.is_in(dx_codelist)
    ).where(
        clinical_events.date.is_on_or_before(studyend_date)
    ).sort_by(
        clinical_events.date
    ).first_for_patient()

# Incident diagnostic code in secondary care record (ICD10 primary diagnoses) (assuming before study end date)
def first_code_in_period_icd(dx_codelist):
    return apcs.where(
        apcs.primary_diagnosis.is_in(dx_codelist)
    ).where(
        apcs.admission_date.is_on_or_before(studyend_date)
    ).sort_by(
        apcs.admission_date
    ).first_for_patient()
    
# Expand 3-character ICD10 codes
def expand_three_char_icd10_codes(dx_codelist):
    return dx_codelist + [f"{code}X" for code in dx_codelist if len(code) == 3]

# Define sex
dataset.sex = patients.sex

# Date of death
dataset.date_of_death = patients.date_of_death

# Define population as any registered patient after index date, then apply further restrictions in later processing steps
dataset.define_population(
    any_registration & dataset.sex.is_in(["male", "female"])
) 

for disease in diseases:

    for codelist_type in codelist_types:

        if (f"{codelist_type}" == "snomed"):
            if hasattr(codelists, f"{disease}_snomed"):
                disease_codelist = getattr(codelists, f"{disease}_snomed")
                dataset.add_column(f"{disease}_prim_date", first_code_in_period_snomed(disease_codelist).date)

            else:
                dataset.add_column(f"{disease}_prim_date", first_code_in_period_snomed([]).date)
        elif (f"{codelist_type}" == "icd"):
            if hasattr(codelists, f"{disease}_icd"):
                disease_codelist = getattr(codelists, f"{disease}_icd")
                disease_codelist = expand_three_char_icd10_codes(disease_codelist)   
                dataset.add_column(f"{disease}_sec_date", first_code_in_period_icd(disease_codelist).admission_date)
            else:
                dataset.add_column(f"{disease}_sec_date", first_code_in_period_icd([]).admission_date)
        else:
            dataset.add_column(f"{disease}_{codelist_type}_inc_date", None)

    # Incident date for each disease - combined primary and secondary care 
    dataset.add_column(f"{disease}_inc_date",
        minimum_of(*[date for date in [
            (getattr(dataset, f"{disease}_prim_date", None)),
            (getattr(dataset, f"{disease}_sec_date", None))
            ] if date is not None]),
    )

    # Incident date before study end (prevalent cases)
    dataset.add_column(f"{disease}_prev_case",
        (getattr(dataset, disease + "_inc_date").is_before(studyend_date)
        ).when_null_then(False)
    )

    # Age at diagnosis
    dataset.add_column(f"{disease}_age",
        (patients.age_on(getattr(dataset, f"{disease}_inc_date"))
        )               
    )

    # Alive at diagnosis date
    dataset.add_column(f"{disease}_alive_inc",
        ((dataset.date_of_death.is_after(getattr(dataset, f"{disease}_inc_date"))) | dataset.date_of_death.is_null()
        ).when_null_then(False)
    )