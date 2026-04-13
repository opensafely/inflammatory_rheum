from ehrql import create_dataset, days, months, years, case, when, minimum_of, maximum_of
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, apcs, addresses, ethnicity_from_sus 
from ehrql.codes import ICD10Code
from datetime import date, datetime
from functools import reduce
import codelists_ehrQL as codelists

diseases = ["eia", "rheumatoid", "psa", "axialspa", "undiffia", "gca", "sjogren", "ssc", "sle", "myositis", "anca", "ctd", "vasc"]
codelist_types = ["snomed", "icd"]

index_date = "2016-04-01"
end_date = "2025-03-31"
fup_date = "2025-09-30"

# Any practice registration before study end date
any_registration = practice_registrations.where(
            practice_registrations.start_date <= end_date
        ).except_where(
            practice_registrations.end_date < index_date    
        ).exists_for_patient()

def create_dataset_with_variables():
    dataset = create_dataset()
    dataset.configure_dummy_data(population_size=10000)

    # Incident diagnostic code in primary care record (SNOMED) (assuming before study end date)
    def first_code_in_period_snomed(dx_codelist):
        return clinical_events.where(
            clinical_events.snomedct_code.is_in(dx_codelist)
        ).where(
            clinical_events.date.is_on_or_before(end_date)
        ).sort_by(
            clinical_events.date
        ).first_for_patient()

    # Incident diagnostic code in secondary care record (ICD10 primary diagnoses) (assuming before study end date)
    def first_code_in_period_icd(dx_codelist):
        return apcs.where(
            apcs.primary_diagnosis.is_in(dx_codelist)
        ).where(
            apcs.admission_date.is_on_or_before(end_date)
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

        # Incident date before study end
        dataset.add_column(f"{disease}_prev_case",
            (getattr(dataset, disease + "_inc_date").is_before(end_date)
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
    return dataset

def get_population(dataset):
    # Create variable for anyone with at least one diagnostic code
    any_prev_case = reduce(lambda x, y: x | y, [
        getattr(dataset, f"{d}_prev_case") for d in diseases
    ])

    # Define population as any patient with at least one diagnostic code before study end, registered after index date - then apply further restrictions later (age, death and preceding registration)
    return (any_prev_case
        & any_registration 
        & dataset.sex.is_in(["male", "female"]))

dataset = create_dataset_with_variables()
dataset.define_population(get_population(dataset))