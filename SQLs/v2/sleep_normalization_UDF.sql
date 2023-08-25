/**
The below exists to normalize the sleep array. 
The way sleep is reported is on a time line. Meaning a user could be mid sleep cycle at the last minute of the hour
and that full time would count toward that hour. It makes charting dirty. 

An example of this is if a user started a DEEP (or any cycle) cycle at 3:59am that lasted for 20 minutes
it would be reported that at 3:59am for 20 minutes the User was in DEEP SLEEP. When you aggregate on our it would 
mean the user for 3AM slept for 79 minutes over a 60 minute hourly period. This fixes that issue.

 */

CREATE OR REPLACE FUNCTION SNOWHEALTH.PUBLIC.HANDLE_SLEEP(SLEEP ARRAY)
  RETURNS array
  LANGUAGE JAVASCRIPT
AS
$$
    if(SLEEP == null){
        return;
    }

    try{
        var data = [];
        var start = new Date(SLEEP[0].DATE)
        var end = new Date(SLEEP[SLEEP.length-1].DATE)
        var diff = (end - start)/ (1000 * 60)
    
        var c = 0;
        for(i = 0; i < SLEEP.length; i++){
            for (k=0; k < parseInt(SLEEP[i].val); k++){
                var item = {}
                item.count = c;
                item.cycle = SLEEP[i].cycle
                c = c +1;
                data.push(item)
                
            }
        }
    
        output = []
        hour = 0
        var agg = {REM:0, Core:0, Deep:0, awake:0}
        var counter = 1;
        
        for(i=0; i < data.length; i++){
            if(i%60 == 0){
                hour = hour +1
                output.push({DATE: new Date(new Date(start.getTime() + (i*60*1000)).setMinutes(0)), cycle:'REM', val:0 })
                output.push({DATE: new Date(new Date(start.getTime() + (i*60*1000)).setMinutes(0)), cycle:'Core', val:0 })
                output.push({DATE: new Date(new Date(start.getTime() + (i*60*1000)).setMinutes(0)), cycle:'Deep', val:0 })
                output.push({DATE: new Date(new Date(start.getTime() + (i*60*1000)).setMinutes(0)), cycle:'awake', val:0 })
                
            }
        }
    
        for(i=0; i < data.length; i++){
            for (k=0; k < output.length; k++){
                if(new Date(output[k].DATE).getTime() == new Date(new Date(start.getTime() + (data[i].count*60*1000)).setMinutes(0)).getTime() && data[i].cycle == output[k].cycle){
                    output[k].val = output[k].val+1;
                }
            }
        }
    
        return output;
    }catch(error){
        return;
    }
$$
;


select SNOWHEALTH.PUBLIC.HANDLE_SLEEP(SLEEP_ARR), sleep_arr
from snowhealth.hk.pop_agg




