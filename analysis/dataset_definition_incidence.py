from ehrql import create_dataset, days, months, years, case, when, minimum_of, maximum_of
from ehrql.tables.tpp import patients, practice_registrations, clinical_events, apcs, addresses
from ehrql.codes import ICD10Code
from datetime import date, datetime
import codelists_ehrQL as codelists

# # Arguments (from project.yaml)
# from argparse import ArgumentParser

# parser = ArgumentParser()
# parser.add_argument("--diseases", type=str)
# args = parser.parse_args()
# diseases = args.diseases.split(", ")

diseases = ["rheumatoid", "psa", "axialspa", "undiffia", "gca", "sjogren", "ssc", "sle", "myositis", "anca"]
codelist_types = ["snomed", "icd"]

dataset = create_dataset()
dataset.configure_dummy_data(population_size=1000)

index_date = "2016-04-01"
end_date = "2025-03-31"

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

# Registration for 12 months prior to incident diagnosis date
def preceding_registration(dx_date):
    return practice_registrations.where(
        practice_registrations.start_date.is_on_or_before(dx_date - months(12))
    ).except_where(
        practice_registrations.end_date.is_on_or_before(dx_date)
    )

# Define sex
dataset.sex = patients.sex

# Date of death
dataset.date_of_death = patients.date_of_death

# Any practice registration before study end date
any_registration = practice_registrations.where(
            practice_registrations.start_date <= end_date
        ).except_where(
            practice_registrations.end_date < index_date    
        ).exists_for_patient()

# Define patient ethnicity
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

# Define patient IMD
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

# Define population as any patient registered after index date - then apply further restrictions later (age, death and preceding registration)
dataset.define_population(
    any_registration 
    & dataset.sex.is_in(["male", "female"])
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

    # Incident date within window - combined primary and secondary care 
    dataset.add_column(f"{disease}_inc_case",
        (getattr(dataset, disease + "_inc_date").is_on_or_between(index_date, end_date)
        ).when_null_then(False)
    )

    # 12 months registration preceding incident diagnosis date - combined primary and secondary care
    dataset.add_column(f"{disease}_pre_reg", 
        preceding_registration(getattr(dataset, f"{disease}_inc_date")
        ).exists_for_patient()
    )

    # Age at diagnosis - combined primary and secondary care
    dataset.add_column(f"{disease}_age",
        (patients.age_on(getattr(dataset, f"{disease}_inc_date"))
        )               
    )

    # Alive at incident diagnosis date - combined primary and secondary care
    dataset.add_column(f"{disease}_alive_inc",
        (
            (dataset.date_of_death.is_after(getattr(dataset, f"{disease}_inc_date"))) |
            dataset.date_of_death.is_null()
        ).when_null_then(False)
    )

    # Incident date within window - primary care only
    dataset.add_column(f"{disease}_inc_case_p",
        (getattr(dataset, disease + "_prim_date").is_on_or_between(index_date, end_date)
        ).when_null_then(False)
    )

    # 12 months registration preceding incident diagnosis date - primary care only
    dataset.add_column(f"{disease}_pre_reg_p", 
        preceding_registration(getattr(dataset, f"{disease}_prim_date")
        ).exists_for_patient()
    )

    # Age at diagnosis - primary care only
    dataset.add_column(f"{disease}_age_p",
        (patients.age_on(getattr(dataset, f"{disease}_prim_date"))
        )               
    )

    # Alive at incident diagnosis date - primary care only
    dataset.add_column(f"{disease}_alive_inc_p",
        (
            (dataset.date_of_death.is_after(getattr(dataset, f"{disease}_prim_date"))) |
            dataset.date_of_death.is_null()
        ).when_null_then(False)
    )

    # Incident date within window - secondary care only
    dataset.add_column(f"{disease}_inc_case_s",
        (getattr(dataset, disease + "_sec_date").is_on_or_between(index_date, end_date)
        ).when_null_then(False)
    )

    # 12 months registration preceding incident diagnosis date - secondary care only
    dataset.add_column(f"{disease}_pre_reg_s", 
        preceding_registration(getattr(dataset, f"{disease}_sec_date")
        ).exists_for_patient()
    )

    # Age at diagnosis - secondary care only
    dataset.add_column(f"{disease}_age_s",
        (patients.age_on(getattr(dataset, f"{disease}_sec_date"))
        )               
    )

    # Alive at incident diagnosis date - secondary care only
    dataset.add_column(f"{disease}_alive_inc_s",
        (
            (dataset.date_of_death.is_after(getattr(dataset, f"{disease}_sec_date"))) |
            dataset.date_of_death.is_null()
        ).when_null_then(False)
    )