# Import python packages
import streamlit as st
from snowflake.snowpark.context import get_active_session
from datetime import datetime, timedelta
import numpy as np
import altair as alt
import pandas as pd
session = get_active_session()  
st.set_page_config(layout="centered")



# ASK CHAT GPT A QUESTION
def ask_chatGPT(prompt):
    gpt_data = session.sql(f"""select CORE.GPT('{prompt}')""").to_pandas()
    output = str( gpt_data.iloc[0,0] ).replace("\\n", "\n")[1:-1]
    return f"""{output}""" 



st.sidebar.header("MyDay Health")
pin = st.sidebar.text_input("User Pin", value='SNOW', key='pin')
start_date =st.sidebar.date_input(key="start_date", label="Start Date", value=datetime.today() - timedelta(days=7))
end_date = st.sidebar.date_input(key="end_date", label="End Date", value=datetime.today())

st.header("Key Health Insights and Trends")
# st.markdown(f"""#### {start_date} and {end_date}""")

agg = session.sql(f""" SELECT *
                       FROM HK.POP_AGG 
                       WHERE ID ='{pin}' 
                       and DATE between '{start_date}' and '{end_date}' 
                       order by DATE asc""").to_pandas()



age = int(agg.iloc[:1]['AGE'].values)
gender = agg.iloc[:1]['GENDER'][0]
weight = int(agg['BODYMASS'].mean())
exercise_mins = int(agg['EXERCISE_TIME'].mean())
sleep = (agg['SLEEP'].mean()/60).round(2)
cals_consumed = int(agg['DIETARY_ENERGY'].mean())
cals_burned = int((agg['ACTIVE_ENERGY_BURNED']+agg['BASAL_ENERGY_BURNED']).mean())

st.markdown(f"""**{pin}**, {age} year old {gender}. {agg.iloc[:1]['BLOODTYPE'][0]} Bloodtype """)



st.header("General Trends & Averages")
chatPrompt = f'''
    you are a health advisor to a {age} year old {gender}. 
    This {gender} weighs {weight} pounds and has exercised an average of {exercise_mins} mins per day
    between {start_date} and {end_date}. This person has slept {sleep} hours on average a night.

    This person on average consumed {cals_consumed} cals and burned a total of {cals_burned} cals.
    
    Please give your opinion,advise and changes would you suggest in 1 paragraph under 4 sentences?
    Please keep it very short and concise.
    Address the user directly in the second person. 
    
'''
st.markdown(f'{ask_chatGPT(chatPrompt)} **:red[Opinion provided by ChatGPT]**')


g1, g2, g3, g4, g5 = st.columns(5)
g1.metric("Weight (lbs)", weight)
g2.metric("Steps", int(agg['STEPS'].mean()))
g3.metric("Exercise Mins", exercise_mins)
g4.metric("Stand Mins", int(agg['APPLE_STAND_TIME'].mean()/60))
g5.metric("Stairs Climbed", int(agg['FLIGHTSCLIMBED'].mean()))

g2_1, g2_2, g2_3, g2_4, g2_5 = st.columns(5)
g2_1.metric("Active Energy", int(agg['ACTIVE_ENERGY_BURNED'].mean()))
g2_2.metric("Basal Energy", int(agg['BASAL_ENERGY_BURNED'].mean()))
g2_3.metric("Total Energy Bruned", cals_burned)
g2_4.metric("Cals Consumed", cals_consumed)
g2_5.metric("Sleep Hours", sleep)


# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------


# CALORIES DATA
df_cals = pd.DataFrame({
  'date': agg['DATE'],
  'Basal': agg['BASAL_ENERGY_BURNED'].round(),
  'Active': agg['ACTIVE_ENERGY_BURNED'].round()
})


# MACRO DATA CONVERT TO CALS
df_macros = pd.DataFrame({
  'date': agg['DATE'],
  'Protein': agg['PROTEIN'].round()*4,
  'Carbs': agg['CARBS'].round()*4,
  'Fat': agg['FATTOTAL'].round()*9
})

MAX_CAL_CALC = max((agg['ACTIVE_ENERGY_BURNED'] + agg['BASAL_ENERGY_BURNED']).max(), agg['DIETARY_ENERGY'].max())/1000


# Transform the dataframe for chart
dfm_macros = df_macros.melt(id_vars=['date'])

# plot chart
macros_chart = alt.Chart(dfm_macros).mark_bar(size=20).encode(
    x = alt.X('date:T', title=None),
    y = alt.Y('value:Q', axis=None, scale=alt.Scale(domain=[0, MAX_CAL_CALC])),
    color= alt.Color('variable', legend=None,
             scale=alt.Scale(domain=['Protein','Carbs', 'Fat'],
                             range=['#6C5B7B','#F67280','#F8B195'])
        )
)

dfm_macros['value'] = (dfm_macros['value']/1000).round(1)
macros_text = alt.Chart(dfm_macros).mark_text(baseline='top',color='white', fontSize=16, fontWeight=900, align='center', filled=False, fill = '#2070b9', strokeWidth=1).encode(
    x = alt.X('date:T'),
    y= alt.value(120),
    text = 'sum(value)'
) 


macros_plot = alt.layer(macros_chart, macros_text).properties(
    title='Macronutrients (cals)'
).configure_title(
    fontSize=15,
    font='Helvetica',
    anchor='start',
    color='#2070b9',
    offset=0
).configure_axis(
    labelColor='#000',
    labelFontSize=12,
    labelFontWeight = 900
).properties(
    width=300,
    height=250
)


# ////////////////////////////////////////////////////////////////////////



# Transform the dataframe for chart
dfm_cals = df_cals.melt(id_vars=['date'])

# plot chart
cals_chart = alt.Chart(dfm_cals).mark_bar(size=20).encode(
    x = alt.X('date:T', title=None, scale=alt.Scale(padding=0)),
    y = alt.Y('value:Q', axis=None, scale=alt.Scale(domain=[0, MAX_CAL_CALC])),
    color= alt.Color('variable', legend=None,
             scale=alt.Scale(domain=['Basal','Active'],
                            range=['#EC5F6B','#B1DD9E'])
        )
)


dfm_cals['value'] = (dfm_cals['value']/1000).round(1)

cals_text = alt.Chart(dfm_cals).mark_text(baseline='top',color='white', fontSize=16, fontWeight=900, align='center', filled=False, fill = '#2070b9', strokeWidth=1).encode(
    x = alt.X('date:T'),
    y=alt.value(120),
    text = 'sum(value)'
) 

cals_plot = alt.layer(cals_chart, cals_text).properties(
    title='Daily Cals Burned (000\'s)'
).configure_title(
    fontSize=15,
    font='Helvetica',
    anchor='start',
    color='#2070b9',
    offset=0
).configure_axis(
    labelColor='#000',
    labelFontSize=12,
    labelFontWeight = 900
).properties(
    width=300,
    height=250
)


# add charts to columns
macros, cals, cal_status = st.columns(3)
# bw_col.altair_chart(weight_plot, use_container_width=True)
macros.altair_chart(macros_plot, use_container_width=True)
cals.altair_chart(cals_plot, use_container_width=True)


D1, D2, D3, D4, D5 = st.columns(5)
D1.metric("Carbs(g)", int(agg['CARBS'].mean()))
D2.metric("Protein(g)", int(agg['PROTEIN'].mean()))
D3.metric("Fat(g)", int(agg['FATTOTAL'].mean()))
D4.metric("Sodium(mg)", int(agg['SODIUM'].mean()*1000))
D5.metric("Sugar(g)", int(agg['SUGAR'].mean()))

cal_diff = int(df_macros['Protein'].sum() + df_macros['Carbs'].sum() + df_macros['Fat'].sum()) - int(df_cals['Basal'].sum() + df_cals['Active'].sum())
cal_status.markdown(f'''You had a caloric difference of **{cal_diff}**. \n\n Generally there are **3,500 calories** in a pound of fat.
                        
                        \n\n You will **{ {True: 'lose', False: 'gain'} [cal_diff < 0] } 1 Pound** every **{abs(3500//int(cal_diff/(end_date-start_date).days))} days.**''')

chatPrompt = f'''
    This person has consumed the following macros in calories \n {df_macros}.
    This person also on average burns {cals_burned} calories a day.
    This person consumed an average {agg['SODIUM'].mean()} grams of sodium per day.
    This person consumed an average {agg['SUGAR'].mean()} grams of sugar per day.
    This person is a {age} year old {gender} and weighs {weight}.

    Please give your opinion,advise and changes would you suggest in 1 paragraph under 4 sentences?
    if applicable, please add what good break out of protein, carbs and sugar are for generally healthy people.
    if applicable, Please add what acceptable levels of sodium and sugar are for healthy people.
    Please keep it very short and concise.
    Address the user directly in the second person. 
'''

st.markdown(f'{ask_chatGPT(chatPrompt)} **:red[Opinion provided by ChatGPT]**')


# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------

st.header("Heart Rate & Sleep Trends")
# st.markdown(f'''Heart health is crucial for overall well-being as the heart is responsible for pumping 
#                 oxygenated blood to all organs, supporting their proper function and vitality. Maintaining a healthy 
#                 heart reduces the risk of cardiovascular diseases. Prioritizing heart health through regular exercise, 
#                 a balanced diet, and stress management positively impacts physical mental well-being and overall quality of life.''')


#HEART RATE KPIs
heart_query = session.sql(f""" SELECT avg(value)::INT as HR
                       FROM hk.heartrate 
                       WHERE ID ='{pin}' 
                       and STARTTIME between '{start_date}' and '{end_date}' 
                       order by STARTTIME asc""").to_pandas()

rest_heart_query = session.sql(f""" SELECT (avg(value)*60)::INT as HR
                       FROM hk.restingheartrate 
                       WHERE ID ='{pin}' 
                       and STARTTIME between '{start_date}' and '{end_date}' 
                       order by STARTTIME asc""").to_pandas()

walk_heart_query = session.sql(f""" SELECT (avg(value)*60)::INT as HR
                       FROM hk.walkingheartavg 
                       WHERE ID ='{pin}' 
                       and STARTTIME between '{start_date}' and '{end_date}' 
                       order by STARTTIME asc""").to_pandas()

heart_sdnn = session.sql(f""" SELECT avg(value)::INTEGER as HR
                       FROM hk.heartratesdnn 
                       WHERE ID ='{pin}' 
                       and STARTTIME between '{start_date}' and '{end_date}' 
                       order by STARTTIME asc""").to_pandas()

HR1, HR2, HR3, HR4, HR5, HR6 = st.columns(6)
HR1.metric("Resting HR", rest_heart_query['HR'])
HR2.metric("Heart Rate", heart_query['HR'])
HR3.metric("Walking HR", walk_heart_query['HR'])
HR6.metric("HR SDNN (ms)", heart_sdnn['HR'])




# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------




heart_rate_plot = session.sql(f""" select DISTINCT DATE_TRUNC('DAY', STARTTIME)::DATE AS DATE, VALUE::INT AS HR
                       from hk.heartrate
                       WHERE ID ='{pin}' 
                       and STARTTIME between '{start_date}' and '{end_date}' 
                       order by DATE asc""").to_pandas()

HR4.metric("Min Heart Rate", heart_rate_plot['HR'].min())
HR5.metric("Max Heart Rate", heart_rate_plot['HR'].max())

points = alt.Chart(heart_rate_plot).mark_point().encode(
    x=alt.X('monthdate(DATE):O', title=None,  scale=alt.Scale(padding=0)),
    y=alt.Y('HR:Q', title=None, scale=alt.Scale(domain=[heart_rate_plot['HR'].min(), heart_rate_plot['HR'].max()], padding=0) )
).properties(
    title= f"""Heart Rate (BPM)"""
).configure_title(
    fontSize=15,
    font='Helvetica',
    anchor='start',
    color='#2070b9',
    offset=0
).configure_axis(
    labelColor='#000',
    labelFontSize=12,
    labelFontWeight = 900
).properties(
    width=300,
    height=250
)



hr_chart, sleep_chart = st.columns([2, 2])
hr_chart.altair_chart(points , use_container_width=True)


sleep_plot = session.sql(f"""select ID, DATE_TRUNC('minute', STARTTIME) AS STARTTIME, sum(mins) as SLEEP, cycle, DATE_TRUNC('DAY', DATEADD(HOUR, 6,STARTTIME))::DATE AS DAY
                                from HK.SLEEP
                                where value != 0 and id = '{pin}'
                                and DATE_TRUNC('DAY', DATEADD(HOUR, 6,STARTTIME))  between '{start_date}' and '{end_date}'
                                group by 1, 2, 4,5
                                order by starttime asc""").to_pandas()







# MAKE DATAFRAME FOR SLEEP CYCLES - PUT TOGETHER ALL THAT LOGIC FOR STRIP PLOT
sleepX = []
sleepY = []
sleepCat = []
unique_sleep_days = sleep_plot['DAY'].unique()

# MAKE DATAFRAME FOR SLEEP CYCLES
for x in range(0, unique_sleep_days.shape[0]):
    sleep_day = unique_sleep_days[x]
    entire_sleep_day = sleep_plot.loc[sleep_plot['DAY'] == sleep_day]
    
    counter = 1
    for z in range(0, entire_sleep_day.shape[0]):
        for y in range(0, int( entire_sleep_day.iloc[z]['SLEEP']) ):
            sleepX.append(counter)
            sleepY.append(sleep_day)
            sleepCat.append(entire_sleep_day.iloc[z]['CYCLE'])
            
            counter = counter + 1
    

sleep_dataframe = pd.DataFrame({
   'X':   sleepX,
   'Y':   sleepY,
   'Cat': sleepCat
})


chart_for_sleep = alt.Chart(sleep_dataframe).mark_tick().encode(
    y= alt.X('X:Q', title=None),
    x= alt.Y('monthdate(Y):T', title=None),

    color= alt.Color('Cat',
            legend=alt.Legend(
                orient='none',
                legendY=-15,
                legendX= 10,
                direction='horizontal',
                labelFontSize=12,
                labelColor= '#000',
                labelFontWeight = 900,
                title=None,
                padding = -10,
                labelPadding = -3,
                symbolSize = 50
                ),
             scale=alt.Scale(domain=['awake','Core','REM','Deep'],
                            range=['#D94496','#015283', '#049ffc','#7892fb'])   
    )# End Color

).properties(
    title= f"""Sleep Cycles (mins)"""
).configure_title(
    fontSize=15,
    font='Helvetica',
    anchor='start',
    color='#2070b9',
).configure_axis(
    labelColor='#000',
    labelFontSize=12,
    labelFontWeight = 900
).properties(
    width=300,
    height=250
)

sleep_chart.altair_chart(chart_for_sleep);


chatPrompt = f'''
    This person has resting heart rate of {rest_heart_query}, average heart rate of {heart_query}.
    This person has a walking heart rate average of {walk_heart_query} and a heart rate variability of {heart_sdnn}.
    This person exercises {exercise_mins} mins on average per day. 
    This person is a {age} year old {gender} and weighs {weight}.
    
    Please give your opinion,advise and changes would you suggest in 1 paragraph under 4 sentences?
    Please keep it very short and concise.
    Address the user directly in the second person. 
    
'''
st.markdown(f'{ask_chatGPT(chatPrompt)} **:red[Opinion provided by ChatGPT]**')


# ---------------------------------------------------------------
# ---------------------------------------------------------------
# ---------------------------------------------------------------




















