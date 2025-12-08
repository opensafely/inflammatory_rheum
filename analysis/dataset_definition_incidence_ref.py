from ehrql import create_dataset, days, months, years, case, when, minimum_of, maximum_of
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, apcs, addresses, ethnicity_from_sus 
from ehrql.codes import ICD10Code
from datetime import date, datetime
from functools import reduce
import codelists_ehrQL as codelists

index_date = date(2016, 4, 1)
end_date = date(2025, 3, 31)

dataset = create_dataset()
dataset.configure_dummy_data(population_size=1000)

# Any practice registration before study end date
registration_in_window = (
    practice_registrations.where(practice_registrations.start_date <= end_date)
    .except_where(practice_registrations.end_date < index_date)
)

observed_registration_end = case(
    when(practice_registrations.end_date.is_null()).then(end_date),
    otherwise=minimum_of(practice_registrations.end_date, end_date),
)

# Keep only overlapping episodes that (observably) last at least 12 months
registration_in_window_12m = registration_in_window.except_where(
    observed_registration_end < (practice_registrations.start_date + months(12))
)

dataset.any_registration_12m = registration_in_window_12m.exists_for_patient()

dataset.first_registration_12m = (
    registration_in_window_12m.sort_by(practice_registrations.start_date)
    .first_for_patient()
    .start_date
)

# If you want cohort entry anchored to study start:
dataset.cohort_entry_date = maximum_of(index_date, dataset.first_registration_12m)

# Define sex
dataset.sex = patients.sex

# Date of death
dataset.date_of_death = patients.date_of_death

dataset.alive_at_entry = (
    patients.date_of_death.is_null() | patients.date_of_death.is_after(dataset.cohort_entry_date)
)

# Age at index date
dataset.age = patients.age_on(dataset.cohort_entry_date)

dataset.age_band = case(  
    when((dataset.age >= 18) & (dataset.age <= 29)).then("age_18_29"),
    when((dataset.age >= 30) & (dataset.age <= 39)).then("age_30_39"),
    when((dataset.age >= 40) & (dataset.age <= 49)).then("age_40_49"),
    when((dataset.age >= 50) & (dataset.age <= 59)).then("age_50_59"),
    when((dataset.age >= 60) & (dataset.age <= 69)).then("age_60_69"),
    when((dataset.age >= 70) & (dataset.age <= 79)).then("age_70_79"),
    when((dataset.age >= 80)).then("age_greater_equal_80"),
)

# Define patient ethnicity (latest code)
latest_ethnicity_code = (
    clinical_events.where(clinical_events.snomedct_code.is_in(codelists.ethnicity_codes))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient().snomedct_code.to_category(codelists.ethnicity_codes)
)

# Extract ethnicity from SUS records if it isn't present in primary care data 
ethnicity_sus = ethnicity_from_sus.code

dataset.ethnicity = case(
    when((latest_ethnicity_code == "1") | ((latest_ethnicity_code.is_null()) & (ethnicity_sus.is_in(["A", "B", "C"])))).then("White"),
    when((latest_ethnicity_code == "2") | ((latest_ethnicity_code.is_null()) & (ethnicity_sus.is_in(["D", "E", "F", "G"])))).then("Mixed"),
    when((latest_ethnicity_code == "3") | ((latest_ethnicity_code.is_null()) & (ethnicity_sus.is_in(["H", "J", "K", "L"])))).then("Asian or Asian British"),
    when((latest_ethnicity_code == "4") | ((latest_ethnicity_code.is_null()) & (ethnicity_sus.is_in(["M", "N", "P"])))).then("Black or Black British"),
    when((latest_ethnicity_code == "5") | ((latest_ethnicity_code.is_null()) & (ethnicity_sus.is_in(["R", "S"])))).then("Chinese or Other Ethnic Groups"),
    otherwise="Unknown", 
) 

# Define patient IMD at cohort entry
imd = addresses.for_patient_on(dataset.cohort_entry_date).imd_rounded

dataset.imd_quintile = case(
    when((imd >= 0) & (imd < int(32844 * 1 / 5))).then("1 (most deprived)"),
    when(imd < int(32844 * 2 / 5)).then("2"),
    when(imd < int(32844 * 3 / 5)).then("3"),
    when(imd < int(32844 * 4 / 5)).then("4"),
    when(imd < int(32844 * 5 / 5)).then("5 (least deprived)"),
    otherwise="Unknown",
)

# Define population
dataset.define_population(
    dataset.age_band.is_not_null()
    & dataset.sex.is_in(["male", "female"])
    & dataset.alive_at_entry
    & dataset.any_registration_12m
    & dataset.cohort_entry_date.is_not_null()
)  