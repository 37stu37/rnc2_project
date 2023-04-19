import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
# from tqdm import tqdm


def generate_daily_rainfall_amount(num_days):
    # Probability of rain and intensity of rainfall for each season
    rain_str = ['Sep-Nov', 'Dec-Feb', 'Mar-May', 'Jun-Aug']
    rain_len = [30, 28, 31, 31]  # Number of days in each season
    proba_values = [0.43, 0.4, 0.35, 0.39]
    # intensity of rainfall
    mu_values = [1.62, 1.56, 1.73, 1.8]
    sigma_values = [1.01, 1.06, 1.09, 1.07]
    num_seasons = len(rain_str)

    # Determine the number of days in each season based on the ratios provided
    season_days = [int(round(n * num_days / sum(rain_len))) for n in rain_len]
    season_days[-1] = num_days - sum(season_days[:-1])

    daily_rainfall = np.zeros(num_days)
    start_day = 0

    # Generate daily rainfall amounts for each season
    for i in range(num_seasons):
        end_day = start_day + season_days[i]
        proba = proba_values[i]
        mu = mu_values[i]
        sigma = sigma_values[i]

        # Generate daily rainfall amounts for the current season
        num_season_days = end_day - start_day
        season_rainfall = np.zeros(num_season_days)

        for j in range(num_season_days):
            u = np.random.uniform(0, 1)

            if proba < u:
                z = np.random.normal()
                amount_of_daily_rainfall = u * np.exp(mu + sigma * z)
            else:
                amount_of_daily_rainfall = 0

            season_rainfall[j] = amount_of_daily_rainfall

        # Add the generated rainfall to the daily rainfall array
        daily_rainfall[start_day:end_day] = season_rainfall

        # Update the start_day for the next season
        start_day = end_day

    return daily_rainfall


# Define catchments and their corresponding parameters
catchments = pd.read_csv("/Users/alexdunant/Documents/Github/rnc2_project/docs/Catchments_updt_sorted.csv", index_col=0)
catchments = catchments[catchments['River System'] == 'Rangitaki']

# Define constants
catchments['max_soil_moisture'] = np.random.randint(200, 400, len(catchments))
num_days = 365  # timestep (in days)

# Define precipitation list (in mm)
precipitations = generate_daily_rainfall_amount(num_days)

# Initialize storage and streamflow arrays
storage = np.zeros(len(catchments))
streamflow = np.zeros(len(catchments))
riverflow = np.zeros(len(catchments))

catchments['riverflow'] = riverflow

# Lists to store results
list_catchment_storages = []
list_catchment_streamflows = []
list_riverflows = []
list_time = []
record = []

# Iterate over timesteps
for t in range(1, num_days):

    # move the flow downstream
    for i in range(len(catchments)):
        target = catchments['Target_river'].values[i]
        source_discharge = catchments[catchments['Source_river'] == target]['riverflow']
        if len(source_discharge) != 0:  # if target is 0 - no source
            catchments.loc[catchments['Target_river'] == target, 'riverflow'] = source_discharge
        else:
            catchments.loc[catchments['Target_river'] == target, 'riverflow'] = 0

    # daily precipitation
    P = precipitations[t]

    # Calculate effective rainfall for each catchment
    for i, catchment in catchments.iterrows():
        # Calculate effective rainfall using F1-RSA method
        sat = catchment['max_soil_moisture']
        k = catchment['Proportional coefficient (K)']
        c1R = catchment['f1']
        c2 = catchment['fsa']
        Rsa = catchment['rsa']
        area = catchment['Area (m2)']
        S = storage[i]
        K = 0.5  # picked a random number for hydraulic conductivity of the soil

        if S <= Rsa:
            Reff = c1R * P * area
        else:
            Reff = (c1R + (c2 - c1R) * ((S - Rsa) / (sat - Rsa))) * P * area

        # Calculate excess rainfall
        excess = max(0, Reff - (sat - S))

        # Calculate infiltration (Proportional coefficient - infiltration rate 'k') and update storage
        infiltration = k * S * t
        storage[i] += Reff - excess - infiltration
        storage[i] = max(0, storage[i])

        # Calculate streamflow
        streamflow[i] = K * storage[i]

    # log the catchment parameters in lists
    list_catchment_storages.append(storage)
    list_catchment_streamflows.append(streamflow)

    # Print streamflow values for each catchment
    print(f"Time: {t} days")
    for i, catchment in catchments.iterrows():
        print(f"{catchment['Catchment Name']}: {streamflow[i]:.2f} m3/s")
    print()

    # create dictionary with new river flows for each node
    new_river_flows = {}
    for index, catchment in catchments.iterrows():
        # get streamflow and river node from current row
        inflow = streamflow[index]
        river_node = catchment['Source_river']

        # add streamflow to new river flow for current node
        if river_node in new_river_flows:
            new_river_flows[river_node] += inflow
        else:
            new_river_flows[river_node] = inflow

    # print new river flows for each node
    for node, flow in new_river_flows.items():
        print(f"River Node {node}: {flow:.2f} m3/s")

    # append the riverflows to dataframe by adding it to old flow
    new_river_flows = catchments['Source_river'].map(new_river_flows)
    riverflow += new_river_flows

    list_riverflows.append(riverflow)
    list_time.append(t)

    # append all to one dataframe which is then stored
    df = pd.concat([pd.Series(storage), pd.Series(streamflow), pd.Series(riverflow)], axis=1)
    df.columns = ['storage', 'streamflow', 'riverflow']
    df['source'] = catchments['Source_river']
    df['target'] = catchments['Target_river']
    df['catchment'] = catchments['Catchment Name']
    df['precipitation'] = P
    df['time'] = t

    record.append(df)


results = pd.concat(record)

print('Done')