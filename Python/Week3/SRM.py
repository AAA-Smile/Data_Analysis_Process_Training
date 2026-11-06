import pandas as pd
from scipy import stats

df = pd.read_csv("ab_experiment.csv")
counts = df["group"].value_counts()
print(counts)

# 卡方拟合优度检验：实际比例 vs 期望 50/50
chi2, p_srm = stats.chisquare(counts.values, f_exp=[len(df)/2, len(df)/2])
print(f"SRM p 值: {p_srm:.4f}")