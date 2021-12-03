{DEFAULT @table_name = cvx_to_ndc_crosswalk}

IF OBJECT_ID('@target_database_schema.@table_name', 'U') IS NOT NULL
DROP TABLE @target_database_schema.@table_name;

CREATE TABLE @target_database_schema.@table_name
(
	sequence_number int,
	sale_ndc varchar(25),
	sale_ndc_clean varchar(25),
	proprietary_name varchar(100),
	sale_labeler varchar(100),
	start_date date,
	end_date date,
	sale_gtin varchar(100),
	sale_last_updated date,
	use_ndc varchar(25),
	no_use_ndc varchar(5),
	use_gtin varchar(100),
	use_last_updated date,
	cvx varchar(10),
	cvx_description varchar(200),
	mvx varchar(5)
)
