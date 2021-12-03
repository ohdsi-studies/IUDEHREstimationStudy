{DEFAULT @table_name = "cvx_vaccine_groups"}

IF OBJECT_ID('@target_database_schema.@table_name', 'U') IS NOT NULL
DROP TABLE @target_database_schema.@table_name;

CREATE TABLE @target_database_schema.@table_name
(
	description varchar(500),
	cvx_code varchar(5),
	vaccine_status varchar(15),
	vaccine_group_name varchar(25),
	vaccine_group_code varchar(5)
)
