import pandas as pd
import numpy as np
from tqdm import trange

from mods import *

# load nodes
df = pd.read_csv("../../docs/Catchments_updt_sorted.csv")
df = df[df['River System'] == 'Rangitaki']  # keep only Rangitaiki river
df['ssat'] = 0  # starting saturation in each catchment
df['rsa'] = 20  # mm rainfall amount for saturation
df['river_flows'] = 74  # mean river discharge for Rangitaiki
df['process_time'] = 0  # include internal process time

# setting period of investigation parameters
number_of_hours = 8766  # one year
season = -1

states_lists = []

for time in trange(number_of_hours):

    # set season
    if time % np.round(8766 / 4) == 0:
        season += 1
        if season > 3:
            season = 0

    # print(f'we are in {rain_str[season]}')

    if time % 24 == 0:  # it's a new day
        # print('next day')
        hourly_rain = generate_hourly_rainfall_amount(rain_proba[season], rain_m[season], rain_s[season])

    # calculate effective rain in each catchments
    df['reff'] = df.apply(lambda row: calculate_effective_rainfall(row['ssat'],
                                                                   row['rsa'],
                                                                   hourly_rain,
                                                                   row['f1'],
                                                                   row['fsa']), axis=1)

    df['total_discharge'] = df.apply(lambda row: calculate_catchment_total_discharge(row['reff'],
                                                                                     row[
                                                                                         'Proportional coefficient (K)'],
                                                                                     row['Area (m2)'],
                                                                                     row['river_discharge']), axis=1)

    df['saturation'] = df.apply(lambda row: calculate_saturation_in_catchment(row['ssat'],
                                                                              row['reff'],
                                                                              row['total_discharge']), axis=1)

    # move the flow downstream
    for i in range(len(df)):
        target = df['Target_river'][i]
        df['river_flows'][i] = df[df['Source_river'] == target]['total_discharge'].max()
        
