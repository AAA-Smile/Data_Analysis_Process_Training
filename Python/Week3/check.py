import pandas as pd

df = pd.read_csv("ab_experiment.csv")

print(pd.crosstab(df["group"], df["channel"], normalize="index").round(3))
print(pd.crosstab(df["group"], df["device"], normalize="index").round(3))