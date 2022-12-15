--This query attempts to group all vaccine products under CVX codes, including
--vaccines in the drug_exposure table coded in RxNorm
{DEFAULT @table_name = "cvx_vaccine_groups"}

SELECT ch.subject_id AS row_id,
--        c2.concept_id AS covariate_id
       cvx.vaccine_group_code AS covariate_id,
       1 AS covariate_value,
       cvx.vaccine_group_name AS covariate_name
FROM @cohort_table ch
INNER JOIN @cdm_database_schema.drug_exposure de     ON de.person_id = ch.subject_id
INNER JOIN @cdm_database_schema.concept c            ON de.drug_concept_id = c.concept_id
INNER JOIN @target_database_schema.@table_name cvx   ON cvx.cvx_code = c.concept_code
INNER JOIN @cdm_database_schema.concept c2            ON cvx.vaccine_group_code = c2.concept_code
WHERE c.vocabulary_id = 'CVX' AND DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days
      {@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}