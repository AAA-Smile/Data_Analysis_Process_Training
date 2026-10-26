# 先将需要分析的表格使用MySQL构建起来
编写一个SQL脚本运行，其中包含建表，插入数据，查询操作，构建三合一表格等相关操作；主要涉及到普通查询，窗口函数查询等
## 数据库以及表的构建
1、构建demo数据库

2、使用demo数据库

3、先删除demo中可能已经存在的构建目标表

4、建表，主要是三个：
	1. users用户表：包含字段为用户id，用户名称，用户所在地区，用户注册时间
	2. products商品表：包含字段为商品id，商品名称，商品品类，商品价格
	3. orders订单表：包含字段为订单id，下单用户id，下单商品id，购买数量，成交金额，下单渠道，订单状态（**在计算GMV时只考虑已付款的情况（已取消、已退款不计算在内）**），下单时间

5、接下来我们模拟插入些数据进去，用户表10行，商品表8行，订单表66行
## 查询操作
1、按周统计GMV，订单数，客单价

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
2、按月统计GMV，订单数，客单价
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
3、







