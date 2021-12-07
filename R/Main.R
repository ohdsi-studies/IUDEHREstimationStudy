# Copyright 2019 Observational Health Data Sciences and Informatics
#
# This file is part of IUDEHRStudy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#' Execute the Study
#'
#' @details
#' This function executes the IUDEHRS Study.
#' 
#' The \code{createCohorts}, \code{synthesizePositiveControls}, \code{runAnalyses}, and \code{runDiagnostics} arguments
#' are intended to be used to run parts of the full study at a time, but none of the parts are considered to be optional.
#'
#' @param connectionDetails    An object of type \code{connectionDetails} as created using the
#'                             \code{\link[DatabaseConnector]{createConnectionDetails}} function in the
#'                             DatabaseConnector package.
#' @param cdmDatabaseSchema    Schema name where your patient-level data in OMOP CDM format resides.
#'                             Note that for SQL Server, this should include both the database and
#'                             schema name, for example 'cdm_data.dbo'.
#' @param cohortDatabaseSchema Schema name where intermediate data can be stored. You will need to have
#'                             write priviliges in this schema. Note that for SQL Server, this should
#'                             include both the database and schema name, for example 'cdm_data.dbo'.
#' @param cohortTable          The name of the table that will be created in the work database schema.
#'                             This table will hold the exposure and outcome cohorts used in this
#'                             study.
#' @param oracleTempSchema     Should be used in Oracle to specify a schema where the user has write
#'                             priviliges for storing temporary tables.
#' @param outputFolder         Name of local folder to place results; make sure to use forward slashes
#'                             (/). Do not use a folder on a network drive since this greatly impacts
#'                             performance.
#' @param databaseId           A short string for identifying the database (e.g.
#'                             'Synpuf').
#' @param databaseName         The full name of the database (e.g. 'Medicare Claims
#'                             Synthetic Public Use Files (SynPUFs)').
#' @param databaseDescription  A short description (several sentences) of the database.
#' @param createCohorts        Create the cohortTable table with the exposure and outcome cohorts?
#' @param synthesizePositiveControls  Should positive controls be synthesized?
#' @param runAnalyses          Perform the cohort method analyses?
#' @param runDiagnostics       Compute study diagnostics?
#' @param packageResults       Should results be packaged for later sharing?     
#' @param maxCores             How many parallel cores should be used? If more cores are made available
#'                             this can speed up the analyses.
#' @param minCellCount         The minimum number of subjects contributing to a count before it can be included 
#'                             in packaged results.
#'
#' @examples
#' \dontrun{
#' connectionDetails <- createConnectionDetails(dbms = "postgresql",
#'                                              user = "joe",
#'                                              password = "secret",
#'                                              server = "myserver")
#'
#' execute(connectionDetails,
#'         cdmDatabaseSchema = "cdm_data",
#'         cohortDatabaseSchema = "study_results",
#'         cohortTable = "cohort",
#'         oracleTempSchema = NULL,
#'         outputFolder = "c:/temp/study_results",
#'         maxCores = 4)
#' }
#'
#' @export
execute <- function(connectionDetails,
                    cdmDatabaseSchema,
                    cohortDatabaseSchema = cdmDatabaseSchema,
                    cohortTable = "cohort",
                    oracleTempSchema = cohortDatabaseSchema,
                    outputFolder,
                    databaseId = "Unknown",
                    databaseName = "Unknown",
                    databaseDescription = "Unknown",
                    createCohorts = TRUE,
                    reloadData = TRUE,
                    synthesizePositiveControls = TRUE,
                    runAnalyses = TRUE,
                    runDiagnostics = TRUE,
                    packageResults = TRUE,
                    maxCores = 4,
                    minCellCount = 5) {

  package <- "IUDEHRStudy"
  if (!file.exists(outputFolder))
    dir.create(outputFolder, recursive = TRUE)

  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))
  ParallelLogger::addDefaultErrorReportLogger(file.path(outputFolder, "errorReportR.txt"))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_FILE_LOGGER", silent = TRUE))
  on.exit(ParallelLogger::unregisterLogger("DEFAULT_ERRORREPORT_LOGGER", silent = TRUE), add = TRUE)

  initializeStudy(outputFolder, connectionDetails, cohortDatabaseSchema, oracleTempSchema, package, reloadData)

  if (createCohorts) {
    ParallelLogger::logInfo("Creating exposure and outcome cohorts")
    createCohorts(connectionDetails = connectionDetails,
                  cdmDatabaseSchema = cdmDatabaseSchema,
                  cohortDatabaseSchema = cohortDatabaseSchema,
                  cohortTable = cohortTable,
                  oracleTempSchema = oracleTempSchema,
                  outputFolder = outputFolder)
  }

  # Set doPositiveControlSynthesis to FALSE if you don't want to use synthetic positive controls:
  doPositiveControlSynthesis = FALSE
  if (doPositiveControlSynthesis) {
    if (synthesizePositiveControls) {
      ParallelLogger::logInfo("Synthesizing positive controls")
      synthesizePositiveControls(connectionDetails = connectionDetails,
                                 cdmDatabaseSchema = cdmDatabaseSchema,
                                 cohortDatabaseSchema = cohortDatabaseSchema,
                                 cohortTable = cohortTable,
                                 oracleTempSchema = oracleTempSchema,
                                 outputFolder = outputFolder,
                                 maxCores = maxCores)
    }
  }

  cohortCountsFile <- file.path(outputFolder, "CohortCounts.csv")
  if (!file.exists(cohortCountsFile)) {
    ParallelLogger::logInfo(paste("CohortCounts file not found. File: ", cohortCountsFile))
  } else {

    cohortCounts <- read.csv(cohortCountsFile) #get the cohort counts from earlier when cohorts are created
    pathToCsv <- system.file("settings", "CohortsToCreate.csv", package = "IUDEHRStudy")
    cohortsToCreate <- read.csv(pathToCsv)

    if (!validCohort(1771648, cohortCounts, minCellCount)) { #LNG-IUS
      ParallelLogger::logInfo("1771648 - LNG-IUS cohort count is too low (less than min cell count) to run study.")
    }
    if (!validCohort(1771647, cohortCounts, minCellCount)) { #Cu-IUD
      ParallelLogger::logInfo("1771647 - Cu-IUD cohort count is too low (less than min cell count) to run study.")
    }
    if (!validCohort(1771054, cohortCounts, minCellCount)) { #Alt High Grade Cervical Neoplasm
      ParallelLogger::logInfo("1771054 - Alt High Grade Cervical Neoplasm cohort count is too low (less than min cell count) to run study.")
    }

    #Continue study if T and O cohorts have a large enough cohort count
    if (validCohort(1771648, cohortCounts, minCellCount) &&
      validCohort(1771647, cohortCounts, minCellCount) &&
      validCohort(1771054, cohortCounts, minCellCount)) {
      if (runAnalyses) {
        ParallelLogger::logInfo("Running CohortMethod analyses")
        runCohortMethod(connectionDetails = connectionDetails,
                        cdmDatabaseSchema = cdmDatabaseSchema,
                        cohortDatabaseSchema = cohortDatabaseSchema,
                        cohortTable = cohortTable,
                        oracleTempSchema = oracleTempSchema,
                        outputFolder = outputFolder,
                        maxCores = maxCores)

        for (i in 1:nrow(cohortsToCreate)) {

          ParallelLogger::logInfo(paste("Running Cohort Characterization for", cohortsToCreate$name[i]))
          runCohortCharacterization(connectionDetails,
                                    cdmDatabaseSchema,
                                    cohortDatabaseSchema,
                                    cohortTable,
                                    oracleTempSchema,
                                    cohortsToCreate$cohortId[i],
                                    outputFolder, cohortsToCreate,
                                    cohortCounts, minCellCount)
        }

        ParallelLogger::logInfo("Calculating cumulative incidence for Cu...")
        #calculate cumulative incidence for Cu and LNG
        calculateCumulativeIncidence(connectionDetails,
                                     cohortDatabaseSchema,
                                     cdmDatabaseSchema,
                                     cohortTable,
                                     oracleTempSchema,
                                     1771647, #Cu-IUD
                                     1771054, #Alt High Grade Cervical Neoplasm
                                     outputFolder)

        ParallelLogger::logInfo("Calculating cumulative incidence for LNG...")
        calculateCumulativeIncidence(connectionDetails,
                                     cohortDatabaseSchema,
                                     cdmDatabaseSchema,
                                     cohortTable,
                                     oracleTempSchema,
                                     1771648, #LNG-IUS
                                     1771054, #Alt High Grade Cervical Neoplasm
                                     outputFolder)

        ParallelLogger::logInfo("Calculating cohort inclusion per year...")
        calculatePerYearCohortInclusion(connectionDetails,
                                        cohortDatabaseSchema,
                                        cohortTable,
                                        oracleTempSchema,
                                        outputFolder,
                                        minCellCount)

        ParallelLogger::logInfo("Create KM graphs...")
        createKMGraphs(outputFolder, cohortsToCreate)
      }

      if (runDiagnostics) {
        ParallelLogger::logInfo("Running diagnostics")
        generateDiagnostics(outputFolder = outputFolder,
                            maxCores = maxCores)
      }

      ParallelLogger::logInfo("Copying some additional analysis and diagnostic files to export...")
      copyAdditionalFilesToExportFolder(outputFolder,
                                        cohortCounts,
                                        minCellCount)

      if (packageResults) {
        ParallelLogger::logInfo("Packaging results")
        exportResults(outputFolder = outputFolder,
                      databaseId = databaseId,
                      databaseName = databaseName,
                      databaseDescription = databaseDescription,
                      minCellCount = minCellCount,
                      maxCores = maxCores)
      }
    }
  }
  invisible(NULL)
}

validCohort <- function(cohortId, cohortCounts, minCellCount) {

  index <- grep(cohortId, cohortCounts$cohortDefinitionId)
  return(length(index) != 0 && cohortCounts$personCount[index] > minCellCount)

}

initializeStudy <- function(outputFolder, connectionDetails, cohortDatabaseSchema, oracleTempSchema, package, reloadData = TRUE) {
  if (!file.exists(outputFolder))
    dir.create(outputFolder, recursive = TRUE)
  ParallelLogger::addDefaultFileLogger(file.path(outputFolder, "log.txt"))
  ParallelLogger::addDefaultErrorReportLogger(file.path(outputFolder, "errorReportR.txt"))

  if (reloadData) {
    #load CVX Groupings
    ParallelLogger::logInfo("Loading CVX Groupings")
    pathToCsv <- system.file("settings", "CvxGroups.txt", package = package)
    createAndLoadFileToTable(pathToCsv, sep = "|", connectionDetails, cohortDatabaseSchema, createTableFile = "CreateCVXGroupsTable.sql", tableName = "cvx_groups", oracleTempSchema, package)

    #load CVX to NDC Crosswalk
    ParallelLogger::logInfo("Loading CVX to NDC Crosswalk")
    pathToCsv <- system.file("settings", "CVXtoNDCCrosswalk.txt", package = package)
    createAndLoadFileToTable(pathToCsv, sep = "|", connectionDetails, cohortDatabaseSchema, createTableFile = "CreateCVXtoNDCTable.sql", tableName = "cvx_to_ndc_crosswalk", oracleTempSchema, package)
  }
}

createAndLoadFileToTable <- function(pathToCsv, sep = ",", connectionDetails, cohortDatabaseSchema, createTableFile, tableName, oracleTempSchema, package) {
  #Create table to load data
  connection <- DatabaseConnector::connect(connectionDetails)
  sql <- SqlRender::loadRenderTranslateSql(sqlFilename = createTableFile,
                                           packageName = package,
                                           dbms = attr(connection, "dbms"),
                                           tempEmulationSchema = oracleTempSchema,
                                           target_database_schema = cohortDatabaseSchema,
                                           table_name = tableName)
  DatabaseConnector::executeSql(connection, sql, progressBar = FALSE, reportOverallTime = FALSE)


  #Load data from csv file
  data <- read.csv(file = pathToCsv, sep = sep)
  #Construct the values to insert
  # paste0(apply(head(data), 1, function(x) paste0("('", paste0(x, collapse = "', '"), "')")), collapse = ", ")
  #batch load the rows
  chunk <- 1000
  n <- nrow(data)
  r <- rep(1:ceiling(n / chunk), each = chunk)[1:n]
  d <- split(data, r)

  for (i in d) {
    # values <- paste0("(", apply(apply(i, 1, function(x) ifelse(is.na(strtoi(x)), paste0("'", x,"'"), paste0(x))), 2, function(x) paste(x, collapse = ", ")), ")", collapse=",")
    values <-   paste0(apply(data, 1, function(x) paste0("('", paste0(x, collapse = "', '"), "')")), collapse = ", ")
    sql <- paste0("INSERT INTO @target_database_schema.@table_name VALUES ", values, ";")
    renderedSql <- SqlRender::render(sql = sql, target_database_schema = cohortDatabaseSchema, table_name = tableName)
    insertSql <- SqlRender::translate(renderedSql, targetDialect = attr(connection, "dbms"))
    DatabaseConnector::executeSql(connection, insertSql)
  }
  disconnect(connection)
}

