# ehrQL codelists
from databuilder.ehrql import codelist_from_csv

# DEMOGRAPHIC CODELIST
ethnicity_codes = codelist_from_csv(
    "codelists/opensafely-ethnicity.csv",
    column="Code",
    category_column="Grouping_6",
)

# SMOKING CODELIST
clear_smoking_codes = codelist_from_csv(
    "codelists/opensafely-smoking-clear.csv",
    column="CTV3Code",
    category_column="Category",
)

# CLINICAL CONDITIONS CODELISTS
ankylosing_spondylitis_codes = codelist_from_csv(
    "codelists/user-markdrussell-axial-spondyloarthritis.csv", column="code",
)

psoriatic_arthritis_codes = codelist_from_csv(
    "codelists/user-markdrussell-psoriatic-arthritis.csv", column="code",
)

rheumatoid_arthritis_codes = codelist_from_csv(
    "codelists/user-markdrussell-new-rheumatoid-arthritis.csv", column="code",
)

undifferentiated_arthritis_codes = codelist_from_csv(
    "codelists/user-markdrussell-undiff-eia.csv", column="code",
)

eia_diagnosis_codes = (
    ankylosing_spondylitis_codes +
    psoriatic_arthritis_codes +
    rheumatoid_arthritis_codes +
    undifferentiated_arthritis_codes
)

chronic_cardiac_disease_codes = codelist_from_csv(
    "codelists/opensafely-chronic-cardiac-disease.csv", column="CTV3ID",
)

diabetes_codes = codelist_from_csv(
    "codelists/opensafely-diabetes.csv", column="CTV3ID",
)

hba1c_new_codes = ["XaPbt", "Xaeze", "Xaezd"]
hba1c_old_codes = ["X772q", "XaERo", "XaERp"]

hypertension_codes = codelist_from_csv(
    "codelists/opensafely-hypertension.csv", column="CTV3ID",
)

chronic_respiratory_disease_codes = codelist_from_csv(
    "codelists/opensafely-chronic-respiratory-disease.csv",
    column="CTV3ID",
)

copd_codes = codelist_from_csv(
    "codelists/opensafely-current-copd.csv", column="CTV3ID",
)

chronic_liver_disease_codes = codelist_from_csv(
    "codelists/opensafely-chronic-liver-disease.csv", column="CTV3ID",
)

stroke_codes = codelist_from_csv(
    "codelists/opensafely-stroke-updated.csv", column="CTV3ID",
)

lung_cancer_codes = codelist_from_csv(
    "codelists/opensafely-lung-cancer.csv", column="CTV3ID",
)

haem_cancer_codes = codelist_from_csv(
    "codelists/opensafely-haematological-cancer.csv", column="CTV3ID",
)

other_cancer_codes = codelist_from_csv(
    "codelists/opensafely-cancer-excluding-lung-and-haematological.csv",
    column="CTV3ID",
)

creatinine_codes = ["XE2q5"]

ckd_codes = codelist_from_csv(
    "codelists/opensafely-chronic-kidney-disease.csv", column="CTV3ID",
)

bmi_codes = ["60621009", "846931000000101"]

referral_rheumatology = codelist_from_csv(
    "codelists/user-markdrussell-referral-rheumatology.csv", column = "code"
)

# MEDICATIONS
hydroxychloroquine_codes = codelist_from_csv(
    "codelists/opensafely-hydroxychloroquine.csv", column="code"
)  
leflunomide_codes = codelist_from_csv(  
    "codelists/opensafely-leflunomide-dmd.csv", column="code"
)    
methotrexate_codes = codelist_from_csv(                   
    "codelists/opensafely-methotrexate-oral.csv", column="code"
)                   
methotrexate_inj_codes = codelist_from_csv(                         
    "codelists/opensafely-methotrexate-injectable.csv", column="code"
)                   
sulfasalazine_codes = codelist_from_csv(       
    "codelists/opensafely-sulfasalazine-oral-dmd.csv", column="code"
)
abatacept_codes = codelist_from_csv(       
    "codelists/opensafely-high-cost-drugs-abatacept.csv", column="olddrugname"
)
adalimumab_codes = codelist_from_csv(       
    "codelists/opensafely-high-cost-drugs-adalimumab.csv", column="olddrugname"
)
baricitinib_codes = codelist_from_csv(       
    "codelists/opensafely-high-cost-drugs-baricitinib.csv", column="olddrugname"
)
certolizumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-certolizumab.csv", column="olddrugname"
)
etanercept_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-etanercept.csv", column="olddrugname"
)
golimumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-golimumab.csv", column="olddrugname"
)
guselkumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-guselkumab.csv", column="olddrugname"
)
infliximab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-infliximab.csv", column="olddrugname"
)
ixekizumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-ixekizumab.csv", column="olddrugname"
)
methotrexate_hcd_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-methotrexate.csv", column="olddrugname"
)
rituximab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-rituximab.csv", column="olddrugname"
)
sarilumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-sarilumab.csv", column="olddrugname"
)
secukinumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-secukinumab.csv", column="olddrugname"
)
tocilizumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-tocilizumab.csv", column="olddrugname"
)
tofacitinib_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-tofacitinib.csv", column="olddrugname"
)
upadacitinib_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-upadacitinib.csv", column="olddrugname"
)
ustekinumab_codes = codelist_from_csv( 
    "codelists/opensafely-high-cost-drugs-ustekinumab.csv", column="olddrugname"
)