# 数据生成脚本

import pandas as pd
import numpy as np
from datetime import datetime, timedelta

np.random.seed(42)
n_users = 2000
n_days = 30
start = datetime(2026, 9, 1)

users = pd.DataFrame({
    "user_id": [f"U{str(i).zfill(4)}" for i in range(1, n_users + 1)],
    "channel": np.random.choice(["App", "小程序", "PC"], n_users, p=[0.5, 0.3, 0.2]),
    "device": np.random.choice(["iOS", "Android", "Web"], n_users, p=[0.4, 0.4, 0.2]),
    "register_date": [start + timedelta(days=np.random.randint(0, n_days)) for _ in range(n_users)],
})

steps = ["exposure", "click", "add_cart", "order", "pay"]
trans = {"exposure": 1.0, "click": 0.35, "add_cart": 0.45, "order": 0.5, "pay": 0.8}

rows = []
for _, u in users.iterrows():
    if np.random.rand() > 0.9:
        continue
    n_sessions = np.random.randint(1, 14)
    for _ in range(n_sessions):
        days_after = np.random.randint(0, n_days)   # 关键：0~29 天
        t = u["register_date"] + timedelta(
            days=days_after,
            hours=np.random.randint(0, 24),
            minutes=np.random.randint(0, 60),
        )
        reached = True
        for s in steps:
            if not reached:
                break
            if np.random.rand() < trans[s]:
                rows.append({
                    "event_id": f"E{len(rows)+1:06d}",
                    "user_id": u["user_id"],
                    "event_time": t.strftime("%Y-%m-%d %H:%M:%S"),
                    "event_type": s,
                    "channel": u["channel"],
                    "device": u["device"],
                    "amount": round(np.random.uniform(50, 2000), 2) if s == "pay" else 0,
                })
                t += timedelta(minutes=np.random.randint(1, 120))
            else:
                reached = False

df = pd.DataFrame(rows)
raw_n = len(df)

dirty = df.sample(frac=0.02, random_state=1).copy()
dirty["event_type"] = dirty["event_type"].replace({"click": "Click", "pay": "PAY"})
dirty["channel"] = dirty["channel"].replace({"App": "app", "PC": "pc"})
dirty["event_time"] = dirty["event_time"].replace(df["event_time"].iloc[0], None)
df = pd.concat([df, dirty], ignore_index=True)
df = pd.concat([df, df.sample(frac=0.01, random_state=2)], ignore_index=True)

df.to_csv("events.csv", index=False, encoding="utf-8-sig")
print("干净行数:", raw_n, "总行数:", len(df))