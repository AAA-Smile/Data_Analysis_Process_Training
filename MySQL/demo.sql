-- ============================================================
-- 数据分析刻意练习 Week1：MySQL 8.0+ / DataGrip
-- 说明：脚本可重复执行，会先删除旧表
-- ============================================================

CREATE DATABASE IF NOT EXISTS demo DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE demo;

DROP TABLE IF EXISTS dw_order_wide;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS users;

-- ============================================================
-- 一、建表
-- ============================================================

CREATE TABLE users (
    user_id       INT PRIMARY KEY,
    user_name     VARCHAR(50),
    region        VARCHAR(20),
    register_time DATETIME
);

CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100),
    category     VARCHAR(30),
    price        DECIMAL(10,2)
);

CREATE TABLE orders (
    order_id    INT PRIMARY KEY,
    user_id     INT,
    product_id  INT,
    quantity    INT,
    amount      DECIMAL(10,2),
    channel     VARCHAR(20),
    status      VARCHAR(20),
    order_time  DATETIME
);

-- ============================================================
-- 二、模拟数据
-- 口径：GMV = status='paid' 的 amount 之和
--       订单数 = COUNT(DISTINCT order_id)
--       客单价 = GMV / 订单数
-- ============================================================

INSERT INTO users (user_id, user_name, region, register_time) VALUES
(1,'张三','华东','2024-01-05 09:00:00'),
(2,'李四','华南','2024-02-10 10:00:00'),
(3,'王五','华北','2024-03-15 11:00:00'),
(4,'赵六','华东','2024-04-20 12:00:00'),
(5,'钱七','华南','2024-05-25 13:00:00'),
(6,'孙八','华北','2024-06-30 14:00:00'),
(7,'周九','西南','2024-07-05 15:00:00'),
(8,'吴十','华东','2024-08-10 16:00:00'),
(9,'郑一','华南','2024-09-15 17:00:00'),
(10,'王二','华北','2024-10-20 18:00:00');

INSERT INTO products (product_id, product_name, category, price) VALUES
(101,'手机','数码',3999.00),
(102,'耳机','数码',499.00),
(103,'衬衫','服饰',199.00),
(104,'运动鞋','服饰',599.00),
(105,'坚果礼盒','食品',129.00),
(106,'咖啡','食品',89.00),
(107,'台灯','家居',159.00),
(108,'背包','服饰',299.00);

-- 订单数据覆盖 2025-01 到 2026-10，每月 3 单，共 66 单
-- 其中少量 cancelled / refunded，用于练习状态过滤
INSERT INTO orders
(order_id, user_id, product_id, quantity, amount, channel, status, order_time) VALUES
(1001, 1, 101, 1, 3999.00, 'App',   'paid',      '2025-01-05 10:00:00'),
(1002, 3, 103, 2,  398.00, '小程序','paid',      '2025-01-12 14:30:00'),
(1003, 5, 105, 3,  387.00, 'PC',    'paid',      '2025-01-25 19:00:00'),
(1004, 2, 102, 2,  998.00, 'App',   'paid',      '2025-02-05 10:00:00'),
(1005, 4, 104, 1,  599.00, '小程序','paid',      '2025-02-12 14:30:00'),
(1006, 6, 106, 3,  267.00, 'PC',    'paid',      '2025-02-25 19:00:00'),
(1007, 3, 101, 1, 3999.00, '小程序','paid',      '2025-03-05 10:00:00'),
(1008, 5, 108, 2,  598.00, 'App',   'paid',      '2025-03-12 14:30:00'),
(1009, 7, 107, 3,  477.00, 'PC',    'cancelled', '2025-03-25 19:00:00'),
(1010, 4, 102, 1,  499.00, 'PC',    'paid',      '2025-04-05 10:00:00'),
(1011, 6, 103, 3,  597.00, 'App',   'paid',      '2025-04-12 14:30:00'),
(1012, 8, 105, 2,  258.00, '小程序','paid',      '2025-04-25 19:00:00'),
(1013, 5, 101, 2, 7998.00, 'App',   'paid',      '2025-05-05 10:00:00'),
(1014, 7, 104, 1,  599.00, '小程序','paid',      '2025-05-12 14:30:00'),
(1015, 9, 106, 5,  445.00, 'PC',    'paid',      '2025-05-25 19:00:00'),
(1016, 6, 102, 1,  499.00, '小程序','paid',      '2025-06-05 10:00:00'),
(1017, 8, 108, 2,  598.00, 'App',   'paid',      '2025-06-12 14:30:00'),
(1018,10, 107, 2,  318.00, 'PC',    'paid',      '2025-06-25 19:00:00'),
(1019, 7, 101, 1, 3999.00, 'PC',    'paid',      '2025-07-05 10:00:00'),
(1020, 9, 103, 2,  398.00, 'App',   'paid',      '2025-07-12 14:30:00'),
(1021, 1, 105, 3,  387.00, '小程序','paid',      '2025-07-25 19:00:00'),
(1022, 8, 102, 2,  998.00, 'App',   'paid',      '2025-08-05 10:00:00'),
(1023,10, 104, 1,  599.00, '小程序','paid',      '2025-08-12 14:30:00'),
(1024, 2, 106, 3,  267.00, 'PC',    'refunded',  '2025-08-25 19:00:00'),
(1025, 9, 101, 1, 3999.00, '小程序','paid',      '2025-09-05 10:00:00'),
(1026, 1, 108, 2,  598.00, 'App',   'paid',      '2025-09-12 14:30:00'),
(1027, 3, 107, 3,  477.00, 'PC',    'paid',      '2025-09-25 19:00:00'),
(1028,10, 102, 1,  499.00, 'PC',    'paid',      '2025-10-05 10:00:00'),
(1029, 2, 103, 3,  597.00, 'App',   'paid',      '2025-10-12 14:30:00'),
(1030, 4, 105, 2,  258.00, '小程序','paid',      '2025-10-25 19:00:00'),
(1031, 1, 101, 2, 7998.00, 'App',   'paid',      '2025-11-05 10:00:00'),
(1032, 3, 104, 1,  599.00, '小程序','paid',      '2025-11-12 14:30:00'),
(1033, 5, 106, 4,  356.00, 'PC',    'paid',      '2025-11-25 19:00:00'),
(1034, 2, 102, 1,  499.00, '小程序','paid',      '2025-12-05 10:00:00'),
(1035, 4, 108, 2,  598.00, 'App',   'paid',      '2025-12-12 14:30:00'),
(1036, 6, 107, 2,  318.00, 'PC',    'paid',      '2025-12-25 19:00:00'),
(1037, 3, 101, 1, 3999.00, 'PC',    'paid',      '2026-01-05 10:00:00'),
(1038, 5, 103, 2,  398.00, 'App',   'paid',      '2026-01-12 14:30:00'),
(1039, 7, 105, 3,  387.00, '小程序','cancelled', '2026-01-25 19:00:00'),
(1040, 4, 102, 2,  998.00, 'App',   'paid',      '2026-02-05 10:00:00'),
(1041, 6, 104, 1,  599.00, '小程序','paid',      '2026-02-12 14:30:00'),
(1042, 8, 106, 3,  267.00, 'PC',    'paid',      '2026-02-25 19:00:00'),
(1043, 5, 101, 1, 3999.00, '小程序','paid',      '2026-03-05 10:00:00'),
(1044, 7, 108, 2,  598.00, 'App',   'paid',      '2026-03-12 14:30:00'),
(1045, 9, 107, 3,  477.00, 'PC',    'paid',      '2026-03-25 19:00:00'),
(1046, 6, 102, 1,  499.00, 'PC',    'paid',      '2026-04-05 10:00:00'),
(1047, 8, 103, 3,  597.00, 'App',   'paid',      '2026-04-12 14:30:00'),
(1048,10, 105, 2,  258.00, '小程序','paid',      '2026-04-25 19:00:00'),
(1049, 7, 101, 2, 7998.00, 'App',   'paid',      '2026-05-05 10:00:00'),
(1050, 9, 104, 1,  599.00, '小程序','paid',      '2026-05-12 14:30:00'),
(1051, 1, 106, 5,  445.00, 'PC',    'paid',      '2026-05-25 19:00:00'),
(1052, 8, 102, 1,  499.00, '小程序','paid',      '2026-06-05 10:00:00'),
(1053,10, 108, 2,  598.00, 'App',   'paid',      '2026-06-12 14:30:00'),
(1054, 2, 107, 2,  318.00, 'PC',    'paid',      '2026-06-25 19:00:00'),
(1055, 9, 101, 1, 3999.00, 'PC',    'paid',      '2026-07-05 10:00:00'),
(1056, 1, 103, 2,  398.00, 'App',   'paid',      '2026-07-12 14:30:00'),
(1057, 3, 105, 3,  387.00, '小程序','paid',      '2026-07-25 19:00:00'),
(1058,10, 102, 2,  998.00, 'App',   'paid',      '2026-08-05 10:00:00'),
(1059, 2, 104, 1,  599.00, '小程序','paid',      '2026-08-12 14:30:00'),
(1060, 4, 106, 3,  267.00, 'PC',    'paid',      '2026-08-25 19:00:00'),
(1061, 1, 101, 1, 3999.00, '小程序','paid',      '2026-09-05 10:00:00'),
(1062, 3, 108, 2,  598.00, 'App',   'paid',      '2026-09-12 14:30:00'),
(1063, 5, 107, 3,  477.00, 'PC',    'paid',      '2026-09-25 19:00:00'),
(1064, 2, 102, 1,  499.00, 'PC',    'paid',      '2026-10-05 10:00:00'),
(1065, 4, 103, 3,  597.00, 'App',   'paid',      '2026-10-12 14:30:00'),
(1066, 6, 105, 2,  258.00, '小程序','paid',      '2026-10-25 19:00:00');

-- ============================================================
-- 三、按月统计 GMV、订单数、客单价
-- ============================================================

SELECT
    DATE_FORMAT(order_time, '%Y-%m') AS month,
    ROUND(SUM(amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS order_cnt,
    ROUND(SUM(amount) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM orders
WHERE status = 'paid'
GROUP BY DATE_FORMAT(order_time, '%Y-%m')
ORDER BY month;

-- ============================================================
-- 四、按周统计（ISO 周：周一开始）
-- ============================================================

SELECT
    DATE_FORMAT(order_time, '%x-%v') AS year_week,
    ROUND(SUM(amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS order_cnt,
    ROUND(SUM(amount) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM orders
WHERE status = 'paid'
GROUP BY DATE_FORMAT(order_time, '%x-%v')
ORDER BY year_week;

-- ============================================================
-- 五、按品类 / 渠道 / 地区分组对比
-- ============================================================

-- 5.1 按品类
SELECT
    p.category,
    ROUND(SUM(o.amount), 2) AS gmv,
    COUNT(DISTINCT o.order_id) AS order_cnt,
    ROUND(SUM(o.amount) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN products p ON o.product_id = p.product_id
WHERE o.status = 'paid'
GROUP BY p.category
ORDER BY gmv DESC;

-- 5.2 按渠道
SELECT
    channel,
    ROUND(SUM(amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS order_cnt,
    ROUND(SUM(amount) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM orders
WHERE status = 'paid'
GROUP BY channel
ORDER BY gmv DESC;

-- 5.3 按地区
SELECT
    u.region,
    ROUND(SUM(o.amount), 2) AS gmv,
    COUNT(DISTINCT o.order_id) AS order_cnt,
    ROUND(SUM(o.amount) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN users u ON o.user_id = u.user_id
WHERE o.status = 'paid'
GROUP BY u.region
ORDER BY gmv DESC;

-- ============================================================
-- 六、窗口函数：按月环比、同比
-- 同比依赖月份连续；本数据集 2025-01 到 2026-10 连续
-- ============================================================

WITH monthly AS (
    SELECT
        DATE_FORMAT(order_time, '%Y-%m') AS month,
        SUM(amount) AS gmv,
        COUNT(DISTINCT order_id) AS order_cnt
    FROM orders
    WHERE status = 'paid'
    GROUP BY DATE_FORMAT(order_time, '%Y-%m')
),
with_lag AS (
    SELECT
        month,
        gmv,
        order_cnt,
        LAG(gmv) OVER (ORDER BY month) AS prev_month_gmv,
        LAG(gmv, 12) OVER (ORDER BY month) AS last_year_gmv
    FROM monthly
)
SELECT
    month,
    gmv,
    prev_month_gmv,
    ROUND((gmv - prev_month_gmv) * 100.0 / NULLIF(prev_month_gmv, 0), 2) AS mom_pct,
    last_year_gmv,
    ROUND((gmv - last_year_gmv) * 100.0 / NULLIF(last_year_gmv, 0), 2) AS yoy_pct
FROM with_lag
ORDER BY month;

-- ============================================================
-- 七、多表 JOIN 出“用户-订单-商品”宽表
-- ============================================================

SELECT
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
FROM orders o
JOIN users u    ON o.user_id = u.user_id
JOIN products p ON o.product_id = p.product_id
ORDER BY o.order_time;

-- ============================================================
-- 八、固化分析宽表（只保留 paid 订单）
-- ============================================================

DROP TABLE IF EXISTS dw_order_wide;

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

-- 验证宽表
SELECT * FROM dw_order_wide ORDER BY order_time LIMIT 10;

-- 基于宽表的示例分析：品类 × 地区 GMV
SELECT
    region,
    category,
    ROUND(SUM(amount), 2) AS gmv,
    COUNT(DISTINCT order_id) AS order_cnt
FROM dw_order_wide
GROUP BY region, category
ORDER BY region, gmv DESC;

-- 基于宽表的分析：用户贡献集中度
WITH user_gmv AS (
    SELECT
        user_id,
        ROUND(SUM(amount), 2) AS gmv,
        COUNT(DISTINCT order_id) AS order_cnt
    FROM dw_order_wide
    GROUP BY user_id
)
SELECT
    user_id,
    gmv,
    order_cnt,
    ROUND(gmv * 100.0 / SUM(gmv) OVER (), 2) AS gmv_pct,
    ROUND(SUM(gmv) OVER (ORDER BY gmv DESC) * 100.0 / SUM(gmv) OVER (), 2) AS cum_pct,
    ROW_NUMBER() OVER (ORDER BY gmv DESC) AS rn
FROM user_gmv
ORDER BY gmv DESC;

-- 周内分布
SELECT
    DAYOFWEEK(order_time) AS dow_num,
    CASE DAYOFWEEK(order_time)
        WHEN 1 THEN '周日' WHEN 2 THEN '周一' WHEN 3 THEN '周二'
        WHEN 4 THEN '周三' WHEN 5 THEN '周四' WHEN 6 THEN '周五'
        WHEN 7 THEN '周六'
    END AS dow_name,
    COUNT(DISTINCT order_id) AS order_cnt,
    ROUND(SUM(amount), 2) AS gmv,
    ROUND(SUM(amount) / COUNT(DISTINCT order_id), 2) AS aov
FROM dw_order_wide
GROUP BY
    DAYOFWEEK(order_time) ,
    CASE DAYOFWEEK(order_time)
        WHEN 1 THEN '周日' WHEN 2 THEN '周一' WHEN 3 THEN '周二'
        WHEN 4 THEN '周三' WHEN 5 THEN '周四' WHEN 6 THEN '周五'
        WHEN 7 THEN '周六'
    END
ORDER BY dow_num;

-- 地区品类交叉
WITH t AS (
    SELECT
        region,
        category,
        ROUND(SUM(amount), 2) AS gmv,
        COUNT(DISTINCT order_id) AS order_cnt
    FROM dw_order_wide
    GROUP BY region, category
)
SELECT
    region,
    category,
    gmv,
    order_cnt,
    ROUND(gmv * 100.0 / SUM(gmv) OVER (PARTITION BY region), 2) AS pct_in_region,
    ROUND(gmv * 100.0 / SUM(gmv) OVER (PARTITION BY category), 2) AS pct_in_category
FROM t
ORDER BY region, gmv DESC;