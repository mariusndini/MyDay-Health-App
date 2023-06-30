create or replace secure materialized view SNOWHEALTH.HK.FLIGHTSCLIMBED(
	ID,
	STARTTIME,
	ENDTIME,
	VALUE,
	UNIT,
	UUID,
	APP,
	DEVICE
) cluster by (ID, STARTTIME) as
select
distinct 
RECORD:identifier::STRING as ID,
PARSE_JSON(value):start_time::timestamp as starttime,
PARSE_JSON(value):end_time::timestamp as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:FlightsClimbed));