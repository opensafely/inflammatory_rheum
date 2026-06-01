from datetime import datetime, date

# Define disease list
diseases = "eia rheumatoid psa axialspa undiffia gca sjogren ssc sle myositis anca"

# Define study dates
studystart_date = "2016-04-01"
studyend_date = "2025-03-31"
studyfup_date = "2026-03-31"

# Including incidence graphs +/- sensitivity analyses with 24 months preceding registration (yes or no)
incidence_graphs = "no"
incidence_sensitivity = "no"

# Include prevalence analyses (yes or no)
prevalence = "no"

# Define intervention date(s) of interest for intervention analyses
intervention_date_covid = "2020-03-01"

# Include early inflammatory arthritis analyses (yes or no)
eia = "no"

# Include giant cell arteritis analyses (yes or no)
gca = "yes"

# Store start years, number of monthly intervals, and merge disease lists
start_dt = datetime.strptime(studystart_date, "%Y-%m-%d").date()
end_dt = datetime.strptime(studyend_date, "%Y-%m-%d").date()
start_year = start_dt.year
end_year = end_dt.year

# Disease lists for Python and R scripts
diseases_str = diseases.split()
diseases_list = " ".join(diseases_str)

# Disease lists for Stata scripts (pipe-separated)
diseases_list_stata = "|".join(diseases_str)

# Monthly intervals calculated for each study year
def calculate_intervals(year, end_dt):
  win_end = date(year + 1, 3, 31)

  if win_end <= end_dt:
      return 12

  return (end_dt.year - year) * 12 + (end_dt.month - 4) + 1

yaml_header = f"""
version: '4.0'

actions:    
  generate_dataset_incidence:
    run: ehrql:v1 generate-dataset analysis/dataset_definition_incidence.py
      --output output/dataset_incidence.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
      --registration_months 12
    outputs:
      highly_sensitive:
        cohort: output/dataset_incidence.csv

  generate_dataset_incidence_ref:
    run: ehrql:v1 generate-dataset analysis/dataset_definition_incidence_ref.py 
      --output output/dataset_incidence_ref.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
    outputs:
      highly_sensitive:
        cohort: output/dataset_incidence_ref.csv

  reference_cleaning:
    run: stata-mp:latest analysis/003_reference_cleaning.do
    needs: [generate_dataset_incidence_ref]
    outputs:
      moderately_sensitive:
        log1: logs/reference_cleaning.log   
        table1: output/tables/reference_table_rounded.csv        
"""
# Include incidence is specified +/- sensitivity analyses
yaml_incidence_sens_dataset = ""

if incidence_sensitivity == "yes":
    yaml_incidence_sens_dataset = f"""
  generate_dataset_incidence_sens:
    run: ehrql:v1 generate-dataset analysis/dataset_definition_incidence.py
      --output output/dataset_incidence_sens.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
      --registration_months 24
    outputs:
      highly_sensitive:
        cohort: output/dataset_incidence_sens.csv
"""

incidence_runs = [
    {
        "suffix": "",
        "months": 12,
    }
]

if incidence_sensitivity == "yes":
    incidence_runs.append(
      {
          "suffix": "_sens",
          "months": 24,
      }
    )
    
yaml_incidence = ""

if incidence_graphs == "yes":
    
  for run in incidence_runs:

        suffix = run["suffix"]
        months = run["months"]

        dataset_action = (
          "generate_dataset_incidence_sens"
          if suffix == "_sens"
          else "generate_dataset_incidence"
        )

        all_needs_incidence = []

        yaml_incidence_measures_template = """
  generate_measures{suffix}_{year}:
    run: ehrql:v1 generate-measures analysis/dataset_definition_incidence_measures.py
      --output output/measures/measures_incidence{suffix}_{year}.csv
      --
      --measure_date "{year}-04-01"
      --intervals {intervals}
      --registration_months {months}
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
    needs: [{dataset_action}]
    outputs:
      highly_sensitive:
        measure_csv: output/measures/measures_incidence{suffix}_{year}.csv
"""

        for year in range(start_year, end_year):
          intervals = calculate_intervals(year, end_dt)

          yaml_incidence += yaml_incidence_measures_template.format(
              year=year,
              intervals=intervals,
              suffix=suffix,
              months=months,
              dataset_action=dataset_action,
              studystart_date=studystart_date,
              studyend_date=studyend_date,
              studyfup_date=studyfup_date,
              diseases_list=diseases_list,
          )
          all_needs_incidence.append(f"generate_measures{suffix}_{year}")
        
          needs_list_incidence = ", ".join(all_needs_incidence)

        yaml_incidence += f"""
  incidence_cleaning{suffix}:
    run: stata-mp:latest analysis/001_incidence_cleaning.do "{diseases_list_stata}" "{studystart_date}" "{studyend_date}" "{suffix}"
    needs: [{dataset_action}, {needs_list_incidence}]
    outputs:
      moderately_sensitive:
        log1: logs/incidence_cleaning{suffix}.log
        table1: output/tables/incidence_rates_rounded{suffix}.csv
        table2: output/tables/incidence_rates_rounded_subgroups{suffix}.csv
        table3: output/tables/baseline_table_rounded{suffix}.csv
        table4: output/tables/mean_age_rounded{suffix}.csv

  incidence_graphs{suffix}:
    run: stata-mp:latest analysis/002_incidence_graphs.do "{diseases_list_stata}" "{intervention_date_covid}" "{suffix}"
    needs: [incidence_cleaning{suffix}]
    outputs:
      moderately_sensitive:
        log1: logs/incidence_graphs{suffix}.log
        figure1: output/figures/inc_rate{suffix}_*.svg
        figure2: output/figures/inc_comp{suffix}_*.svg
        figure3: output/figures/adj_sex{suffix}_*.svg
        figure4: output/figures/unadj_age{suffix}_*.svg
        figure5: output/figures/unadj_imd{suffix}_*.svg
        figure6: output/figures/unadj_ethn{suffix}_*.svg
        figure7: output/figures/mean_age{suffix}_*.svg
        figure8: output/figures/median_age{suffix}_*.svg
        figure9: output/figures/mean_med_age{suffix}_*.svg

  sarima{suffix}:
    run: r:latest analysis/200_sarima.R "{intervention_date_covid}" "{suffix}"
    needs: [incidence_cleaning{suffix}]
    outputs:
      moderately_sensitive:
        log1: logs/sarima_log{suffix}.txt
        figure1: output/figures/auto_residuals{suffix}_*.svg
        figure2: output/figures/obs_pred{suffix}_*.svg
        table1: output/tables/change_incidence_byyear{suffix}.csv
"""

# Include prevalence if specified
yaml_prevalence = ""

if prevalence == "yes":

    yaml_prevalence = f"""
  generate_dataset_prevalence:
    run: ehrql:v1 generate-dataset analysis/dataset_definition_prevalence.py
      --output output/dataset_prevalence.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
    outputs:
      highly_sensitive:
        cohort: output/dataset_prevalence.csv
"""

    all_needs_prevalence = []

    yaml_prevalence_measures_template = """
  prevalence_measures_{disease}:
    run: ehrql:v1 generate-measures analysis/dataset_definition_prevalence_measures.py
      --output output/measures/measures_prevalence_{disease}.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
      --disease "{disease}"
      --intervals {intervals}
    needs: [generate_dataset_prevalence]
    outputs:
      highly_sensitive:
        measure_csv: output/measures/measures_prevalence_{disease}.csv
"""

    for disease in diseases_str:
      yaml_prevalence += yaml_prevalence_measures_template.format(
          studystart_date=studystart_date,
          studyend_date=studyend_date,
          studyfup_date=studyfup_date,
          diseases_list=diseases_list,
          disease=disease,
          intervals=end_year - start_year,
      )
      all_needs_prevalence.append(f"prevalence_measures_{disease}")

    needs_list_prevalence = ", ".join(["generate_dataset_prevalence"] + all_needs_prevalence)

    yaml_prevalence += f"""
  prevalence_cleaning:
    run: stata-mp:latest analysis/004_prevalence_cleaning.do "{diseases_list_stata}"
    needs: [{needs_list_prevalence}]
    outputs:
      moderately_sensitive:
        log1: logs/prevalence_cleaning.log   
        table1: output/tables/prevalence_rates_rounded.csv

  prevalence_graphs:
    run: stata-mp:latest analysis/005_prevalence_graphs.do "{diseases_list_stata}" "{intervention_date_covid}"
    needs: [prevalence_cleaning]
    outputs:
      moderately_sensitive:
        log1: logs/prevalence_graphs.log   
        figure1: output/figures/prev_adj_*.svg
        figure2: output/figures/prev_comp_*.svg  
"""    
    
# Include EIA analyses if specified
yaml_eia = ""

if eia == "yes":

    yaml_eia = f"""
  generate_dataset_eia:
    run: ehrql:v1 generate-dataset analysis/dataset_definition_eia.py 
      --output output/dataset_eia.csv
      --
      --studystart_date "{studystart_date}"
      --studyend_date "{studyend_date}"
      --studyfup_date "{studyfup_date}"
      --diseases_list {diseases_list}
      --registration_months 12
    needs: [generate_dataset_incidence]
    outputs:
      highly_sensitive:
        cohort: output/dataset_eia.csv

  eia_cleaning:
    run: stata-mp:latest analysis/100_eia_cleaning.do "{studystart_date}" "{studyend_date}" "{studyfup_date}"
    needs: [generate_dataset_eia]
    outputs:
      highly_sensitive:
        log1: logs/eia_cleaning.log   
        data1: output/data/file_eia_all.dta  

  eia_box_plots:
    run: stata-mp:latest analysis/300_eia_box_plots.do
    needs: [eia_cleaning]
    outputs:
      moderately_sensitive:
        log1: logs/eia_box_plots.log   
        figure 1: output/figures/eia_regional_qs2_bar_*.svg 
        figure 2: output/figures/eia_regional_csdmard_bar_*.svg                           
"""
  
# Include GCA analyses if specified
yaml_gca = ""

if gca == "yes":

    yaml_gca = f"""
  generate_dataset_gca:
      run: ehrql:v1 generate-dataset analysis/dataset_definition_gca.py 
        --output output/dataset_gca.csv
        --
        --studystart_date "{studystart_date}"
        --studyend_date "{studyend_date}"
        --studyfup_date "{studyfup_date}"
        --diseases_list {diseases_list}
        --registration_months 12
      needs: [generate_dataset_incidence]
      outputs:
        highly_sensitive:
          cohort: output/dataset_gca.csv

  gca_cleaning:
    run: stata-mp:latest analysis/101_gca_cleaning.do "{studystart_date}" "{studyend_date}" "{studyfup_date}"
    needs: [generate_dataset_gca]
    outputs:
      highly_sensitive:
        log1: logs/gca_cleaning.log   
        data1: output/data/gca_processed.dta

  gca_datatables:
    run: stata-mp:latest analysis/201_gca_datatables.do "{studystart_date}" "{studyend_date}" "{studyfup_date}"
    needs: [gca_cleaning]
    outputs:
      moderately_sensitive:
        log1: logs/gca_datatables.log   
        table1: output/tables/gca_datatable_*.csv

  gca_temporal_plots:
    run: stata-mp:latest analysis/301_gca_plots.do "{studystart_date}" "{studyend_date}" "{studyfup_date}" "{intervention_date_covid}"
    needs: [gca_datatables]
    outputs:
      moderately_sensitive:
        log1: logs/gca_plots.log   
        figure1: output/figures/gca_plot_*.svg                                                            
"""

# Combine header, body, and footer
generated_yaml = yaml_header + yaml_incidence_sens_dataset + yaml_incidence + yaml_prevalence + yaml_eia + yaml_gca

# Save to a file
with open("project.yaml", "w") as file:
    file.write(generated_yaml)