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
axialspa_snomed = codelist_from_csv(
    "codelists/user-markdrussell-axial-spondyloarthritis.csv", column="code",
)

axialspa_icd = codelist_from_csv(
    "codelists/user-markdrussell-axial-spondyloarthritis-secondary-care.csv", column="code",
)

psa_snomed = codelist_from_csv(
    "codelists/user-markdrussell-psoriatic-arthritis.csv", column="code",
)

psa_icd = codelist_from_csv(
    "codelists/user-markdrussell-psoriatic-arthritis-secondary-care.csv", column="code",
)

rheumatoid_snomed = codelist_from_csv(
    "codelists/user-markdrussell-new-rheumatoid-arthritis.csv", column="code",
)

rheumatoid_icd = codelist_from_csv(
    "codelists/user-markdrussell-rheumatoid-arthritis-secondary-care.csv", column="code",
)

undiffia_snomed = codelist_from_csv(
    "codelists/user-markdrussell-undiff-eia.csv", column="code",
)

eia_diagnosis_codes = (
    axialspa_snomed +
    psa_snomed +
    rheumatoid_snomed +
    undiffia_snomed
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

rf_tests = codelist_from_csv(
    "codelists/user-markdrussell-rheumatoid-factor.csv", column = "code"
)

ccp_tests = codelist_from_csv(
    "codelists/user-markdrussell-cyclic-citrullinated-peptide-ccp-antibody.csv", column = "code"
)

rf_codes = codelist_from_csv(
    "codelists/user-markdrussell-rheumatoid-factor-positive-finding.csv", column = "code"
)

ccp_codes = codelist_from_csv(
    "codelists/user-markdrussell-cyclic-citrullinated-peptide-ccp-antibody-positive-finding.csv", column = "code"
)

seropositive_codes = codelist_from_csv(
    "codelists/user-markdrussell-seropositive-rheumatoid-arthritis.csv", column = "code"
)

erosive_codes = codelist_from_csv(
    "codelists/user-markdrussell-erosive-rheumatoid-arthritis.csv", column = "code"
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
steroid_codes = codelist_from_csv(       
    "codelists/user-markdrussell-corticosteroids-oral-im-or-iv-dmd.csv", column="code"
)