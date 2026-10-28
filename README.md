# 数分练习

## 先将需要分析的表格使用MySQL构建起来
编写一个SQL脚本运行，其中包含建表，插入数据，查询操作，构建三合一表格等相关操作；主要涉及到普通查询，窗口函数查询等

## 一、数据库以及表的构建
1、构建demo数据库

2、使用demo数据库

3、先删除demo中可能已经存在的构建目标表

4、建表，主要是三个：
	1. users用户表：包含字段为用户id，用户名称，用户所在地区，用户注册时间
	2. products商品表：包含字段为商品id，商品名称，商品品类，商品价格
	3. orders订单表：包含字段为订单id，下单用户id，下单商品id，购买数量，成交金额，下单渠道，订单状态（**在计算GMV时只考虑已付款的情况（已取消、已退款不计算在内）**），下单时间

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
```MySQL

```

（4）地区品类交叉GMV占比分析
```MySQL

```

## 三、**基于MySQL查询分析得出的结论**













