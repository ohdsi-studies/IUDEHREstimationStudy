Relative Risk of Cervical Neoplasms Associated with Copper and Levonorgestrel Secreting Intrauterine Devices: Real World Evidence from the OHDSI Network
==============================

<img src="https://img.shields.io/badge/Study%20Status-Design%20Finalized-brightgreen.svg" alt="Study Status: Design Finalized"> 

- Analytics use case(s): **Characterization** and **Population-Level Estimation**
- Study type: **Clinical Application**
- Tags: **iud**
- Study lead: **Matthew Spotnitz** and **Karthik Natarajan**
- Study lead forums tag: **[mattspotnitz](https://forums.ohdsi.org/u/mattspotnitz)**
- Study start date: **September 23, 2019**
- Study end date: **-**
- Protocol: **[Word file](https://github.com/ohdsi-studies/IUDEHREstimationStudy/blob/master/documents/IUD%20Cervical%20Neoplasms%20Estimation%20Protocol.docx)**
- Publications: **-**
- Results explorer: **-**

This study extends the [prior single-site study](https://journals.lww.com/greenjournal/fulltext/2020/02000/relative_risk_of_cervical_neoplasms_among_copper.11.aspx) to the OHDSI network.


Requirements
============

- A database in [Common Data Model version 5](https://github.com/OHDSI/CommonDataModel) in one of these platforms: SQL Server, Oracle, PostgreSQL, IBM Netezza, Apache Impala, Amazon RedShift, Google BigQuery, or Microsoft APS.
- R version 3.5.0 or newer
- On Windows: [RTools](http://cran.r-project.org/bin/windows/Rtools/)
- [Java](http://java.com)
- 25 GB of free disk space

If you have access to a claims data set please also run this study on it, which is described in the "Run Study on Claims Data" section below

How to run
==========
1. Follow [these instructions](https://ohdsi.github.io/Hades/rSetup.html) for setting up your R environment, including RTools and Java. 

2. Open your study package in RStudio. Use the following code to install all the dependencies:

	```r
	renv::restore()
	```

3. In RStudio, select 'Build' then 'Install and Restart' to build the package.

4. Once installed, you can execute the study by modifying and using the code below. For your convenience, this code is also provided under `extras/CodeToRun.R`:

   ```r
   library(IUDStudy)
   # Optional: specify where the temporary files (used by the Andromeda package) will be created:
   options(andromedaTempFolder = "c:/andromedaTemp")
	
   # Maximum number of cores to be used:
	maxCores <- parallel::detectCores()
	
   # Minimum cell count when exporting data:
	minCellCount <- 5
	
   # The folder where the study intermediate and result files will be written:
	outputFolder <- "c:/IUDStudy"

   # Boolean to indicate if data is claims vs ehr False for this case
   isClaimsData <- FALSE
	
   # Details for connecting to the server:
   # See ?DatabaseConnector::createConnectionDetails for help
   connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
									server = "some.server.com/ohdsi",
									user = "joe",
									password = "secret")
	
   # The name of the database schema where the CDM data can be found:
   cdmDatabaseSchema <- "cdm_synpuf"
	
   # The name of the database schema and table where the study-specific cohorts will be instantiated:
   cohortDatabaseSchema <- "scratch.dbo"
   cohortTable <- "my_study_cohorts"
	
   # Some meta-information that will be used by the export function:
   databaseId <- "Synpuf"
   databaseName <- "Medicare Claims Synthetic Public Use Files (SynPUFs)"
   databaseDescription <- "Medicare Claims Synthetic Public Use Files (SynPUFs) were created to allow interested parties to gain familiarity using Medicare claims data while protecting beneficiary privacy. These files are intended to promote development of software and applications that utilize files in this format, train researchers on the use and complexities of Centers for Medicare and Medicaid Services (CMS) claims, and support safe data mining innovations. The SynPUFs were created by combining randomized information from multiple unique beneficiaries and changing variable values. This randomization and combining of beneficiary information ensures privacy of health information."
	
   # For Oracle: define a schema that can be used to emulate temp tables:
   oracleTempSchema <- NULL
	
   execute(connectionDetails = connectionDetails,
            cdmDatabaseSchema = cdmDatabaseSchema,
            cohortDatabaseSchema = cohortDatabaseSchema,
            cohortTable = cohortTable,
            oracleTempSchema = oracleTempSchema,
            outputFolder = outputFolder,
            databaseId = databaseId,
            databaseName = databaseName,
            databaseDescription = databaseDescription,
            createCohorts = TRUE,
            synthesizePositiveControls = TRUE,
            runAnalyses = TRUE,
            runDiagnostics = TRUE,
            packageResults = TRUE,
            maxCores = maxCores,
            isClaimsData = FALSE)
	```

4. Upload the file ```export/Results_<DatabaseId>.zip``` in the output folder to the study coordinator:

	```r
	uploadResults(outputFolder, privateKeyFileName = "<file>", userName = "<name>")
	```
	
	Where ```<file>``` and ```<name>``` are the credentials provided to you personally by the study coordinator.
		
5. To view the results, use the Shiny app:

	```r
	prepareForEvidenceExplorer("Result_<databaseId>.zip", "/shinyData")
	launchEvidenceExplorer("/shinyData", blind = TRUE)
	```
  
  Note that you can save plots from within the Shiny app. It is possible to view results from more than one database by applying `prepareForEvidenceExplorer` to the Results file from each database, and using the same data folder. Set `blind = FALSE` if you wish to be unblinded to the final results.



How to run for Claims Data
==========================

As mentioned above, if you have access to a claims data follow the below instructions to run an additional analysis.

```r
devtools::install_github("https://github.com/ohdsi-studies/IUDEHREstimationStudy/additionalEstimationPackage/IUDClaimsEstimation")
library(IUDClaimsStudy)

# Optional: specify where the temporary files (used by the ff package) will be created:
options(andromedaTempFolder = "c:/andromedaTemp")

# Maximum number of cores to be used:
maxCores <- parallel::detectCores()

# Minimum cell count when exporting data:
minCellCount <- 10

 # Boolean to indicate if data is claims vs ehr TRUE for this case
isClaimsData <- TRUE

# The folder where the study intermediate and result files will be written:
outputFolder <- paste0(outputFolder,"/IUDClaimsStudy") #If running this analysis in isolation (i.e. without EHR analysis) please enter the file directory here (i.e. "C:/IUDClaimsStudy")

# Details for connecting to the server:
# See ?DatabaseConnector::createConnectionDetails for help
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
                                server = "some.server.com/ohdsi",
                                user = "",
                                password = "")

# The name of the database schema where the CDM data can be found:
cdmDatabaseSchema <- "cdm_synpuf"

# The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema <- "scratch.dbo" #You mush have rights to create tables in this schema
cohortTable <- "iud_study_claims"

# Some meta-information that will be used by the export function:
databaseId <- ""          #SiteName
databaseName <- ""        #SiteName_DatabaseName
databaseDescription <- "" #Description of site's database

# For Oracle: define a schema that can be used to emulate temp tables:
oracleTempSchema <- NULL

IUDClaimsStudy::execute(connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTable,
        oracleTempSchema = oracleTempSchema,
        outputFolder = outputFolder,
        databaseId = databaseId,
        databaseName = databaseName,
        databaseDescription = databaseDescription,
        createCohorts = TRUE,
        synthesizePositiveControls = TRUE,
        runAnalyses = TRUE,
        runDiagnostics = TRUE,
        packageResults = TRUE,
        maxCores = maxCores,
        isClaimsData = TRUE)
```


Development
===========
IUDStudy was developed in ATLAS and R Studio. The package was modified to include additional analyses from the initial Atlas package. All additional analyses and code are located in the _AdditionalAnalysis.R_ file. The following are the additional analyses and modifications:
1. Calculates counts to additional cohorts for sensitivity analysis
2. Calculates the cumulative incidence of the cohorts
3. Calculates the yearly distribution of all cohorts
4. Creates KM graphs for the cohorts of interest
5. Copies all diagnostic graphs in the diagnostic folder to the export folder 
6. All cohort counts and distributions are filtered based on minimum cell count

License
=======
The IUDStudy package is licensed under Apache License 2.0
