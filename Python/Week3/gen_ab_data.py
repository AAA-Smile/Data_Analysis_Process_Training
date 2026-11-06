import pandas as pd
import numpy as np
from datetime import datetime, timedelta

np.random.seed(2026)
n = 20000
start = datetime(2026, 9, 1)

# ---------- 1. 分组：故意制造 SRM（样本比例失调） ----------
# 设计 50/50，实际 52/48
group = np.random.choice(["control", "treatment"], n, p=[0.52, 0.48])

# ---------- 2. 渠道：treatment 组 App 占比更高（埋辛普森悖论伏笔） ----------
channel = []
for g in group:
    if g == "treatment":
        channel.append(np.random.choice(["App", "小程序", "PC"], p=[0.60, 0.25, 0.15]))
    else:
        channel.append(np.random.choice(["App", "小程序", "PC"], p=[0.45, 0.35, 0.20]))

device = np.random.choice(["iOS", "Android", "Web"], n, p=[0.4, 0.4, 0.2])
exp_date = [start + timedelta(days=np.random.randint(0, 14)) for _ in range(n)]

# ---------- 3. 转化率：整体 treatment 更高，但分渠道看 treatment 更低 ----------
# 这是刻意设计的辛普森悖论
base_rate = {"App": 0.15, "小程序": 0.08, "PC": 0.05}
lift_by_channel = {"App": -0.01, "小程序": -0.005, "PC": -0.002}  # 每个渠道内 treatment 都更低

converted = []
for g, ch in zip(group, channel):
    p = base_rate[ch]
    if g == "treatment":
        p += lift_by_channel[ch]
    converted.append(1 if np.random.rand() < p else 0)
converted = np.array(converted)

# ---------- 4. 支付金额：treatment 均值略高，但效应量很小 ----------
amount = np.where(
    converted == 1,
    np.random.normal(200, 100, n) + np.where(group == "treatment", 8, 0),
    0,
)
amount = np.round(np.clip(amount, 0, None), 2)

# ---------- 5. 留存：treatment 略高，但差异可能不显著 ----------
d1_rate = np.where(group == "treatment", 0.32, 0.30)
d7_rate = np.where(group == "treatment", 0.16, 0.15)
active_d1 = (np.random.rand(n) < d1_rate).astype(int)
active_d7 = (np.random.rand(n) < d7_rate).astype(int)

# ---------- 6. 新奇效应：前 3 天 treatment 转化率额外 +3pp，之后回落 ----------
day_idx = [(d - start).days for d in exp_date]
novelty_bonus = np.where((np.array(day_idx) < 3) & (group == "treatment"), 0.03, 0)
# 用额外随机数模拟“因新奇效应多转化的人”
novelty_convert = (np.random.rand(n) < novelty_bonus).astype(int)
converted = np.maximum(converted, novelty_convert)

df = pd.DataFrame({
    "user_id": [f"U{str(i).zfill(5)}" for i in range(1, n + 1)],
    "group": group,
    "channel": channel,
    "device": device,
    "exp_date": [d.strftime("%Y-%m-%d") for d in exp_date],
    "day_idx": day_idx,
    "converted": converted,
    "amount": amount,
    "active_d1": active_d1,
    "active_d7": active_d7,
})

df.to_csv("ab_experiment.csv", index=False, encoding="utf-8-sig")
print(df.shape)
print(df.groupby("group").size())
print(df.groupby("group")["converted"].mean())
print(df.groupby(["group", "channel"])["converted"].mean().unstack())