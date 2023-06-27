create or replace secure materialized view SNOWHEALTH.HK.SLEEP(
	ID,
	STARTTIME,
	ENDTIME,
	VALUE,
	UNIT,
	UUID,
	APP,
	DEVICE,
    CYCLE
) cluster by (ID, STARTTIME) as
select
distinct 
RECORD:identifier::STRING as ID,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::integer as VALUE,
'Sleep' as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
CASE 
when PARSE_JSON(value):value::integer = 0 then 'InBed'
when PARSE_JSON(value):value::integer = 1 then 'Unknown' //asleepUnspecified
when PARSE_JSON(value):value::integer = 2 then 'awake'
when PARSE_JSON(value):value::integer = 3 then 'Core'
when PARSE_JSON(value):value::integer = 4 then 'Deep'
when PARSE_JSON(value):value::integer = 5 then 'REM'
end AS CYCLE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:SleepAnalysis))
where DEVICE ILIKE 'Watch%' 

        ;