#############################################################################################
# file: vaccineCovariateBuilder.R
# Two functions required for the vaccine custom covariate builder
# These can be put in a separate R script and sourced before running feature extraction

createVaccineCovariateSettings <- function(lookbackDays = 180, cohortTable = "cohort_person") {
  covariateSettings <- list(lookbackDays = lookbackDays, cohortTable = cohortTable)
  attr(covariateSettings, "fun") <- "getDbVaccineCovariateData"
  class(covariateSettings) <- "covariateSettings"
  return(covariateSettings)
}


getDbVaccineCovariateData <- function(connection,
                                      oracleTempSchema = NULL,
                                      cdmDatabaseSchema,
                                      cohortTable = "cohort_person",
                                      cohortId = -1,
                                      cdmVersion = "5",
                                     # cohortDatabaseSchema,
                                      rowIdField = "subject_id",
                                      covariateSettings,
                                      aggregated = FALSE) {

  writeLines("Constructing Vaccine covariates using CVX Groups")
  if (covariateSettings$lookbackDays < 1) return(NULL)
  if (rowIdField != "subject_id") stop("Only subject_id as rowId is supported.")
  if (aggregated)  aggregated <- FALSE #stop("Aggregation not supported")

  # Some SQL to construct the covariate:
  # sql <- paste("SELECT ch.subject_id AS row_id",
  #              ",de.drug_concept_id AS covariate_id",
  #              ",1 AS covariate_value",
  #              ",de.drug_concept_id AS concept_id",
  #              ",c.concept_name AS covariate_name",
  #              "FROM @cohort_table ch",
  #              "INNER JOIN @cdm_database_schema.drug_exposure de",
  #              "ON de.person_id = ch.subject_id",
  #              "INNER JOIN @cdm_database_schema.concept c",
  #              "ON de.drug_concept_id = c.concept_id",
  #              "WHERE c.vocabulary_id = 'CVX'",
  #              "AND DATEDIFF(DAY, de.drug_exposure_start_date, ch.cohort_start_date) <= @lookback_days",
  #              "{@cohort_id != -1} ? {AND cohort_definition_id = @cohort_id}")
  # sql <- SqlRender::render(sql,
  #                          cohort_table = cohortTable,
  #                          cohort_id = cohortId,
  #                          cdm_database_schema = cdmDatabaseSchema,
  #                          lookback_days = covariateSettings$lookbackDays)
  # sql <- SqlRender::translate(sql, targetDialect = attr(connection, "dbms"))

  sqlFile <- "VaccineCovariatesBasedOnCVXGroups.sql"

  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = sqlFile,
                                           packageName = "IUDEHRStudy",
                                           dbms = attr(connection, "dbms"),
                                           tempEmulationSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           vocabulary_database_schema = cdmDatabaseSchema,
                                           target_database_schema = cohortDatabaseSchema,
                                           cvx_group_table_name = "cvx_groups",
                                           cohort_table = cohortTable,
                                           cohort_id = cohortId,
                                           row_id_field = rowIdField)

  # Retrieve the covariate:
  # sqlResult <- DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, reportOverallTime = FALSE)
  sqlResult <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)

  if (nrow(sqlResult) < 1) {
    message("No persons in the cohort with vaccine covariates.")
  }

  sqlResult$analysisId <- 10000
  covariates <- sqlResult[, c("rowId", "covariateId", "covariateValue")]
  covariateRef <- sqlResult[, c("covariateId", "covariateName", "analysisId", "conceptId")]

  # Construct analysis reference:
  analysisRef <- data.frame(analysisId = 10000,
                            analysisName = "CVX Vaccine Covariates",
                            domainId = "Drug",
                            startDay = 0, #-covariateSettings$lookbackDays,
                            endDay = 0,
                            isBinary = "Y",
                            missingMeansZero = "Y")

  # Construct analysis reference:
  metaData <- list(sql = sql, call = match.call())
  result <- Andromeda::andromeda(covariates = covariates,
                                 covariateRef = covariateRef,
                                 analysisRef = analysisRef)
  attr(result, "metaData") <- metaData
  class(result) <- "CovariateData"
  return(result)
}

######################################################################################################
# main analysis script

# library(FeatureExtraction)
# source("vaccineCovariateBuilder.R")
#
# # Create your connection details
# connectionDetails <- DatabaseConnector::createConnectionDetails()
#
# # create your normal covariate settings
# covariateSettings <- createCovariateSettings(useDemographicsGender = TRUE,
#                                              useDemographicsAgeGroup = TRUE)
#
# # create the vaccine covariate settings
# vaccineCovariateSettings <- createVaccineCovariateSettings(lookbackDays = 3650)
#
# # combine both covariate settings into a list
# covariateSettingsList <- list(covariateSettings, vaccineCovariateSettings)
#
# # run feature extraction as normal
# run feature extraction as normal
# covariates <- getDbCovariateData(connectionDetails = connectionDetails,
#                                  cdmDatabaseSchema = cdmDatabaseSchema,
#                                  cohortDatabaseSchema = cohortDatabaseSchema,
#                                  cohortTable = "iudstudy",
#                                  cohortId = 1771648, # The cohort to extract features for
#                                  covariateSettings = covariateSettingsList)#
#
# # take a look at first few rows of the vaccine covariates
# covariates$covariates %>%
#   left_join(covariates$covariateRef) %>%
#   left_join(covariates$analysisRef) %>%
#   filter(analysisId == 1000) %>%
#   head(10) %>%
#   collect()

