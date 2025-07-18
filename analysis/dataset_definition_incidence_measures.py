from ehrql import create_dataset, days, months, years, case, when, create_measures, INTERVAL, minimum_of, maximum_of
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, apcs, addresses, ons_deaths, appointments
from datetime import date, datetime
import codelists_ehrQL as codelists
from analysis.dataset_definition_incidence import dataset
import sys

# Arguments (from project.yaml)
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--start-date", type=str)
parser.add_argument("--intervals", type=int)
args = parser.parse_args()

start_date = args.start_date
intervals = args.intervals
intervals_years = int(intervals/12)

index_date = INTERVAL.start_date
end_date = INTERVAL.end_date

# Currently registered
curr_registered = practice_registrations.for_patient_on(index_date).exists_for_patient()

# Registration for at least 12 months before index date
pre_registrations = (
    practice_registrations.where(
        practice_registrations.start_date.is_on_or_before(index_date - months(12))
    ).except_where(
        practice_registrations.end_date.is_on_or_before(index_date)
    )
)
preceding_reg_index = pre_registrations.exists_for_patient()

# Age at interval start
age = patients.age_on(index_date)

age_band = case(  
    when((age >= 18) & (age < 30)).then("age_18_29"),
    when((age >= 30) & (age < 39)).then("age_30_39"),
    when((age >= 40) & (age < 49)).then("age_40_49"),
    when((age >= 50) & (age < 59)).then("age_50_59"),
    when((age >= 60) & (age < 69)).then("age_60_69"),
    when((age >= 70) & (age < 79)).then("age_70_79"),
    when((age >= 80)).then("age_greater_equal_80"),
)

measures = create_measures()
measures.configure_dummy_data(population_size=1000, legacy=True)
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(intervals=months(intervals).starting_on(start_date))

# Population denominator (currently registered)
current_denominator = (
    ((age >= 18) & (age <= 110))
    & dataset.sex.is_in(["male", "female"])
    & (dataset.date_of_death.is_after(index_date) | dataset.date_of_death.is_null())
    & curr_registered
)

# Population denominator (with 12m+ preceding registration)
preceding_denominator = (
    ((age >= 18) & (age <= 110))
    & dataset.sex.is_in(["male", "female"])
    & (dataset.date_of_death.is_after(index_date) | dataset.date_of_death.is_null())
    & preceding_reg_index
)

# Population
measures.define_measure(
    name="population_overall",
    numerator=preceding_denominator,
    denominator=current_denominator,
)

# Population by age and sex
measures.define_measure(
    name="population_bands",
    numerator=preceding_denominator,
    denominator=current_denominator,
    group_by={
        "sex": dataset.sex,
        "age": age_band,  
    },
)