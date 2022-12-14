call SH_MARIUS.PIPELINE_TRAIN.TRAIN_MODEL('DefaultModelName');



CREATE OR REPLACE PROCEDURE SH_MARIUS.PIPELINE_TRAIN.TRAIN_MODEL(MODEL_NAME STRING)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.8'
PACKAGES = ('snowflake-snowpark-python', 'scikit-learn')
HANDLER = 'main'
AS
$$

import snowflake.snowpark as snowpark
from snowflake.snowpark import Session
from snowflake.snowpark.functions import udf
from snowflake.snowpark.functions import col
from snowflake.snowpark import functions as F
from snowflake.snowpark.types import *
from sklearn.neural_network import MLPClassifier

def main(session: snowpark.Session, MODEL_NAME):
    MODELNAME = MODEL_NAME #MODEL NAME COMING FROM THE S.PROC DEF

    mlpc = MLPClassifier(hidden_layer_sizes = (10, 5), max_iter=2000);
    
    x = session.sql(f"""SELECT CAL_DIFF, CARBS, FAT, PROTEIN, CHOL, SALT, SUGAR 
                        FROM SH_MARIUS.pipeline_train.GRADED_DIET
                        WHERE DIET_NAME = '{MODELNAME}';""").collect()
    y = session.sql(F"""SELECT GRADE 
                        FROM SH_MARIUS.pipeline_train.GRADED_DIET
                        WHERE DIET_NAME = '{MODELNAME}';""").collect()

    # Model Training 
    mlpc.fit(x, y) 

    @udf(name= f"""SH_MARIUS.pipeline_train.PREDICT_{MODELNAME}""", 
         return_type=IntegerType(), 
         packages=["scikit-learn"],
         is_permanent=True, replace=True, 
         stage_location="@SH_MARIUS.GRADES.HEALTH_STAGE",
         input_types=[FloatType(), FloatType(),FloatType(), FloatType(), FloatType(), FloatType(), FloatType()])
    
    def PREDICT_DIET(calAte, carbs, fat, protein, chol, salt, sugar):
        return mlpc.predict( [[calAte, carbs, fat, protein, chol, salt, sugar]] )[0]

    session.sql(f"""insert into SH_MARIUS.pipeline_train.model_list values ('{MODELNAME}');""").collect()
    return "DONE - Model Trained"

$$