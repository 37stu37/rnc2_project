from mods_weather import *
from mods_catchment import *

import pandas as pd
import numpy as np

# probability of rain Sep-Nov, Dec-Feb, Mar-May, Jun-Aug
rain_proba = [0.43, 0.4, 0.35, 0.39]
rain_m = [1.62, 1.56, 1.73, 1.8]
rain_s = [1.01, 1.06, 1.09, 1.07]
rain_str = ['Sep-Nov', 'Dec-Feb', 'Mar-May', 'Jun-Aug']

df = pd.read_csv("/Users/alexdunant/Documents/Github/rnc2_project/docs/Catchments_updt_sorted.csv")
saturations = np.zeros(len(df))
baseflows = np.zeros(len(df))
tephra_deposits = np.zeros(len(df))
vegetation_param = np.zeros(len(df))
river_flows = np.arange(0, len(df))

number_of_hours = 8766  # one year
season = 0

states_lists = []

for time in range(number_of_hours):

    # weather
    if time % np.round(8766/4) == 0:
        season += 1
        if season > 3:
            season = 0

    if time % 24 == 0: # it's a new day
        daily_rain = generate_daily_rainfall_amount(rain_proba[season], rain_m[season], rain_s[season])
        hourly_rain = daily_rain / 24 # we assume same intensity every hour for 24h ...
    else:
        hourly_rain = daily_rain / 24

    # effective rain for each catchment
    effective_rains = np.array([effective_rainfall(df['saturation'][i],
                                          df['rsa'][i],
                                          hourly_rain,
                                          df['f1'][i],
                                          df['fsa'][i]) for i in range(len(df))])

    # calculate catchment discharges to river
    catchment_discharges = [catchment_discharge(effective_rains[i],
                                                df['Proportional coefficient (K)'][i],
                                                df['Area (m2)'],
                                                time,
                                                baseflows[i]) for i in range(len(df))]

    # update saturation "state" for each catchment
    saturations = [catchment_saturation(saturations[i],
                                       effective_rains[i],
                                       catchment_discharges[i]) for i in range(len(df))]

    # calculate tephra runoff to river
    tephra_runoffs = [tephra_runoff(catchment_discharges[i],
                                    df['Area (m2)'][i],
                                    df['Length (m2)'][i],
                                    df['Slope (Gradient)'][i],
                                    tephra_deposits[i],
                                    vegetation_param[i]) for i in range(len(df))]


    # update river flows with additional discharges and sediments
    !!!!river_flows = [river_flows[df['Source_river']==df['Target_river'][i]] for i in range(len(df))]
    sediment_river = ...

    # database to list
    states_at_time = pd.DataFrame(
        {'time': time,
         'effective_rain': effective_rains,
         'catchment_discharges': catchment_discharges,
         'catchment_saturations': saturations,
         'tephra_runoff': tephra_runoffs,
         'river_flows' : flows,
         'sediment_river' : sediment_river
         })

    states_lists.append(states_at_time)