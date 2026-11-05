# 数分练习

## 先将需要分析的表格使用MySQL构建起来
编写一个SQL脚本运行，其中包含建表，插入数据，查询操作，构建三合一表格等相关操作；主要涉及到普通查询，窗口函数查询等

## 一、数据库以及表的构建
1、构建demo数据库

2、使用demo数据库

3、先删除demo中可能已经存在的构建目标表

4、建表，主要是三个：

（1）users用户表：包含字段为用户id，用户名称，用户所在地区，用户注册时间

（2）products商品表：包含字段为商品id，商品名称，商品品类，商品价格

（3）orders订单表：包含字段为订单id，下单用户id，下单商品id，购买数量，成交金额，下单渠道，订单状态（**在计算GMV时只考虑已付款的情况（已取消、已退款不计算在内）**），下单时间

5、接下来我们模拟插入些数据进去，用户表10行，商品表8行，订单表66行
## 二、查询操作
**1、按周统计GMV，订单数，客单价**

**%x-%v**它遵循的是**ISO 8601标准**，也就是**以周一作为一周的开始**，表示第几年的第几周
```MySQL
select 
	date_format(order_time , '%x-%v') as year_week , 
	round(sum(amount) , 2) as gmv , 
	count(distinct order_id) as order_cnt , 
	round(sum(amount) / count(distinct order_id) , 2) as avg_order_value
from orders
where status = 'paid'
group by date_format(order_time , '%x-%v')
order by month 
```
**2、按月统计GMV，订单数，客单价**
```MySQL
select 
	date_format(order_time , '%Y-%m') as month , 
	round(sum(amount) , 2) as gmv , 
	count(distinct order_id) as order_cnt
	round(sum(amount) / count(distinct order_id) , 2) as avg_order_value
from orders
where status = 'paid'
group by date_format(order_time , '%Y-%m')
order by month 
```
**3、按品类/渠道/地区分组对比 GMV，订单数，客单价**

（1）按品类

使用JOIN时，没有前缀默认是INNER JOIN内连接，只保留两张表内公有的元素
```MySQL
select 
	p.category , 
	round(sum(o.amount) , 2) as gmv , 
	count(distinct o.order_id) as order_cnt , 
	round(sum(o.amount) / count(distinct o.order_id) , 2) as avg_order_value
from order as o 
join products as p 
on o.product_id = p.product_id 
where o.status = 'paid'
group by p.category
order by gmv desc 
```
（2）按渠道
```MySQL
select 
	channel , 
	round(sum(amount) , 2) as gmv , 
	count(distinct order_id) as order_cnt , 
	round(sum(amount) / count(distinct order_id) , 2) as avg_order_value 
from order
where status = 'paid'
group by channel
order by gmv desc 
```
（3）按地区
```MySQL
select 
	u.region , 
	round(sum(amount) , 2) as gmv ,
	count(distinct o.order_id) as order_cnt , 
	round(sum(amount) / count(distinct o.order_id) , 2) as avg_order_value
from orders as o
join users as u 
on o.user_id = u.user_id
where o.status = 'paid'
group by u.region
order by gmv desc 
```

**4、窗口函数：按月环比、同比**

`WITH ... AS` 叫 **CTE（Common Table Expression，公共表表达式）**，中文常叫“**公用表表达式**”或“**临时结果集**”。

**它给一段查询结果起个名字，让后面的 SQL 可以像用表一样用它**

`LAG(gmv) OVER (ORDER BY month)` —— 取“上一行”的 GMV

	ORDER BY month 先按照月份升序排好
	
	LAG(gmv) 对每一行，往上找 1 行，把那一行的 gmv 拿过来，作为 prev_month_gmv

	默认偏移量是 1，等价于 LAG(gmv, 1)

`LAG(gmv, 12) OVER (ORDER BY month)` —— 取“往上数 12 行”的 GMV

	相当于是去年该月的GMV，不过这个严重依赖连续月份

**同比环比计算公式**

$$
环比公式=（本月 GMV−上月 GMV）/上月 GMV​×100%
$$

$$
同比公式 = （本月GMV - 去年同月GMV）/去年同月GMV × 100%
$$

```MySQL
with monthly as (
	SELECT  
    DATE_FORMAT(order_time, '%Y-%m') AS month,  
    SUM(amount) AS gmv,  
    COUNT(DISTINCT order_id) AS order_cnt  
	FROM orders  
	WHERE status = 'paid'  
	GROUP BY DATE_FORMAT(order_time, '%Y-%m')
) , 
with_lag as (
	select 
		month , 
		gmv , 
		order_cnt , 
		lag(gmv) over (order by month) as prev_month_gmv , 
		lag(gmv , 12) over (order by month) as last_year_gmv 
	from monthly
)
select 
	month , 
	gmv , 
	prev_month_gmv , 
	round((gmv - prev_month_gmv) * 100.0 / nullif(prev_month_gmv , 0) , 2) as mom_pct , 
	last_year_gmv , 
	round((gmv - last_yaer_gmv) * 100.0 / nullif(last_yaer_gmv , 0) , 2) as yoy_pct 
from with_lag
order by month 
```

**5、多表JOIN出’用户-订单-商品‘宽表**

主要包含字段为：订单id，下单时间，下单状态，下单渠道，用户id，用户名称，用户地区，商品id，商品名称，商品类别，商品单价，购买商品数量，成交金额，购买商品平均单价

```MySQL
select 
	o.order_id,  
	o.order_time,  
	o.status,  
	o.channel,  
	u.user_id,  
	u.user_name,  
	u.region,  
	p.product_id,  
	p.product_name,  
	p.category,  
	p.price,  
	o.quantity,  
	o.amount,
	ROUND(o.amount / NULLIF(o.quantity, 0), 2) AS unit_price
from orders as o 
join users as u
on o.user_id = u.user_id 
join products as p 
on o.product_id = p.product_id 
order by o.order_time
```

**6、将分析宽表固化且只保留paid订单**
```MySQL
CREATE TABLE dw_order_wide AS 
SELECT
	o.order_id,  
	o.order_time,  
	DATE_FORMAT(o.order_time, '%Y-%m') AS month,  
	DATE_FORMAT(o.order_time, '%x-%v') AS year_week,  
	u.user_id,  
	u.region,  
	o.channel,  
	p.product_id,  
	p.category,  
	o.quantity,  
	o.amount
FROM orders o  
JOIN users u    ON o.user_id = u.user_id  
JOIN products p ON o.product_id = p.product_id  
WHERE o.status = 'paid';
```
这时候你就可以在数据库demo中发现一个新的分析宽表，包含的字段就是SELECT语句中提到的那些

可以利用查询函数简单验证一下
```MySQL
SELECT * FROM dw_order_wide ORDER BY order_time LIMIT 10;
```

**7、基于宽表的分析，这里我简单选择几个维度进行描述性分析**

（1）品类×地区 GMV
```MySQL
select 
	region , 
	category , 
	round(sum(amount) , 2) as gmv , 
	count(distinct order_id) as order_cnt 
from dw_order_wide 
group by region , category
order by region , gmv desc 
```

（2）用户贡献集中度

帕累托分析，主要分析方式就是计算各个用户贡献的GMV占比情况，根据总占比大于80%时的人数判断GMV贡献是否过于集中

- **sum(gmv) over()** 目的是计算全表的GMV总和，每一行的都是一个结果，通过计算这个再将每行的GMV作为除数计算每行GMV占比
- **sum(gmv) over (order by gmv desc)** 先将GMV排序，随后计算第一行累加到该行的GMV总和，这是为了计算前n行的GMV之和占全GMV之和的百分比，作为帕累托分析的核心依据
- **row_number() over (order by gmv desc)** 是将GMV从大到小排序，从1开始依此编号，值得注意的是即使两行数值相同编号也不会相同

```MySQL
with user_gmv as (
	select 
		user_id ,
		round(sum(amount) , 2) as gmv , 
		count(distinct user_id) as order_cnt 
	from dw_order_wide 
	group by user_id 
)
select 
	user_id , 
	gmv , 
	order_cnt , 
	round(gmv * 100.0 / sum(gmv) over() , 2) as gmv_cnt ,
	round(sum(gmv) over (order by gmv desc) * 100.0 / sum(gmv) over () , 2) as cum_cnt , 
	row_number() over (order by gmv desc) as rn 
from user_gmv , 
order by gmv desc 
```

（3）周内分布

**星期维度经营分析**：看一周七天里，哪天下单最多、GMV 最高、客单价最贵

- ***`DAYOFWEEK(order_time)`*** —— 返回星期数字，不过周日对应的是数字1，周一对应数字2，以此类推
- ***`CASE DAYOFWEEK(order_time)  WHEN 1 THEN '周日'`*** —— 是将对应的数字类型转换为汉字，简单的 **`CASE 表达式 WHEN 值 THEN 结果`** 写法
- 还有值得注意的是，在查询分组条件上，也需要添加上汉字类型的分组，不然会报错
```MySQL
select 
	dayofweek(order_time) as dow_num , 
	case dayofweek(order_time)
	    WHEN 1 THEN '周日' WHEN 2 THEN '周一' WHEN 3 THEN '周二' 
	    WHEN 4 THEN '周三' WHEN 5 THEN '周四' WHEN 6 THEN '周五' 
	    WHEN 7 THEN '周六'  
	END AS dow_name
	count(distinct order_id) as order_cnt , 
	round(sum(amount) , 2) as gmv , 
	round(sum(amount) / count(distinct order_id) , 2) as aov
from dw_order_wide 
group by 
	dayofweek(order_time), 
	case dayofweek(order_time)
	    WHEN 1 THEN '周日' WHEN 2 THEN '周一' WHEN 3 THEN '周二' 
	    WHEN 4 THEN '周三' WHEN 5 THEN '周四' WHEN 6 THEN '周五' 
	    WHEN 7 THEN '周六'  
	END
order by dow_num
```

（4）地区品类交叉GMV占比分析

主要涉及到的为**PARTITION BY**函数

- **`SUM(gmv) OVER (PARTITION BY region)`** 按照表格字段：区域分成不同窗口，再对区域求GMV的和，拿到每个区域对应的总GMV，由此可以计算**对应品类在该区域GMV占比多大**
- **`SUM(gmv) OVER (PARTITION BY category)`** 按照表格字段：品类分成不同窗口，再对品类求GMV的和，拿到每个品类对应的总GMV，由此可以计算**对应区域在该品类GMV占比多大**

```MySQL
with t as (
	select 
		region , 
		category , 
		round(sum(amount) , 2) as gmv , 
		count(distinct order_id) as order_cnt ,
	from dw_order_wide ,
	group by region , category
)
select 
	region , 
	category , 
	gmv , 
	order_cnt , 
	round(gmv * 100.0 / sum(gmv) over (partition by region) , 2) as pct_in_region , 
	round(gmv * 100.0 / sum(gmv) over (partition by category) , 2) as pct_in_category
from t 
order by region , gmv desc 
```

## 三、**基于MySQL查询结果进行分析**

**1、首先基于MySQL基础表格查询结果本身**

- 由于是模拟数据，所以每月稳定三个购买订单，每周稳定一个购买订单
- 按品类 / 渠道 / 地区分组对比查询可观察到
	- （1）数码、服饰类消费占比最大
	- （2）下单渠道区别不大，小程序、APP、PC端下单次数较为平均
	- （3）下单用户所在地区主要集中在华南、华北、华东
- GMV月环比最高的前三个为25-05、25-11、26-05，月同比最高的是26-08

**2、再基于MySQL组合宽表的描述性分析**

其中涉及到的图位于Python文件夹下，利用Python语言进行图表绘制

（1）用户集中度分析
- 发现：前 6个用户贡献了 84.19% 的 GMV，头部集中度低  
- 证据：帕累托图显示第 6 个用户累计占比达 84.19%
- 建议：若集中度高，建议对头部用户做留存维护（专属权益/复购提醒），同时拓展中部用户；若集中度低，说明盘子较均衡，可优先做拉新。
- 局限：仅 10 个用户，样本小，集中度结论不宜直接外推到全量用户

（2）周内分布分析
- 发现：订单在周三最多，客单价在周一最高
- 证据：周内分布图显示周三订单11单、周一AOV 2076.43 元
- 建议：若某天订单明显集中，可把促销/推送安排在该天前；若周内差异不明显，则不建议按星期做差异化运营
- 局限：每月仅 3 单，日期分布不均匀，周内效应可能被样本噪声掩盖

 （3）地区品类交叉分析
 - 发现：华东/华北/华南/西南等地区的主力品类是数码，该品类在这些地区占比分别为 76.40%、62.59%、79.56%、90.93%
 - 证据：热力图显示 region=华南、category=数码 的 GMV 最高，为21991 元
 - 库存和营销资源向“高 GMV 地区 × 高占比品类”倾斜；对低占比格子先确认是需求低还是供给不足
 - 局限：部分格子订单数 ≤2，占比波动大，需更多数据验证

（4）地区偏科和品类偏科
- 发现：品类食品的 GMV 主要来自地区华东（占该品类44.39%），存在明显的地区偏科/品类结构差异
- 证据：`pct_in_category` 显示品类食品在地区华东的占比远高于其他地区
- 若偏科是渠道/供给造成的，可试点把该品类复制到其他地区；若是需求差异，则维持区域化选品
- 局限：交叉分析只能看相关，不能解释原因，需结合业务背景

（5）综合分析
- 发现：GMV 的主要贡献来自“少数用户 + 特定地区品类组合”，周内分布不是主要影响因素
- 证据：帕累托前6用户占84.19%，地区×品类最高格子占全量 GMV 的 **（待计算）**%，周内订单极差仅 4 单
- 建议：Week 2 优先分析头部用户的行为路径和高占比品类的转化漏斗，而不是按星期做运营
- 局限：描述性分析，未做显著性检验；样本量小，结论需后续数据验证


# 利用Python生成事件数据以及清洗分析操作

## 一、数据生成

首先利用脚本生成两万行左右的数据表格，由于是虚拟数据并不涉及到现实情况，所以逻辑上可能和现实生活中有些偏差。表格中包含一定量的脏数据，方便我们进行数据清洗的练习操作。该生成表主要包含的字段有事件id、用户id、事件时间、事件类型、平台类型、系统类型、消费

## 二、数据清洗

**1、读取数据与描述性统计**

（1）首先导入必要包
```Python
import pandas as pd 
```

（2）读取 - 顺便简单的看一下表格结构
```Python
df = pd.read_csv('events.csv' , encoding='utf-8')
df.head(10)
```

（3）展示表格形状

观察输出结果发现该表在未清洗的情况下总共 21162行、7列
```Python
df.shape()
```

（4）展示表格各列类型

这里就可以观察表格各个字段的类型是否符合要求，例如日期字段在这结果显示的是object类型，显然是不行的，所以在后面的清洗环节需要将其转化为datetime类型，其他字段同理，需要将他们转化为需要的类型
```Python
df.dtypes()
```

（5）统计表格缺失值数量

检查表格有无缺失值，在后续根据需要对缺失值进行一定处理
```Python
df.isna().sum()
```

（6）检查表格事件类型与渠道类型分布

这里主要是针对事件类型列进行分布查看，输出发现exposure类型最多，但有大小写不统一导致部分字段原本同意却分开统计，说明这在后续的清洗环节也需要注意统一字段大小写等操作
```Python
df['event_type'].value_counts(dropna = False)
df['channel'].value_counts(dropna = False)
```

（7）金额描述

负责将金额详细分布情况写出，总值、平均值、中位数、最小最大值等相关指标
```Python
df['amount'].describe()
```

**2、去重**

这个过程目的是为了删除完全重复行，避免影响到后续的分析结果

`subset=["event_id"]`：以业务主键判断重复

`keep="first"`：保留第一次出现的行

`keep=False` 是标记所有重复行，常用于**诊断**而不是删除

`.copy()`：避免后续操作触发 `SettingWithCopyWarning`

操作后发现有1237行事件id重复，我们保留第一个出现的事件，其余重复的直接删除，共删除621行，该表格从原本的 21162行变为现在的 20541行
```Python
before = len(df)
dup_mask = df.duplicated(subset = ['event_id'] , keep = False)
print("重复的 event_id 行数:",dup_mask.sum())
print(df[dup_mask].sort_values('event_id').head(10))

df = df.drop_duplicates(subset = ['event_id'] , keep = 'first').copy()
after = len(df)
print(f"去重：{before} → {after}，删除 {before - after} 行")
```

**3、统一事件类型**

前面也提到了，由于大小写的不同导致会额外对这些意思相同的字段进行分开统计，这不是我们想要的，我们需要将事件类型统一

映射表兜底可以将未成功转化的且不在映射表里的转化为unknown，后面再对这些列做决定

`where(..., "unknown")`：**不要静默丢弃**无法识别的值，先标成 `unknown`，再决定删还是查。这比直接 `replace` 更安全

```Python
print("处理前:", df["event_type"].value_counts(dropna=False).to_dict())

df['event_type'] = (
	df['event_type']
	.astype(str)
	.str.strip() # 去首尾空格
	.str.lower() # 统一字段为小写
)

# 用映射表兜底：把非标准值显式映射，映射不到的标为 unknown
valid = {"exposure", "click", "add_cart", "order", "pay"}  
df["event_type"] = df["event_type"].where(df["event_type"].isin(valid), "unknown")

print("处理后:", df["event_type"].value_counts(dropna=False).to_dict())
```

**4、统一渠道**

目的同上

渠道和事件类型不同，渠道有中文，所以使用映射表最稳妥，将所有已知变体写清楚，将字段统一转化

映射表的使用方式

- **键**：原始数据里可能出现的各种写法。
- **值**：统一后的标准名称。

在这里面，web端并入到pc

```Python
print("处理前:", df["channel"].value_counts(dropna=False).to_dict())

channel_map = {
    "app": "App", "APP": "App", "App": "App",
    "小程序": "小程序", "mini": "小程序",
    "pc": "PC", "PC": "PC", "web": "PC",
}
df["channel"] = (
    df["channel"].astype(str).str.strip()
    .replace(channel_map)
)
df["channel"] = df["channel"].where(df["channel"].isin({"App", "小程序", "PC"}), "unknown")

print("处理后:", df["channel"].value_counts(dropna=False).to_dict())
```

**5、处理时间空值**

这一步目的是为了将时间列转化为datetime类型，同时对空值以及非法值进行处理

这一步和前面去重的操作差不多，先将该列转化为日期列，然后检查该列的空值以及非法值，将它们删除

- `errors="coerce"`：把无法解析的值变成 `NaT`，而不是直接抛错。**这是诊断的关键**——先看看有多少、长什么样。
- 删除前先打印：确认空值行是否集中在某些用户/事件上，避免系统性偏差。
- 如果空值比例很高，不要直接删，要考虑填充或找上游修复。

`df.loc[na_time, ["event_id", "user_id", "event_type"]].head()` **从 `df` 中筛选出“时间字段缺失”的那些行，只保留三列 `event_id`、`user_id`、`event_type`，然后打印前 5 行**

```Python
before = len(df)
df["event_time"] = pd.to_datetime(df["event_time"], errors="coerce")

na_time = df['event_time'].isna()
print("时间空值/非法行数:", na_time.sum())
print(df.loc[na_time, ["event_id", "user_id", "event_type"]].head())

df = df.dropna(subset = ['event_time']).copy()
print(f"时间清洗：{before} → {len(df)}，删除 {before - len(df)} 行")
```

**6、时间字段派生**

目的是为了扩展分析维度，将时间派生为星期、日期、小时等字段

趋势分析按天、周内分布按星期、漏斗顺序按时间排序，都需要派生字段

`.to_period("W")` **把 `event_time` 这一列的每个时间点，转换成它所属的“那一周”周期，并以字符串形式存到新列 `week` 里**

.`to_period("M")`  **把 `event_time` 这一列的每个时间点，转换成它所属的“那一月”周期，并以字符串形式存到新列 `month` 里**

```Python
df['date'] = df['event_time'].dt.date
df['hour'] = df['event_time'].dt.hour
df['dow'] = df['event_time'].dt.dayofweek
df['dow_name'] = df['dow'].map({0:"周一",1:"周二",2:"周三",3:"周四",4:"周五",5:"周六",6:"周日"})
df["week"] = df["event_time"].dt.to_period("W").astype(str)
df['month'] = df['event_time'].dt.to_period('M').astype(str)

print(df[["event_time","date","hour","dow","dow_name","week","month"]].head())
```

**7、类型转换**

确保数值列是数值类型、id列是字符串类型，最后整体查看一下表格字段类型，确认字段类型转换成功，再确认数值行 NaN 数量

- `to_numeric(errors="coerce")`：把无法转数值的变成 `NaN`，再 `fillna(0)`。**先看有多少 NaN 再决定 fill 还是删**。
- `category` 类型：节省内存，且 `value_counts`、`groupby` 更快。但注意 category 不能直接做数值运算。
- ID 用 `str`：避免 `001` 变成 `1`。

```Python
df['amount'] = pd.to_numeric(df['amount'] , error = 'coerce').fillna(0.0)
df['user_id'] = df['user_id'].astype(str)
df['event_id'] = df['event_id'].astype(str)
df['event_type'] = df['event_type'].astype('category')
df['channel'] = df['channel'].astype('category')

print(df.dtypes)
print("amount 非数值行数:", df["amount"].isna().sum())
```

**8、清洗前后对比与清洗日志**

| 步骤   | 处理前   | 处理后   | 删除/修改  | 规则                                                                | 原因                                        |
| ---- | ----- | ----- | ------ | ----------------------------------------------------------------- | ----------------------------------------- |
| 去重   | 21162 | 20541 | 621    | 按 event_id 保留首行                                                   | 重复行虚增指标                                   |
| 事件类型 | 20541 | 20541 | 修改 0 行 | strip + lower，非标准值标 unknown                                       | 大小写导致分组错误，但最终结果显示未修改任何字段，推测在去重时就将不合规字段删除了 |
| 渠道   | 20451 | 20451 | 修改 0 行 | 映射表统一，web 并入 PC                                                   | 可能渠道名不一致，但结果同上                            |
| 时间空值 | 20451 | 20451 | 修改0行   | to_datetime coerce 后删除                                            | 删除无法参与时间分析的值，但该表中未出现                      |
| 类型转换 | 20451 | 20451 | 修改对应列  | amount→float, id→str,<br>event_type→category,<br>channel→category | 防止聚合错误                                    |

口径说明：
- 事件类型只保留 exposure/click/add_cart/order/pay，其余标 unknown 并保留。
- Web 端并入 PC 渠道。
- 删除空时间行，假设空时间占比 <2%，不构成系统性偏差。

```Python
df['user_id'].nunique() # 输出该表有多少唯一用户
```

清洗后概况：20451 行，1791个用户，5 类事件，3 个渠道。

**9、保存清洗结果与检查**

这一步就是将前面清洗好的数据保存成一个新表 events_clean.csv ，避免覆盖，同时检查数据结构能否对应上清洗后的结果

但由于保存成 CSV表格 时清洗字段格式不保留，所以导出新表的作用是为了交付或者给他人查看

在读取时显示指定字段类型，才能将数据类型原本读回

```Python
df.to_csv('event_clean.csv' , index = False,encoding='utf-8')
```

```Python
df1 = pd.read_csv(
    "events_clean.csv",
    encoding="utf-8",
    parse_dates=["event_time"],          # 时间列直接解析成 datetime
    dtype={
        "user_id": str,
        "event_id": str,
        "event_type": "category",
        "channel": "category",
    },
)

print(df1.dtypes)
```

```Python
df1.shape
```

确认最终结果和清洗后一致，基础的数据清洗工作就到此完成了

## 三、数据分析

经过上一轮的数据清洗工作，表格字段格式以及内容都符合分析要求了，接下来我们进行简单的数据分析操作，尽量全涉及到在日常工作中会使用到的分析方法

**1、读入数据**

由于最好就是另开一份notebook文件来编写分析代码，所以在这里我先将清洗好的CSV表格数据按照规定字段类型读入

由于该部分涉及一些简单的图表绘制，会出现中文乱码的情况，所以现在开头全局设置好

```Python
import matplotlib.pyplot as plt  
  
# 设置中文字体  
plt.rcParams['font.sans-serif'] = ['SimHei']   # Windows 常用  
plt.rcParams['axes.unicode_minus'] = False     # 正常显示负号
```

```Python
import pandas as pd  
import numpy as np 
```

```Python
# 指定字符格式读入数据  
df1 = pd.read_csv(  
    "events_clean.csv",  
    encoding="utf-8",  
    parse_dates=["event_time"],          # 时间列直接解析成 datetime    
    dtype={  
        "user_id": str,  
        "event_id": str,  
        "event_type": "category",  
        "channel": "category",  
    },  
)  
  
print(df1.dtypes)
```

**2、描述性统计与分布分析**

在分析比较以及建模之前，我们需要先知道这个数据他的分布情况是怎么样的，是均匀的、长尾的还是带有异常极值，知道数据分布情况才好决定接下来要做什么，而不是直接利用平均值对比，容易被数据极端值带偏

描述统计不是“跑一下 describe 就完事”，而是回答三个问题：

- **中心在哪**：均值 vs 中位数是否接近？
- **离散多大**：P25–P75 有多宽？P99 和最大值差多少？
- **形状如何**：单峰还是双峰？有没有长尾？

（1）首先筛选出要分析的子集

因为该事件表中，只有状态为pay的情况下才有消费，其他的状态下消费都为0，所以我们需要筛选出状态为pay的数据集

```Python
pay = df1[df1['event_type'] == 'pay'].copy()
pay 
```

（2）看多分位数

`describe()` 默认只有 P25/P50/P75。长尾数据一定要加 P90/P95/P99，否则看不到尾部

根据这个输出结果我们可以知道总共758个数据，其中消费平均值为1000.73，P75的值为1485.18、P99的值为1986.30

```Python
pay["amount"].describe(percentiles=[.1, .25, .5, .75, .9, .95, .99])
```

（3）对比均值和中位数

一般情况下判断规则为：比值 > 1.2 说明右偏（少数高额拉高均值）；接近 1 说明分布较对称

根据输出结果可知，amount的均值为1000.73，中位数为991.38，比值1.01，说明该数据分布较为对称

```Python
mean_v = pay['amount'].mean()
median_v = pay['amount'].median()
print(f"均值 {mean_v:.2f}, 中位数 {median_v:.2f}, 比值 {mean_v/median_v:.2f}")
```

（4）分箱观察分布情况

`qcut` 是**等频分箱**（每箱人数接近），`cut` 是**等宽分箱**。看分布用 `qcut` 更稳，因为不会被极值拉偏箱宽

根据代码输出结果可以观察到，分组都较为平均，每组都是76个样本左右

关于两行代码的详细解释看下两表

| 参数                  | 含义                      |
| ------------------- | ----------------------- |
| `pay["amount"]`     | 要分箱的数值列                 |
| `q=10`              | 分成 10 份，即每份约 10% 的数据    |
| `duplicates="drop"` | 如果分位点有重复，自动丢弃重复的边界，减少箱数 |

| 部分                        | 作用             |
| ------------------------- | -------------- |
| `groupby("amount_bin")`   | 按分箱结果分组，每个区间一组 |
| `observed=True`           | 只保留实际出现过的分组    |
| `["amount"]`              | 只对金额列聚合        |
| `.agg(["count", "mean"])` | 同时算每组的样本数和非空均值 |
```Python
pay['amount_bin'] = pd.qcut(pay['amount'] , q = 10 , duplicates = 'drop')
bin_stat = pay.groupby('amount_bin' , observed = True)['amount'].agg(['count' , 'mean'])
bin_stat 
```

（5）画一个可视化箱线图和直方图

```Python
pay["amount"].hist(bins=50)
pay.boxplot(column="amount")
```

（6）关于这部分的结果解读

- 首先我们知道均值和中位数是接近的，所以可以知道amount分布较为对称，可以用均值代表典型值
- 多分位数的结果中，P75的值为1485.18、P99的值为1986.30，两者差距500左右，说明尾部不存在有涉及特别大金额的订单
- 支付金额中位数 991.38 元，均值 1000.73 元，均值/中位数 = 1.01，呈 对称 分布。P90 为 1485.18 元，P99 为 1986.31 元，尾部 无 明显高额订单。因此后续对比渠道客单价时，采用 中位数 更稳健

**3、分组对比分析**

这部分我们需要解决的问题是回答“**不同群体之间有没有差异、差异多大**”。这是数据分析最高频的动作：渠道对比、设备对比、新老用户对比

分组对比的关键不是 `groupby` 语法，而是**三件事**：

- **比什么指标**：人数、事件数、转化率、客单价；
- **分母是谁**：转化率的分母是用户数还是事件数？
- **样本够不够**：小样本组的差异可能只是噪声。

（1）先指定指标口径

先将口径写成注释，再写代码，口径不清楚的话后面的计算数字可能就对不上

```Python
# 示例：按渠道对比
# 用户数 = nunique(user_id)
# 支付用户数 = event_type=='pay' 的 nunique(user_id)
# GMV = pay 事件 amount 之和
# 支付转化率 = 支付用户数 / 用户数
# 客单价 = GMV / 支付用户数
```

（2）指标计算

使用agg函数一次性计算多个指标，这多个指标合并到同一个表格g中，方便查看

`agg` 里用 `nunique` 算人数，用 `count` 算事件数，用`sum`算分组后的各组消费情况。同时再往g表格中添加各个平台消费用户、消费用户占比以及人均单价字段，最后整合成一个表格按照升序的顺序输出

`ascending = False`控制的是排序顺序，这里是正序

```Python
g = df1.groupby('channel' , observed = True).agg(
	users = ('user_id' , 'nunique'),
	events = ('event_id' , 'count') , 
	gmv = ('amount' , 'sum')
)
pay_users = df1[df1['event_type'] == 'pay'].groupby('channel' , observed = True)['user_id'].nunqiue()
g['pay_users'] = pay_users
g['pay_rate'] = g['pay_users'] / g['users']
g['aov'] = g['gmv'] / g['pay_users']
g.sort_values('pay_rate' , ascending = False)
```

（3）统计样本量，标注小样本

这一步是将g表格中**用户数量**小于100的标记为样本不足，否则就不标记，该行该列的位置留空

想我们这个数据集，在PC，APP，小程序这三个平台上的用户数量均大于100，所以我们g的flag列在这三行中都为空

```Python
g['flag'] = np.where(g['users'] < 100 , '样本不足' , '')
```

（4）简单输出个支付转化率的柱状图

支付转化率在前面g表格中已经计算好了，根据平台支付用户和平台总用户的比值得出

```Python
g['pay_rate'].plot(kind = 'bar' , title="各渠道支付转化率")
```

（5）关于这部分结果解读

- 各渠道支付转化率分别为 App 31.9%、小程序 34.1%、PC 36.1%
- App 用户数最多且转化率 中等 （也大于20%，但相对于其他两个平台低），是主力渠道
- PC 转化率 高 但样本仅 368 人，结论可能没有其他两个平台的可靠
- 建议优先在 App 渠道做转化优化，PC 渠道补充数据后再判断

**4、透视表与交叉分析**

分组对比是“一个维度”，透视表是“**两个维度交叉**”：渠道 × 设备、地区 × 品类、日期 × 事件类型。用来发现结构性差异

核心构造思路就是：

透视表 = **行维度 × 列维度 × 聚合值**。
- 行放什么、列放什么；
- 聚合用 `nunique`（人数）还是 `sum`（金额）还是 `count`（次数）；
- 要不要加合计（`margins=True`）。

（1）先做一个最简单的透视表

按照行为渠道、列为系统，聚合用户数量作为标准

- `aggfunc="nunique"` 算支付人数
- `fill_value=0` 让空组合显示 0 而不是 NaN
- `margins=True` 是在结果表中显示行列合计

```Python
pt = pd.pivot_table(
	df1[df1['event_type'] == 'pay'] , 
	values = 'user_id' , 
	index = 'channel' , 
	columns = 'device' , 
	aggfunc = 'nunique' , 
	fill_value = 0 , 
	margins = True , 
	margins_name = '合计',
)
pt 
```

（2）计算行列各值占比

**行占比**回答“每个渠道内部设备怎么分布”，**列占比**回答“每个设备主要来自哪个渠道”

关于div

- `div` 是 `divide` 的缩写，等价于 `/`
- **关键区别**：`div` 可以用 `axis` 参数指定对齐方向，`/` 默认按列对齐，容易出错
- `axis=0` 表示：让右边的 Series **按行索引（index）对齐**，也就是每一行除以该行对应的和

首先先将上面的pt结果表中行列的合计字段删除，然后求每行的和，再将每行的结果除以该行和，并只取小数点后三位，这样可以回答渠道内部设备是怎么分布的问题

再将`.div`内部参数的求和改为列，再将每列的结果除以列和，这样就可以回答每个设备主要来自哪个渠道的问题

在这里我建议是将`axis`的参数写的明白一些，不使用1或者0来代替行或者列，这样代码不仅更易懂，后续也不容易出错

```Python
# 计算行占比 - 每个渠道内部设备怎么分布
pt_pct = pd.drop('合计' , axis = 'index').drop('合计' , axis = 'columns')
pt_pct = pt_pct.div(pt_pct.sum(axis='columns') , axis = 'index').round(3)
pt_pct
```

```Python
# 计算列占比 - 每个设备主要来自哪个渠道
pt_pct = pt.drop("合计" , axis = "index").drop("合计", axis= "columns")  
pt_pct = pt_pct.div(pt_pct.sum(axis="index"), axis="columns").round(3)  
pt_pct
```

（3）绘制一个占比热力图

可视化结果可以让分析结果更加清晰易懂 ，按照`pt_pct`这个透视表绘制热力图

```Python
import seaborn as sns  
sns.heatmap(pt.drop("合计").drop("合计", axis=1), annot=True, fmt=".0f", cmap="YlOrRd")
```

（4）关于这部分结果解读

- 渠道 × 设备交叉显示，App 渠道中 iOS 支付人数占 44%，Android 占 39.4%
- 小程序渠道以 iOS 为主（39.2%）
- PC 渠道各设备样本均 < 70 人，结构差异不具参考性
- 建议 App 端优先优化 iOS 体验，小程序端重点保障 iOS 兼容性

**5、漏斗分析**

回答“**用户从进入到支付，在哪一步流失最多**”，这是转化分析的核心方法

漏斗的本质是**按步骤算去重用户数，再算相邻步骤的转化率**。三个关键口径必须先定：

- **步骤顺序**：exposure → click → add_cart → order → pay；
- **用户口径**：出现过该事件就算，还是必须按时间顺序完成？
- **时间窗口**：一次会话内，还是一天内，还是不限时间？

我们这简单演示一下，**简化版用“出现过该事件的用户数”**，报告里必须写明“未要求严格顺序”

（1）整体漏斗情况

先按照上面提到的步骤顺序定义漏斗顺序`steps`，核心就是将`df1`表格按照`event_type`分组并只保留`user_id`字段并聚合计算每组的用户数量，再按照漏斗顺序重排，缺失的补0

按照漏斗顺序构造表格并填入`step`和`users`对应的聚合数值

- `reindex(steps)` 保证顺序正确
- `shift(1)` 算相邻步骤转化率
- `iloc[0]` 算整体转化率

| 写法          | 作用              | 一句话记忆    |
| ----------- | --------------- | -------- |
| `.shift(1)` | 把值**整体往下挪 1 行** | 取"上一行"的值 |
| `.iloc[0]`  | 按**位置**取第 1 个元素 | 取"第一个"值  |
```Python
steps = ["exposure", "click", "add_cart", "order", "pay"]
funnel = df1.groupby('event_type' , observed = True)['user_id'].nunique().reindex(steps).fillna(0)
funnel_df = pd.DataFrame({"step": steps, "users": funnel.values})
funnel_df["step_rate"] = funnel_df["users"] / funnel_df["users"].shift(1)  
funnel_df["overall_rate"] = funnel_df["users"] / funnel_df["users"].iloc[0]
funnel_df 
```

（2）观察最大流失环节

**看绝对流失人数，不只看转化率**。转化率最低的环节不一定流失人数最多

对`funnel_df`表添加流失人数字段，我们计算相邻步骤的流失人数`lost_users`，然后将`funnel_df`表按照流失人数`lost_users`字段降序排序并取前两个结果，观察是哪个环节流失人数最多

- 在到下单这一步的用户流失是最多的，可能原因是只是想先加入购物车等后续有需要再购买，也可能是突然觉得没有必要购买了
- 第二是加入购物车这一步，可能原因是点进商品界面发现宣传和实际不符或者观察买家秀之后觉得和自己心理预期不符

```Python
funnel_df['lost_users'] = funnel_df['users'].shift(1) - funnel_df['users']
funnel_df.sort_values('lost_users' , ascending = False).head(2)
```

（3）分渠道漏斗

- `unstack()` 转的是内层索引，在这个表中我们是先对`channel`分组，再对`event_type`分组，那`event_type`就是内层索引，把 `event_type` 从行变成列
- `div(..., axis='index')` 按行做除法，得到每步相对曝光的转化率

计算各个渠道划分的转化率：每行exposure指标作为被除数，随后每行的其他参数值除以exposure得到转化率

```Python
ch_funnel = df1.groupby(['channel' , 'event_type'] , observed = True)['user_id'].nunique().unstack()[steps]
ch_rate = ch_funnel.div(ch_funnel['exposure'] , axis = 'index')
ch_rate.round(3)
```

（4）漏斗图绘制（使用柱状图简单观察趋势）

```Python
import matplotlib.pyplot as plt  
plt.barh(funnel_df["step"][::-1], funnel_df["users"][::-1])  
for i, v in enumerate(funnel_df["users"][::-1]):  
    plt.text(v, i, f" {v:.0f}", va="center")  
plt.title("整体转化漏斗")  
plt.show()
```

（5）关于这部分结果解读

- 整体漏斗从曝光到支付转化率为 33.45%。最大流失在 add_cart→order 环节，环节转化率仅 39.20%，流失 420 人。
- 分渠道看，App 在该环节转化率最低（37.4%），是优先优化对象。
- 注意：本漏斗采用“出现过事件即计入”口径，未要求严格时间顺序，结论为描述性发现

**6、留存/同期群分析**

回答“**用户来了之后还回不回来**”。漏斗看单次转化，留存看长期价值。cohort（同期群）分析按注册批次分组，排除“新用户多导致整体留存虚高”的干扰

- **cohort 标签**：按注册周/月给用户分组；
- **观察期**：注册后第 N 天是否有行为；
- **留存率**：某 cohort 在第 N 天活跃人数 / 该 cohort 总人数。

**分母是该 cohort 的总人数，不是当天活跃人数**。这是留存和活跃度最容易混的地方

（1）给用户打cohort标签

- 从 `df1` 中按 `user_id` 去重（每个用户只保留一行），只取 `user_id` 这一列，并复制成一个独立的新 DataFrame，其中`user_id`外嵌套两层中括号是为了保证取出的数据还是 DataFrame 
- 再按照用户分组，取每组的最小时间（即第一次发生事件的时间），然后将索引还原成普通列得到一个两列表`first_event`
- 再往该列表中添加`cohort`列，对时间取其对应的 周 周期
- 把 `first_event` 表里的"首次事件时间"按 `user_id` 匹配，拼接到 `users` 表上；`users` 里每个用户都保留，匹配不到的时间填 `NaN`
- 最后按照降序计算出每个周区间有多少个用户

```Python
users = df1.drop_duplicates('user_id')[['user_id']].copy()
first_event = df1.groupby('user_id')['event_time'].min().reset_index()
first_event['cohort'] = first_event['event_time'].dt.to_period('W').astype(str)
users = users.merge(first_event,on='user_id',how='left')
users['cohort'].value_counts().sort_index()

```

（2）算每个用户每次活动时间距最早活动起始的天数

```Python
df1 = df1.merge(users[["user_id", "cohort"]], on="user_id", how="left")  
df1= df1.drop(columns=["cohort_x", 'cohort_y']) # 删除可能会出现的多余列，看实际表格情况

# 对每组用户求最小date并广播到该组的每一列
df1['cohort_start'] = df1.groupby("user_id")["date"].transform('min') 
df1['day_diff'] = (df1['date'] - df1['cohort_start']).dt.days
df1.head()
```

（3）计算第N天留存情况

分为多种留存情况分析方式

口径 1：求日留存（现在的写法）

```Python
cohort_total = users.groupby("cohort")["user_id"].nunique()  
for d in [0, 1, 7, 14, 30]:  
    active = df1[df1["day_diff"] == d].groupby("cohort")["user_id"].nunique()  
    rate = (active / cohort_total).fillna(0).round(3)  
    print(f"D{d} 留存:\n{rate}\n")
```
口径 2：区间留存（首周内任意一天回来）

```Python
def retention_range(df, cohort_size, start_day, end_day):
    active = df[(df["day_diff"] >= start_day) & (df["day_diff"] <= end_day)] \
        .groupby("cohort")["user_id"].nunique()
    return (active / cohort_size).fillna(0).round(3)

# 首周留存：第 1–7 天任意一天有行为
r_w1 = retention_range(df, cohort_size, 1, 7)
print("D1–D7 区间留存:\n", r_w1)
```

 口径 3：滚动留存（第 N 天及以后回来过）

```Python
def retention_rolling(df, cohort_size, day):
    active = df[df["day_diff"] >= day].groupby("cohort")["user_id"].nunique()
    return (active / cohort_size).fillna(0).round(3)

print("D7+ 滚动留存:\n", retention_rolling(df, cohort_size, 7))
```

口径 4：周留存（第 N 周内任意一天回来）

```Python
df["week_diff"] = df["day_diff"] // 7

def retention_weekly(df, cohort_size, week):
    active = df[df["week_diff"] == week].groupby("cohort")["user_id"].nunique()
    return (active / cohort_size).fillna(0).round(3)

for w in [0, 1, 2, 4]:
    print(f"W{w} 周留存:\n", retention_weekly(df, cohort_size, w), "\n")
```

（4）绘制留存曲线

可以清除观察各天留存率随着cohort增加的留存情况

```Python
retention = pd.DataFrame({
    d: (df1[df1["day_diff"] == d].groupby("cohort")["user_id"].nunique() / cohort_total).fillna(0)
    for d in [0, 1, 3, 7, 14, 30]
})
retention.plot(marker="o", title="各 cohort 留存曲线")
```

（5）关于这部分结果解读

- 按首次行为周划分 cohort，首周 D1 留存 23.9%，D7 留存 23.3%，D30 留存 0%
- 越晚的 cohort D7 留存 下降，说明 渠道质量变化/产品改动效果
- 最后 6 个 cohort 因观察期不足未纳入 D30 对比
- 建议对 D7 流失用户做召回，并排查晚 cohort 留存下降的渠道来源



