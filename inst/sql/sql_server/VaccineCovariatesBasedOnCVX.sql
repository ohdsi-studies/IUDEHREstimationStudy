{DEFAULT @cvx_table_name = "cvx_vaccine_groups"}
{DEFAULT @cvx_ndc_table_name = "cvx_to_ndc_crosswalk"}

with rxnorm_to_cvx as {
    SELECT *
    FROM @vocabulary_database_schema.concept as c
    JOIN @vocabulary_database_schema.concept_relationship as cr ON c.concept_id=cr.concept_id_1 AND
                                                                   c.vocabulary_id='RxNorm' AND
                                                                   cr.relationship_id = 'Mapped from'
    JOIN @vocabulary_database_schema.concept as c2              ON cr.concept_id_2=c2.concept_id and c2.vocabulary_id='NDC'
    JOIN @target_database_schema.cvx_to_ndc_crosswalk as cw     ON cw.sale_ndc_clean=c2.concept_code
    JOIN @target_database_schema.cvx_table_name as cvx          ON cvx.sale_ndc=c2.concept_code
}
SELECT ch.subject_id AS row_id,
--        c2.concept_id AS covariate_id
       cvx.vaccine_group_code AS covariate_id,
       1 AS covariate_value,
       cvx.vaccine_group_name AS covariate_name
FROM @target_database_schema.@cohort_table as ch
INNER JOIN @cdm_database_schema.drug_exposure as de            ON de.person_id = ch.subject_id
INNER JOIN @vocabulary_database_schema.concept as c            ON de.drug_concept_id = c.concept_id
INNER JOIN @target_database_schema.@cvx_table_name as cvx      ON cvx.cvx_code = c.concept_code
INNER JOIN @vocabulary_database_schema.concept as c2           ON cvx.vaccine_group_code = c2.concept_code
WHERE c.vocabulary_id = 'CVX'  AND DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days
      {@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}

UNION

SELECT ch.subject_id AS row_id,
--        c2.concept_id AS covariate_id
       cvx.vaccine_group_code AS covariate_id, --CAST(ancestor_concept_id AS BIGINT) * 1000 + @analysis_id
       1 AS covariate_value,
       cvx.vaccine_group_name AS covariate_name
FROM @target_database_schema.@cohort_table as ch
INNER JOIN @cdm_database_schema.drug_exposure as de            ON de.person_id = ch.subject_id
INNER JOIN @vocabulary_database_schema.concept as c            ON de.drug_concept_id = c.concept_id
INNER JOIN @target_database_schema.@cvx_table_name as cvx      ON cvx.cvx_code = c.concept_code
INNER JOIN @vocabulary_database_schema.concept as c2           ON cvx.vaccine_group_code = c2.concept_code
WHERE c.vocabulary_id = 'CVX'  AND DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days
      {@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}
