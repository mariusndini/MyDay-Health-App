create or replace task HEALTH_TABLES_PROCESS
warehouse=SNOWHEALTH_WH
WHEN
  SYSTEM$STREAM_HAS_DATA('HEALTH_STREAM')
schedule='1 minute'
as call SNOWHEALTH.HK.HEALTH_TABLES_SPROC();
