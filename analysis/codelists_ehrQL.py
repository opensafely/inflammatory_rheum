# ehrQL codelists
from ehrql import codelist_from_csv

# Demographics
ethnicity_codes = codelist_from_csv(
    "codelists/opensafely-ethnicity-snomed-0removed.csv",
    column="code",
    category_column="Grouping_6",
)

# Smoking
clear_smoking_codes = codelist_from_csv(
    "codelists/opensafely-smoking-clear.csv",
    column="CTV3Code",
    category_column="Category",
)

# Inflammatory rheumatology diagnoses
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

# Relevant comorbidities
chd_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-chd_cod.csv", column="code",
)

diabetes_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dmtype2audit_cod.csv", column="code",
)

ild_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-interstitial-lung-disease-codes.csv",
    column="code",
)

copd_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-copd_cod.csv", column="code",
)

stroke_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-strk_cod.csv", column="code",
)

tia_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-tia_cod.csv", column="code",
)

cva_codes = (
    stroke_codes +
    tia_codes
)

lung_cancer_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-lung-cancer-codes.csv", column="code",
)

haem_cancer_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-c19haemcan_cod.csv", column="code",
)

solid_cancer_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-solid-cancer-diagnosis-codes.csv", column="code",
)

ckd_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-ckdatrisk2_cod.csv", column="code",
)

creatinine_codes = codelist_from_csv(
    "codelists/ardens-creatinine-level.csv", column="code",
)

depression_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-depr_cod.csv", column="code",
)

osteoporosis_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-osteo_cod.csv", column="code",
)

## Fragility fracture
fracture_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-ff_cod.csv", column="code",
)

dementia_codes = codelist_from_csv(
    "codelists/nhsd-primary-care-domain-refsets-dem_cod.csv", column="code",
)

bmi_codes = ["60621009", "846931000000101"]

referral_rheumatology = codelist_from_csv(
    "codelists/user-markdrussell-referral-rheumatology.csv", column = "code"
)

rf_codes = codelist_from_csv(
    "codelists/ardens-rheumatoid-factor.csv", column = "code"
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