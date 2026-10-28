import pandas as pd
import matplotlib.pyplot as plt
from sqlalchemy import create_engine
import matplotlib

matplotlib.rcParams['font.sans-serif'] = ['Microsoft YaHei']  # Mac 改 'PingFang SC'
matplotlib.rcParams['axes.unicode_minus'] = False

engine = create_engine(
    'mysql+pymysql://root:123456@localhost:3306/demo?charset=utf8mb4'
)

# ---------- 图1：帕累托 ----------
df_user = pd.read_sql("""
WITH user_gmv AS (
    SELECT user_id, SUM(amount) AS gmv
    FROM dw_order_wide GROUP BY user_id
)
SELECT user_id, gmv,
       ROUND(gmv*100.0/SUM(gmv) OVER (),2) AS gmv_pct,
       ROUND(SUM(gmv) OVER (ORDER BY gmv DESC)*100.0/SUM(gmv) OVER (),2) AS cum_pct
FROM user_gmv ORDER BY gmv DESC
""", engine)

fig, ax1 = plt.subplots(figsize=(10, 5))
ax1.bar(df_user['user_id'].astype(str), df_user['gmv'], color='#4C72B0', label='用户GMV')
ax1.set_xlabel('用户ID')
ax1.set_ylabel('GMV（元）')
ax1.tick_params(axis='x', rotation=0)

ax2 = ax1.twinx()
ax2.plot(df_user['user_id'].astype(str), df_user['cum_pct'],
         color='#C44E52', marker='o', label='累计占比')
ax2.axhline(80, color='gray', linestyle='--', linewidth=1)
ax2.set_ylabel('累计占比（%）')
ax2.set_ylim(0, 105)

plt.title('用户GMV贡献帕累托图')
fig.tight_layout()
plt.savefig('fig1_user_pareto.png', dpi=150)
plt.show()

# ---------- 图2：周内分布 ----------
df_dow = pd.read_sql("""
SELECT DAYOFWEEK(order_time) AS dow_num,
       CASE DAYOFWEEK(order_time)
         WHEN 1 THEN '周日' WHEN 2 THEN '周一' WHEN 3 THEN '周二'
         WHEN 4 THEN '周三' WHEN 5 THEN '周四' WHEN 6 THEN '周五'
         WHEN 7 THEN '周六' END AS dow_name,
       COUNT(DISTINCT order_id) AS order_cnt,
       SUM(amount) AS gmv,
       SUM(amount)/COUNT(DISTINCT order_id) AS aov
FROM dw_order_wide
GROUP BY DAYOFWEEK(order_time)
ORDER BY dow_num
""", engine)

fig, ax1 = plt.subplots(figsize=(9, 5))
ax1.bar(df_dow['dow_name'], df_dow['order_cnt'], color='#55A868', label='订单数')
ax1.set_ylabel('订单数')
ax1.set_xlabel('星期')

ax2 = ax1.twinx()
ax2.plot(df_dow['dow_name'], df_dow['aov'], color='#C44E52', marker='o', label='客单价')
ax2.set_ylabel('客单价（元）')

plt.title('周内订单分布与客单价')
fig.tight_layout()
plt.savefig('fig2_weekday.png', dpi=150)
plt.show()

# ---------- 图3：地区×品类热力图 ----------
df_cross = pd.read_sql("""
SELECT region, category, SUM(amount) AS gmv
FROM dw_order_wide
GROUP BY region, category
""", engine)

pivot = df_cross.pivot(index='region', columns='category', values='gmv').fillna(0)

fig, ax = plt.subplots(figsize=(8, 5))
im = ax.imshow(pivot.values, cmap='YlOrRd', aspect='auto')
ax.set_xticks(range(len(pivot.columns)))
ax.set_xticklabels(pivot.columns)
ax.set_yticks(range(len(pivot.index)))
ax.set_yticklabels(pivot.index)

for i in range(len(pivot.index)):
    for j in range(len(pivot.columns)):
        ax.text(j, i, f'{pivot.values[i, j]:.0f}',
                ha='center', va='center', fontsize=9)

plt.colorbar(im, label='GMV（元）')
plt.title('地区 × 品类 GMV 热力图')
fig.tight_layout()
plt.savefig('fig3_region_category.png', dpi=150)
plt.show()