CREATE OR REPLACE SECURE MATERIALIZED VIEW SNOWHEALTH.HK.SODIUM (
    ID,
	VALUE,
	UNIT,
	UUID,
	APP,
	DEVICE,
	STARTTIME,
	ENDTIME,
	EXTERNALUUID,
	FOODIMAGENAME,
	FOODMEAL,
	FOODTYPE,
	FOODTYPEUUID,
	FOODUSDANUMBER

)
CLUSTER BY (ID, STARTTIME)
as
  select 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
PARSE_JSON(value):start_time::timestamp as starttime,
PARSE_JSON(value):end_time::timestamp as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietarySodium))
  ;
