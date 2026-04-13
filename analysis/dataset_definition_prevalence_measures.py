from ehrql import create_dataset, days, months, years, case, when, create_measures, INTERVAL, minimum_of, maximum_of
from ehrql.tables.tpp import patients, medications, practice_registrations, clinical_events, apcs, addresses, ons_deaths, appointments
from datetime import date, datetime
import codelists_ehrQL as codelists
from analysis.dataset_definition_prevalence import dataset
import sys

# Arguments (from project.yaml)
from argparse import ArgumentParser

parser = ArgumentParser()
parser.add_argument("--start-date", type=str)
parser.add_argument("--intervals", type=int)
parser.add_argument("--disease", type=str)
args = parser.parse_args()

start_date = args.start_date
intervals_years = args.intervals
disease = args.disease

index_date = INTERVAL.start_date

# Currently registered
curr_registered = practice_registrations.for_patient_on(index_date).exists_for_patient()

# Age at interval start
age = patients.age_on(index_date)

age_band = case(  
    when((age >= 18) & (age <= 29)).then("age_18_29"),
    when((age >= 30) & (age <= 39)).then("age_30_39"),
    when((age >= 40) & (age <= 49)).then("age_40_49"),
    when((age >= 50) & (age <= 59)).then("age_50_59"),
    when((age >= 60) & (age <= 69)).then("age_60_69"),
    when((age >= 70) & (age <= 79)).then("age_70_79"),
    when((age >= 80)).then("age_80"),
)

measures = create_measures()
measures.configure_dummy_data(population_size=1000, legacy=True)
measures.configure_disclosure_control(enabled=False)
measures.define_defaults(intervals=years(intervals_years).starting_on(start_date))

# Population denominator (currently registered)
prev_denominator = (
    ((age >= 18) & (age <= 110))
    & dataset.sex.is_in(["male", "female"])
    & (dataset.date_of_death.is_after(index_date) | dataset.date_of_death.is_null())
    & curr_registered
)

# Dictionaries to store values
prev = {}
prev_numerators = {} 

# Prevalent diagnosis (at interval start)
prev[disease + "_prev"] = (
    (getattr(dataset, disease + "_inc_date") < index_date)
).when_null_then(False)

# Prevalence numerator - people registered on index date who have an diagnostic code on or before index date
prev_numerators[disease + "_prev_num"] = (
    prev[disease + "_prev"] & prev_denominator
)

# Prevalence by age and sex
measures.define_measure(
    name=disease + "_prevalence",
    numerator=prev_numerators[disease + "_prev_num"],
    denominator=prev_denominator,
    intervals=years(intervals_years).starting_on(start_date),
    group_by={
        "sex": dataset.sex,
        "age": age_band,  
    },
)