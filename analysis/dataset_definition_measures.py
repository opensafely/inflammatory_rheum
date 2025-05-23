from ehrql import create_dataset, months, years, case, when, create_measures, INTERVAL
from ehrql.tables.tpp import patients, practice_registrations, clinical_events, apcs, addresses, ons_deaths, appointments
from datetime import date, datetime
import codelists_ehrQL as codelists
import sys

# Arguments (from project.yaml)
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--start-date", type=str)
parser.add_argument("--intervals", type=int)
args = parser.parse_args()

start_date = args.start_date
intervals = args.intervals

index_date = INTERVAL.start_date
end_date = INTERVAL.end_date

# Currently registered with a practice
curr_reg = practice_registrations.for_patient_on(index_date).exists_for_patient()

# Practice registration for at least 12 months before index date
pre_registrations = (
    practice_registrations.where(
        practice_registrations.start_date.is_on_or_before(index_date - months(12))
    ).except_where(
        practice_registrations.end_date.is_on_or_before(index_date)
    )
)
pre_reg = pre_registrations.exists_for_patient()

# Demographics
age = patients.age_on(index_date)

age_band = case(  
    when((age >= 0) & (age < 9)).then("age_0_9"),
    when((age >= 10) & (age < 19)).then("age_10_19"),
    when((age >= 20) & (age < 29)).then("age_20_29"),
    when((age >= 30) & (age < 39)).then("age_30_39"),
    when((age >= 40) & (age < 49)).then("age_40_49"),
    when((age >= 50) & (age < 59)).then("age_50_59"),
    when((age >= 60) & (age < 69)).then("age_60_69"),
    when((age >= 70) & (age < 79)).then("age_70_79"),
    when((age >= 80)).then("age_greater_equal_80"),
)

sex = patients.sex

latest_ethnicity_code = (
    clinical_events.where(clinical_events.snomedct_code.is_in(codelists.ethnicity_codes))
    .where(clinical_events.date.is_on_or_before(end_date))
    .sort_by(clinical_events.date)
    .last_for_patient().snomedct_code.to_category(codelists.ethnicity_codes)
)

ethnicity = case(
    when(latest_ethnicity_code == "1").then("White"),
    when(latest_ethnicity_code == "2").then("Mixed"),
    when(latest_ethnicity_code == "3").then("Asian or Asian British"),
    when(latest_ethnicity_code == "4").then("Black or Black British"),
    when(latest_ethnicity_code == "5").then("Chinese or Other Ethnic Groups"),
    otherwise="Unknown",
)

latest_address_per_patient = addresses.sort_by(addresses.start_date).last_for_patient()
imd_rounded = latest_address_per_patient.imd_rounded
imd_quintile = case(
    when((imd_rounded >= 0) & (imd_rounded < int(32844 * 1 / 5))).then("1 (most deprived)"),
    when(imd_rounded < int(32844 * 2 / 5)).then("2"),
    when(imd_rounded < int(32844 * 3 / 5)).then("3"),
    when(imd_rounded < int(32844 * 4 / 5)).then("4"),
    when(imd_rounded < int(32844 * 5 / 5)).then("5 (least deprived)"),
    otherwise="Unknown",
)

measures = create_measures()
measures.configure_dummy_data(population_size=1000)
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(intervals=years(intervals).starting_on(start_date))

# Denominator (currently registrered at index date)
denominator = (
    ((age >= 18) & (age <= 110)) &
    sex.is_in(["male", "female"])
    & curr_reg
)

# Numerator (at least 12 months practice registration at index date)
numerator = (
    ((age >= 18) & (age <= 110)) &
    sex.is_in(["male", "female"])
    & pre_reg
)

# Currently registered patient population vs. those with at least 12 months preceding practice registration
measures.define_measure(
    name="Registered_patients_all",
    numerator=numerator,
    denominator=denominator,
    intervals=years(intervals).starting_on(start_date),
)

# Broken down by age band and sex
measures.define_measure(
    name="Registered_patients_age_sex",
    numerator=numerator,
    denominator=denominator,
    intervals=years(intervals).starting_on(start_date),
    group_by={
        "sex": sex,
        "age": age_band,  
    },
)

# # Incidence by ethnicity
# measures.define_measure(
#     name=disease + "_inc_ethn",
#     numerator=incidence_numerators[disease + "_inc_num"],
#     denominator=incidence_denominators[disease + "_inc_denom"],
#     group_by={
#         "ethnicity": dataset.ethnicity,
#     },
# )

# # Incidence by IMD quintile
# measures.define_measure(
#     name=disease + "_inc_imd",
#     numerator=incidence_numerators[disease + "_inc_num"],
#     denominator=incidence_denominators[disease + "_inc_denom"],
#     group_by={
#         "imd": dataset.imd_quintile,
#     },
# )