{DEFAULT @cvx_group_table_name = "cvx_groups"}
{DEFAULT @row_id_field = "subject_id"}
{DEFAULT @analysis_id = "555"}

-- Feature construction
with rxnorm_to_cvx as (
    SELECT cr.concept_id_1 as rx_norm_concept_id, cr.concept_id_2 as cvx_concept_id, c2.concept_code as cvx_code --c.concept_name,
    FROM @vocabulary_database_schema.concept as c1
    JOIN @vocabulary_database_schema.concept_relationship as cr ON c1.concept_id = cr.concept_id_1 AND
                                                                   c1.vocabulary_id = 'RxNorm' AND
                                                                   cr.relationship_id = 'RxNorm - CVX' --RxNorm mapping
    JOIN @vocabulary_database_schema.concept as c2              ON cr.concept_id_2 = c2.concept_id
)
SELECT @row_id_field AS row_id,
       CAST(cvx.vaccine_group_code AS BIGINT) * 1000 + @analysis_id  AS covariate_id,
       1 AS covariate_value,  -- Should this be the number of days before index date or a binary value
       CAST(CONCAT('CVX group any time prior to index: ', CASE WHEN cvx.vaccine_group_name IS NULL THEN 'Unknown CVX Group' ELSE cvx.vaccine_group_name END) AS VARCHAR(512)) AS covariate_name,
       c2.concept_id --as cvx_group_concept_id
FROM @cohort_table as ch
JOIN @cdm_database_schema.drug_exposure as de             ON de.person_id = ch.subject_id
JOIN rxnorm_to_cvx rc                                     ON de.drug_concept_id = rc.rx_norm_concept_id
JOIN @target_database_schema.@cvx_group_table_name as cvx ON cvx.cvx_code = rc.cvx_code
JOIN @vocabulary_database_schema.concept as c2            ON rc.cvx_code=c2.concept_code and c2.vocabulary_id='CVX'
WHERE de.drug_exposure_start_date <= ch.cohort_start_date --DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days
      {@cohort_id != -1} ? { AND cohort_definition_id = @cohort_id}

UNION

SELECT @row_id_field AS row_id,
       CAST(cvx.vaccine_group_code AS BIGINT) * 1000 + @analysis_id  AS covariate_id,
       1 AS covariate_value,   -- Should this be the number of days before index date or a binary value
       CAST(CONCAT('CVX group any time prior to index: ', CASE WHEN cvx.vaccine_group_name IS NULL THEN 'Unknown CVX Group' ELSE cvx.vaccine_group_name END) AS VARCHAR(512)) AS covariate_name,
       c2.concept_id --as cvx_group_concept_id
FROM @cohort_table as ch
JOIN @cdm_database_schema.drug_exposure as de            ON de.person_id = ch.subject_id
JOIN @vocabulary_database_schema.concept as c            ON de.drug_concept_id = c.concept_id
JOIN @target_database_schema.@cvx_group_table_name as cvx      ON cvx.cvx_code = c.concept_code and c.vocabulary_id = 'CVX'
JOIN @vocabulary_database_schema.concept as c2           ON cvx.cvx_code=c2.concept_code and c2.vocabulary_id='CVX'
WHERE c.vocabulary_id = 'CVX'  AND
      de.drug_exposure_start_date <= ch.cohort_start_date --DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days
      {@cohort_id != -1} ? { AND cohort_definition_id = @cohort_id}