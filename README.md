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
- ***CASE DAYOFWEEK(order_time)  WHEN 1 THEN '周日'*** 是将对应的数字类型转换为汉字，简单的 **CASE 表达式 WHEN 值 THEN 结果** 写法
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


  
  












