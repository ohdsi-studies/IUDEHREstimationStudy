#############################################################################################
# file: vaccineCovariateBuilder.R
# Two functions required for the vaccine custom covariate builder
# These can be put in a separate R script and sourced before running feature extraction
#' @export
createVaccineCovariateSettings <- function(lookbackDays = 180, cohortTable = "cohort_person", analysisId = 555, cohortDatabaseSchema) {
  if (lookbackDays < 1){
    stop('lookbackDays must be >= 1')
  }
  covariateSettings <- list(lookbackDays = lookbackDays, cohortTable = cohortTable, analysisId = analysisId, cohortDatabaseSchema = cohortDatabaseSchema)
  attr(covariateSettings, "fun") <- "IUDEHRStudy::getDbVaccineCovariateData"
  class(covariateSettings) <- "covariateSettings"
  return(covariateSettings)
}

#' @export
getDbVaccineCovariateData <- function(connection,
                                      cdmDatabaseSchema,
                                      oracleTempSchema = NULL,
                                      cohortTable = "cohort_person",
                                      cohortId = -1,
                                      cdmVersion = "5",
                                      rowIdField = "subject_id",
                                      covariateSettings,
                                      aggregated = FALSE) {

  #writeLines("Constructing Vaccine covariates using CVX Groups")
  ParallelLogger::logInfo(paste0("*** Constructing Vaccine covariates using CVX Groups for ", cohortId, " ***"))
  #if (rowIdField != "subject_id") stop(paste0("Only subject_id as rowId is supported. This value was used ", rowIdField))
  if (aggregated)  aggregated <- FALSE #stop("Aggregation not supported")

  sqlFile <- "VaccineCovariatesBasedOnCVXGroups.sql"
  cohortDatabaseSchema <- covariateSettings$cohortDatabaseSchema
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = sqlFile,
                                           packageName = "IUDEHRStudy",
                                           dbms = attr(connection, "dbms"),
                                           tempEmulationSchema = oracleTempSchema,
                                           cdm_database_schema = cdmDatabaseSchema,
                                           vocabulary_database_schema = cdmDatabaseSchema,
                                           target_database_schema = cohortDatabaseSchema,
                                           cvx_group_table_name = "cvx_groups",
                                           cohort_table = cohortTable,
                                           cohort_id = cohortId)

  # Retrieve the covariate:
  # sqlResult <- DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, reportOverallTime = FALSE)
  sqlResult <- DatabaseConnector::querySql(connection, sql, snakeCaseToCamelCase = TRUE)

  if (nrow(sqlResult) < 1) {
    message("No persons in the cohort with vaccine covariates.")
  }

  #sqlResult$analysisId <- 555
  
  #ToDo: 
  covariates <- unique(sqlResult[, c("rowId", "covariateId", "covariateValue")])
  covariateRef <- unique(sqlResult[, c("covariateId", "covariateName", "conceptId")])

  # Construct analysis reference:
  analysisRef <- data.frame(analysisId = covariateSettings$analysisId,
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
#   filter(analysisId == 555) %>%
#   head(10) %>%
#   collect()

