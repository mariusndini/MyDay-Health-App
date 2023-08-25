SELECT SYSTEM$TASK_DEPENDENTS_ENABLE('snowhealth.HK.HEALTH_TABLES_PROCESS');
alter task snowhealth.HK.HEALTH_TABLES_PROCESS suspend;



create or replace task snowhealth.HK.HEALTH_TABLES_PROCESS
	warehouse=SNOWHEALTH_ETL
	schedule='1 minute'
	when SYSTEM$STREAM_HAS_DATA('SNOWHEALTH.HK.HEALTH_STREAM')
	as CREATE OR REPLACE STREAM SNOWHEALTH.HK.HEALTH_STREAM ON TABLE SNOWHEALTH.PUBLIC.HEALTHKIT_IMPORT;


create or replace task SNOWHEALTH.HK.CREATE_HEALTH_DATE_DIM
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS

	as CREATE OR REPLACE TABLE HK.DATE_DIM (
         DATE             DATE        NOT NULL
        ,YEAR             SMALLINT    NOT NULL
        ,MONTH            SMALLINT    NOT NULL
        ,MONTH_NAME       CHAR(3)     NOT NULL
        ,DAY_OF_MON       SMALLINT    NOT NULL
        ,DAY_OF_WEEK      VARCHAR(9)  NOT NULL
        ,WEEK_OF_YEAR     SMALLINT    NOT NULL
        ,DAY_OF_YEAR      SMALLINT    NOT NULL
      )
      AS
        WITH CTE_MY_DATE AS (
          SELECT DATEADD(DAY, SEQ4(), '2020-01-01') AS MY_DATE
            FROM TABLE(GENERATOR(ROWCOUNT => 366 * 5))  -- Count starts from Jan 1 2019 + 5 years by day
        )
        SELECT MY_DATE
              ,YEAR(MY_DATE)
              ,MONTH(MY_DATE)
              ,MONTHNAME(MY_DATE)
              ,DAY(MY_DATE)
              ,DAYOFWEEK(MY_DATE) + 1
              ,WEEKOFYEAR(MY_DATE)
              ,DAYOFYEAR(MY_DATE)
          FROM CTE_MY_DATE;







create or replace task SNOWHEALTH.HK.CREATE_HEALTH_HOUR_DIM
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS
	as 
    CREATE OR REPLACE TABLE HK.HOUR_DIM (
         DATE             DATETIME    NOT NULL
        ,YEAR             SMALLINT    NOT NULL
        ,MONTH            SMALLINT    NOT NULL
        ,MONTH_NAME       CHAR(3)     NOT NULL
        ,DAY_OF_MON       SMALLINT    NOT NULL
        ,HOUR             SMALLINT    NOT NULL
        ,DAY_OF_WEEK      VARCHAR(9)  NOT NULL
        ,WEEK_OF_YEAR     SMALLINT    NOT NULL
        ,DAY_OF_YEAR      SMALLINT    NOT NULL
      )
      AS
        WITH CTE_MY_HOURS AS (
          SELECT DATEADD(HOUR, SEQ4(), '2020-01-01 00') AS MY_DATE
            FROM TABLE(GENERATOR(ROWCOUNT => (366*5) * 24))  -- Count starts from Jan 1 2019 + 5 years by day by hour
        )
        SELECT MY_DATE
              ,YEAR(MY_DATE)
              ,MONTH(MY_DATE)
              ,MONTHNAME(MY_DATE)
              ,DAY(MY_DATE)
              ,EXTRACT(HOUR FROM MY_DATE)
              ,DAYOFWEEK(MY_DATE) + 1
              ,WEEKOFYEAR(MY_DATE)
              ,DAYOFYEAR(MY_DATE)
          FROM CTE_MY_HOURS;



create or replace task SNOWHEALTH.HK.CREATE_POPULATION
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS
	as 

CREATE OR REPLACE TABLE HK.POPULATION AS(
          select 
            RECORD:identifier::STRING as ID,
            RECORD:age::INT as AGE,
            RECORD:bloodstype::STRING as BLOODTYPE,
            RECORD:gender::STRING as GENDER,
            RECORD:loaddate::TIMESTAMP AS LOADTIME
          FROM "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT" HKI
          INNER JOIN 
            (select 
                RECORD:identifier::STRING  AS ID, 
                MAX(RECORD:loaddate)::TIMESTAMP AS LOADTIME
            from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT"
            group by 1) U ON ID = U.ID AND RECORD:loaddate = U.LOADTIME 
          group by 1, 2, 3, 4, 5
        );



create or replace task SNOWHEALTH.HK.CREATE_DATED_POPULATION
	warehouse=SNOWHEALTH_ETL
    AFTER SNOWHEALTH.HK.CREATE_POPULATION, SNOWHEALTH.HK.CREATE_HEALTH_DATE_DIM
	as 
CREATE OR REPLACE TABLE HK.DATED_POP AS (
          select  ID, DATE
          FROM "SNOWHEALTH"."HK"."POPULATION",
               "SNOWHEALTH"."HK"."DATE_DIM"
          group by 1, 2
          order by id, date
        );



create or replace task SNOWHEALTH.HK.CREATE_HOUR_POPULATION
	warehouse=SNOWHEALTH_ETL
    AFTER SNOWHEALTH.HK.CREATE_POPULATION, SNOWHEALTH.HK.CREATE_HEALTH_HOUR_DIM
	as 
CREATE OR REPLACE TABLE HK.HOURS_POP AS (
          select  ID, DATE
          FROM "SNOWHEALTH"."HK"."POPULATION",
              "SNOWHEALTH"."HK"."HOUR_DIM"
          group by 1, 2
          order by id, date
        );


create or replace task SNOWHEALTH.HK.CREATE_ACTIVE_ENERGY_BURNED
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.ACTIVE_ENERGY_BURNED(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:ActiveEnergyBurned));



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_APPLESTANDTIME
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.APPLESTANDTIME(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:AppleStandTime));



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_BASALENERGYBURNED
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.BASALENERGYBURNED(
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
        table(flatten(input => RECORD:BasalEnergyBurned));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_BODY_MASS
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.BODYMASS(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
NULL as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:BodyMass))
        ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_CARBS
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.CARBS(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryCarbohydrates))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_CHOLESTEROL
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.CHOLESTEROL(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryCholesterol))
  ;



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_DIETARYENERGY
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.DIETARYENERGY(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryEnergyConsumed))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_ENVIRONMENTAUDIO
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.ENVIRONMENTAUDIO(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:EnvironmentalAudioExposure));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_EXERCISETIME
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.EXERCISETIME(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:AppleExerciseTime));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_FATMONO
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.FATMONO(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryFatMonounsaturated))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_FATPOLY
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.FATPOLY(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryFatPolyunsaturated))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_FATSAT
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.FATSAT(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryFatSaturated))
  ;



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_FATTOTAL
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.FATTOTAL(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryFatTotal))
  ;



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_FLIGHTSCLIMBED
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.FLIGHTSCLIMBED(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:FlightsClimbed));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_HEAPHONEAUDIO
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
CREATE OR REPLACE TABLE HK.HEAPHONEAUDIO(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:HeadphoneAudioExposure));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_HEARTRATE
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.HEARTRATE(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
CASE
    WHEN PARSE_JSON(value):unit::string='count/s' THEN PARSE_JSON(value):value::double * 60
    ELSE PARSE_JSON(value):value::double
END as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:HeartRate));

--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_HEARTRATESDNN
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.HEARTRATESDNN(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:HeartRateVariabilitySDNN));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_PROTEIN
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.PROTEIN(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietaryProtein))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_RESTINGHEARTRATE
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.RESTINGHEARTRATE(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:RestingHeartRate));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_SLEEP
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.SLEEP(
	ID,
	STARTTIME,
	ENDTIME,
	VALUE,
	UNIT,
	UUID,
	APP,
	DEVICE,
	CYCLE,
	MINS
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
end AS CYCLE,
timediff(minute, starttime, endtime) AS MINS

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:SleepAnalysis))
where DEVICE ILIKE 'Watch%' ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_SODIUM
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.SODIUM(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietarySodium))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_STEPCOUNT
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.STEPCOUNT(
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
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE

  from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:StepCount));


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_SUGAR
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.SUGAR(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DietarySugar))
  ;



--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_WALKINGHEARTAVG
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.WALKINGHEARTAVG(
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
) cluster by (ID, STARTTIME) as
  select 
distinct 
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:WalkingHeartRateAverage))
  ;


--------------------------------------------------------------------------------------------
create or replace task SNOWHEALTH.HK.CREATE_WALKRUNDISTANCE
	warehouse=SNOWHEALTH_ETL
    AFTER snowhealth.HK.HEALTH_TABLES_PROCESS as
create or replace TABLE HK.WALKRUNDISTANCE(
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
) cluster by (ID, STARTTIME) as
  select 
distinct
RECORD:identifier::string as ID,
PARSE_JSON(value):value::double as VALUE,
PARSE_JSON(value):unit::string as UNIT,
PARSE_JSON(value):uuid::string as UUID,
NULL AS APP,
PARSE_JSON(value):source::string as DEVICE,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):start_time::timestamp) as starttime,
convert_timezone('UTC', 'America/New_York', PARSE_JSON(value):end_time::timestamp) as endtime,
NULL as EXTERNALUUID,
PARSE_JSON(value):metadata:foodImageName::string as FOODIMAGENAME,
PARSE_JSON(value):metadata:foodType::string as FOODTYPE,
PARSE_JSON(value):metadata:USDANumber::string as FOODUSDANUMBER,
null as FOODTYPEUUID,
PARSE_JSON(value):metadata:meal::string as FOODMEAL

from "SNOWHEALTH"."PUBLIC"."HEALTHKIT_IMPORT",
        table(flatten(input => RECORD:DistanceWalkingRunning))
  ;



create or replace task SNOWHEALTH.HK.CREATE_POP_AGG
	warehouse=SNOWHEALTH_ETL
    AFTER 
    SNOWHEALTH.HK.CREATE_DATED_POPULATION,
    HK.CREATE_ACTIVE_ENERGY_BURNED,
    HK.CREATE_APPLESTANDTIME,
    HK.CREATE_BASALENERGYBURNED,
    HK.CREATE_CARBS,
    HK.CREATE_CHOLESTEROL,
    HK.CREATE_POPULATION,
    HK.CREATE_DIETARYENERGY,
    HK.CREATE_ENVIRONMENTAUDIO,
    HK.CREATE_EXERCISETIME,
    HK.CREATE_FATMONO,
    HK.CREATE_FATPOLY,
    HK.CREATE_FATSAT,
    HK.CREATE_FATTOTAL,
    HK.CREATE_FLIGHTSCLIMBED,
    HK.CREATE_HEALTH_DATE_DIM,
    HK.CREATE_HEALTH_HOUR_DIM,
    HK.CREATE_HEAPHONEAUDIO,
    HK.CREATE_HEARTRATE,
    HK.CREATE_HEARTRATESDNN,
    HK.CREATE_POPULATION,
    HK.CREATE_PROTEIN,
    HK.CREATE_RESTINGHEARTRATE,
    HK.CREATE_SLEEP,
    HK.CREATE_SODIUM,
    HK.CREATE_STEPCOUNT,
    HK.CREATE_SUGAR,
    HK.CREATE_WALKINGHEARTAVG,
    HK.CREATE_WALKRUNDISTANCE
	
    
    as 

create or replace table HK.POP_AGG2 AS (
        select DISTINCT
          DP.ID
          ,DP.DATE
          ,POP.AGE AS AGE
          ,POP.BLOODTYPE AS BLOODTYPE
          ,POP.GENDER AS GENDER
          ,AEB.VALUE as ACTIVE_ENERGY_BURNED
          ,AST.VALUE AS APPLE_STAND_TIME
          ,BEB.VALUE AS BASAL_ENERGY_BURNED
          ,CARBS.VALUE AS CARBS
          ,CSTRL.VALUE AS CHOLESTEROL
          ,DE.VALUE as DIETARY_ENERGY
          ,FM.VALUE AS FATMONO
          ,FP.VALUE AS FATPOLY
          ,FS.VALUE AS FATSAT
          ,FT.VALUE AS FATTOTAL
          ,FC.VALUE AS FLIGHTSCLIMBED
          ,PRO.VALUE AS PROTEIN
          ,SOD.VALUE AS SODIUM
          ,STEPS.VALUE AS STEPS
          ,SUG.VALUE AS SUGAR
          ,WRD.VALUE AS WALK_RUN
          ,ET.VALUE AS EXERCISE_TIME
          ,BDM.VALUE AS BODYMASS
          ,SLP.SLEEP

          ,HRTRT.DATA AS HEART_RATE_ARR
          ,RHRTRT.DATA AS REST_HEART_RATE_ARR
          ,SDNNHRTRT.DATA AS SDNN_HEART_RATE_ARR
          ,WHRTRT.DATA AS WALK_HEART_RATE_ARR
          ,TAST.DATA AS STAND_TIME_ARR
          ,ENAUDIO.DATA AS ENVIRONMENT_AUDIO_ARR
          ,HPAUDIO.DATA AS HEADPHONE_AUDIO_ARR
          ,FCDETAIL.DATA AS FLIGHTS_ARR
          ,WRDIST.DATA AS WALK_RUN_ARR
          ,STEPSDET.DATA AS STEPS_ARR
          ,AEBDET.DATA AS ACTIVE_ENERGY_ARR
          ,BASALDET.DATA AS BASAL_ARR
          ,WEEK_HIST.DATA AS WEEK_CALS_ARR
          ,TET.DATA AS EXERCISE_TIME_ARR
          ,SLEEP.DATA AS SLEEP_ARR

          ,current_timestamp as RUN_DATE
        
          from "SNOWHEALTH"."HK"."DATED_POP" DP 
              LEFT JOIN "SNOWHEALTH"."HK"."POPULATION" POP ON DP.ID = POP.ID
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."ACTIVE_ENERGY_BURNED" group by 1,2,4) AEB ON DP.ID = AEB.ID AND DP.DATE = AEB.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."APPLESTANDTIME" group by 1,2,4) AST ON DP.ID = AST.ID AND DP.DATE = AST.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."EXERCISETIME" group by 1,2,4) ET ON DP.ID = ET.ID AND DP.DATE = ET.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."BASALENERGYBURNED" group by 1,2,4) BEB ON DP.ID = BEB.ID AND DP.DATE = BEB.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."CARBS" group by 1,2,4) CARBS ON DP.ID = CARBS.ID AND DP.DATE = CARBS.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."CHOLESTEROL" group by 1,2,4) CSTRL ON DP.ID = CSTRL.ID AND DP.DATE = CSTRL.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."DIETARYENERGY" group by 1,2,4) DE ON DP.ID = DE.ID AND DP.DATE = DE.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."FATMONO" group by 1,2,4) FM ON DP.ID = FM.ID AND DP.DATE = FM.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."FATPOLY" group by 1,2,4) FP ON DP.ID = FP.ID AND DP.DATE = FP.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."FATSAT" group by 1,2,4) FS ON DP.ID = FS.ID AND DP.DATE = FS.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."FATTOTAL" group by 1,2,4) FT ON DP.ID = FT.ID AND DP.DATE = FT.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."FLIGHTSCLIMBED" group by 1,2,4) FC ON DP.ID = FC.ID AND DP.DATE = FC.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."PROTEIN" group by 1,2,4) PRO ON DP.ID = PRO.ID AND DP.DATE = PRO.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."SODIUM" group by 1,2,4) SOD ON DP.ID = SOD.ID AND DP.DATE = SOD.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."STEPCOUNT" group by 1,2,4) STEPS ON DP.ID = STEPS.ID AND DP.DATE = STEPS.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."SUGAR" group by 1,2,4) SUG ON DP.ID = SUG.ID AND DP.DATE = SUG.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."WALKRUNDISTANCE" group by 1,2,4) WRD ON DP.ID = WRD.ID AND DP.DATE = WRD.DATE
              LEFT JOIN (SELECT ID, DATE_TRUNC('DAY', STARTTIME) AS DATE, sum(VALUE) as VALUE, UNIT FROM "SNOWHEALTH"."HK"."BODYMASS" group by 1,2,4) BDM ON DP.ID = BDM.ID AND DP.DATE = BDM.DATE
              LEFT JOIN (select ID, DATE_TRUNC('DAY', DATEADD(HOUR, 6,STARTTIME)) AS DATE, sum(mins) as sleep
                            from SNOWHEALTH.HK.SLEEP
                            where value in (3,4,5) 
                            group by 1, 2) SLP ON DP.ID = SLP.ID AND DP.DATE = SLP.DATE

              
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::STRING||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select distinct B.ID AS ID, B.DATE AS STARTTIME, IFF((VALUE is not null), value::STRING,'') as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."HEARTRATE" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                          ) group by ID, date_trunc('day',STARTTIME)) HRTRT ON HRTRT.ID=DP.ID AND HRTRT.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select ID, STARTTIME, VALUE from "SNOWHEALTH"."HK"."RESTINGHEARTRATE")
                          group by ID, date_trunc('day',STARTTIME) ) RHRTRT ON RHRTRT.ID=DP.ID AND RHRTRT.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select ID, STARTTIME, VALUE from "SNOWHEALTH"."HK"."HEARTRATESDNN")
                          group by ID, date_trunc('day',STARTTIME) ) SDNNHRTRT ON SDNNHRTRT.ID=DP.ID AND SDNNHRTRT.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select ID, STARTTIME, VALUE from "SNOWHEALTH"."HK"."WALKINGHEARTAVG")
                          group by ID, date_trunc('day',STARTTIME) ) WHRTRT ON WHRTRT.ID=DP.ID AND WHRTRT.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."APPLESTANDTIME" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME)) TAST ON TAST.ID=DP.ID AND TAST.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select ID, STARTTIME, VALUE from "SNOWHEALTH"."HK"."ENVIRONMENTAUDIO")
                          group by ID, date_trunc('day',STARTTIME) ) ENAUDIO ON ENAUDIO.ID=DP.ID AND ENAUDIO.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select ID, STARTTIME, VALUE from "SNOWHEALTH"."HK"."HEAPHONEAUDIO")
                          group by ID, date_trunc('day',STARTTIME) ) HPAUDIO ON HPAUDIO.ID=DP.ID AND HPAUDIO.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."FLIGHTSCLIMBED" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME) ) FCDETAIL ON FCDETAIL.ID=DP.ID AND FCDETAIL.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."WALKRUNDISTANCE" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME) ) WRDIST ON WRDIST.ID=DP.ID AND WRDIST.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."STEPCOUNT" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME)) STEPSDET ON STEPSDET.ID=DP.ID AND STEPSDET.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."ACTIVE_ENERGY_BURNED" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME) ) AEBDET ON AEBDET.ID=DP.ID AND AEBDET.DATE = DP.DATE
              LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                          from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."BASALENERGYBURNED" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                GROUP BY 1, 2 
                          ) group by ID, date_trunc('day',STARTTIME) ) BASALDET ON BASALDET.ID=DP.ID AND BASALDET.DATE = DP.DATE

                LEFT JOIN (select ID, date_trunc('day',STARTTIME) AS DATE, ARRAY_AGG(PARSE_JSON('{"DATE":"'||STARTTIME::TIMESTAMP ||'", "val":"'|| VALUE::DOUBLE||'"}')) within group (order by starttime::TIMESTAMP ASC) AS DATA
                            from (select B.ID AS ID, B.DATE AS STARTTIME, NVL(SUM(VALUE),0) as VALUE
                                    FROM "SNOWHEALTH"."HK"."HOURS_POP" B LEFT OUTER JOIN  "SNOWHEALTH"."HK"."EXERCISETIME" A ON A.ID = B.ID AND DATE_TRUNC('HOUR',A.STARTTIME) = B.DATE
                                  GROUP BY 1, 2 
                            ) group by ID, date_trunc('day',STARTTIME)) TET ON TET.ID=DP.ID AND TET.DATE = DP.DATE

                LEFT JOIN(select ID, date_trunc('day',STARTTIME) AS DATE, 
                            ARRAY_AGG(PARSE_JSON('{"DATE":"'||DATEADD(HOUR, -6,STARTTIME::TIMESTAMP) ||'", "val":'|| SLEEP::DOUBLE||',"cycle":"'||CYCLE||'"}')) 
                            within group (order by starttime::TIMESTAMP ASC) AS DATA
                            from (
                                select ID, DATE_TRUNC('minute', DATEADD(HOUR, 6,STARTTIME)) AS STARTTIME, sum(mins) as SLEEP, cycle
                                from SNOWHEALTH.HK.SLEEP
                                where value != 0
                                group by 1, 2, 4
                            ) 
                            group by ID, date_trunc('day',STARTTIME)
                            order by date desc) SLEEP ON SLEEP.ID=DP.ID AND SLEEP.DATE = DP.DATE
            
            
            -- ADD WEEKLY HISTORY
            LEFT JOIN(
                select DP.ID AS ID, DP.DATE AS T,
                    ARRAY_AGG(PARSE_JSON('{"DATE":"'||TIME::TIMESTAMP ||'", "ACTIVE":"'|| CONSUMED::DOUBLE||'", "BASAL":"'|| ACTIVE_ENERGY::DOUBLE||'", "CONSUMED":"'|| BASAL_ENERGY::DOUBLE||'"}')) within group (order by TIME::TIMESTAMP ASC) AS DATA
                from SNOWHEALTH.HK.DATED_POP DP
                join SNOWHEALTH.DAILY_AGG.DAILY_ENERGY_CALS DEC on DP.ID=DEC.ID
                where TIME BETWEEN (DP.date-9) AND (DP.DATE)
                GROUP BY 1, 2
                order by 1, 2 desc
            ) WEEK_HIST ON WEEK_HIST.ID = DP.ID AND WEEK_HIST.T=DP.DATE 


        order by 1 asc, 2 asc
      );





create or replace task SNOWHEALTH.HK.SWAP_POP_AGG
	warehouse=SNOWHEALTH_ETL
    AFTER SNOWHEALTH.HK.CREATE_POP_AGG 
    as
    ALTER TABLE HK.POP_AGG SWAP WITH HK.POP_AGG2;



    
create or replace task SNOWHEALTH.HK.GRANT_ACCESS
	-- warehouse=SNOWHEALTH_ETL
    AFTER SNOWHEALTH.HK.CREATE_POP_AGG 
    as
    GRANT SELECT ON ALL TABLES IN SCHEMA SNOWHEALTH.HK TO ROLE HEALTHKITSERVICE;




create or replace task SNOWHEALTH.HK.SHARE_DATA
	-- warehouse=SNOWHEALTH_ETL
    AFTER SNOWHEALTH.HK.CREATE_POP_AGG 
    as
    CALL SNOWHEALTH.HK.SHARE_DATA_SCRIPT();



CREATE OR REPLACE PROCEDURE SNOWHEALTH.HK.SHARE_DATA_SCRIPT()
RETURNS VARCHAR
LANGUAGE JAVASCRIPT
EXECUTE AS OWNER
AS   $$
      rs = snowflake.execute( { sqlText: `GRANT USAGE ON SCHEMA "SNOWHEALTH"."HK" TO ROLE HEALTHKITSERVICE;`} );
      rs = snowflake.execute( { sqlText: `grant select on all tables in schema SNOWHEALTH.HK to role HEALTHKITSERVICE;`} );

      rs = snowflake.execute( { sqlText: `GRANT USAGE ON DATABASE "SNOWHEALTH" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT USAGE ON SCHEMA "SNOWHEALTH"."HK" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."ACTIVE_ENERGY_BURNED" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."WALKRUNDISTANCE" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."WALKINGHEARTAVG" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."SUGAR" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."STEPCOUNT" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."SODIUM" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."RESTINGHEARTRATE" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."PROTEIN" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."POP_AGG" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."POPULATION" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."HOUR_DIM" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."HOURS_POP" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."HEARTRATESDNN" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."HEARTRATE" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."HEAPHONEAUDIO" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."FLIGHTSCLIMBED" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."FATTOTAL" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."FATSAT" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."FATPOLY" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."FATMONO" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."ENVIRONMENTAUDIO" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."DIETARYENERGY" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."DATE_DIM" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."DATED_POP" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."CHOLESTEROL" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."CARBS" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."BASALENERGYBURNED" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."APPLESTANDTIME" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."EXERCISETIME" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."SLEEP" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."BODYMASS" TO SHARE "HEALTH_DATASHARE";`} );
      
      // ADD TO SHARE TO SNOWHEALTH ACCOUNT
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."POPULATION" TO SHARE "HEALTH_DATASHARE";`} );
      rs = snowflake.execute( { sqlText: `GRANT SELECT ON TABLE "SNOWHEALTH"."HK"."POP_AGG" TO SHARE "HEALTH_DATASHARE";`} );

      rs = snowflake.execute( { sqlText: `GRANT USAGE ON SCHEMA "SNOWHEALTH"."PUBLIC" TO SHARE "HEALTH_DATASHARE";`} );      
      rs = snowflake.execute( { sqlText: `insert into SNOWHEALTH.PUBLIC.TRIGGER_UPDATE (SELECT CURRENT_TIMESTAMP());`} );
      rs = snowflake.execute( { sqlText: `alter table SNOWHEALTH.PUBLIC.TRIGGER_UPDATE set change_tracking = true;`} );

      return 'Done';
      $$;


create or replace pipe SNOWHEALTH.PUBLIC.HEALTH_PIPE auto_ingest=true as 
copy into SNOWHEALTH.PUBLIC.HEALTHKIT_IMPORT
    from @SNOWHEALTH.PUBLIC.SNOWHEALTHS3
    FILE_FORMAT = (TYPE = JSON);

