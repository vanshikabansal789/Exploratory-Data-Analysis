CREATE DATABASE IF NOT EXISTS food_delivery;
USE food_delivery;

CREATE TABLE customers (
    customer_id    VARCHAR(10),
    customer_name  VARCHAR(100),
    city           VARCHAR(50),
    phone          VARCHAR(15),
    email          VARCHAR(100),
    joined_date    DATE
);

CREATE TABLE restaurants (
    restaurant_id    VARCHAR(10),
    restaurant_name  VARCHAR(100),
    city             VARCHAR(50),
    cuisine          VARCHAR(50),
    rating           DECIMAL(3,1),
    avg_cost_for_two INT
);
CREATE TABLE orders (
    order_id        VARCHAR(10),
    customer_id     VARCHAR(10),
    restaurant_id   VARCHAR(10),
    order_date      DATE,
    order_status    VARCHAR(20),
    payment_method  VARCHAR(30),
    total_amount    DECIMAL(10,2)
);

CREATE TABLE order_items (
    item_id       VARCHAR(10),
    order_id      VARCHAR(10),
    product_name  VARCHAR(100),
    category      VARCHAR(50),
    quantity      INT,
    unit_price    DECIMAL(10,2)
);

CREATE TABLE delivery (
    delivery_id       VARCHAR(10),
    order_id          VARCHAR(10),
    delivery_partner  VARCHAR(100),
    pickup_time       DATETIME,
    delivered_time    DATETIME,
    delivery_minutes  INT,
    delivery_status   VARCHAR(20)
);
select *
from customers;
Select *
from orders;
Select*
from delivery;
Select *
from order_items;
Select *
from restaurants;
SELECT COUNT(*) AS total_customers   FROM customers;
SELECT COUNT(*) AS total_restaurants FROM restaurants;
SELECT COUNT(*) AS total_orders      FROM orders;
SELECT COUNT(*) AS total_items       FROM order_items;
SELECT COUNT(*) AS total_deliveries  FROM delivery;

-- 1. Find the total number of orders,total revenue, and average order value — but only for delivered orders?
Select count(o.order_id) as total_orders
from orders o
where o.order_status="delivered";

select sum(o.total_amount) as total_revenue
from orders o
where o.order_status="delivered";

Select Round(avg(o.total_amount),2) as Avg_order_value
from orders o
where order_status="delivered";

-- 2. Which city is driving the most revenue?
Select r.city, sum(o.total_amount) as total_revenue
from restaurants r Left JOIN orders o ON r.restaurant_id=o.restaurant_id
where o.order_status="delivered"
Group by r.city
order by total_revenue desc;

-- USING WINDOW FUNCTION & CTE
With CTE as (Select r.city, sum(o.total_amount) as total_revenue, RANK () over (order by sum(o.total_amount) DESC) as revenue_rank
             from restaurants r JOIN orders o ON r.restaurant_id=o.restaurant_id
             where o.order_status="delivered"
             group by r.city )
Select *
from CTE
where revenue_rank = 1;

-- 3. Which 3 cities are driving the most revenue
With CTE as (Select r.city, sum(o.total_amount) as total_revenue, RANK () over (order by sum(o.total_amount) DESC) as revenue_rank
             from restaurants r JOIN orders o ON r.restaurant_id=o.restaurant_id
             where o.order_status="delivered"
             group by r.city )
Select *
from CTE
where revenue_rank <=3;

-- 4. Which top 5 restaurants are driving the most revenue
With CTE as (Select r.restaurant_name, sum(o.total_amount) as total_revenue, rank () over (order by sum(o.total_amount) desc) as revenue_rank
			 from restaurants r join orders o ON r.restaurant_id = o.restaurant_id
             where order_status="delivered"
             group by r.restaurant_name)
select *
from CTE
where revenue_rank<=5;

-- 5. Is the business growing each month & if yes, then by how much %?
with Monthly_revenue as (Select DATE_FORMAT(order_date, '%Y-%m') as month, sum(total_amount) as revenue
                         from orders
                         where order_status="delivered"
						 group by month
                         order by month),
revenue_with_LAG as (select month, revenue, LAG (revenue) over (order by month) as prev_month_revenue
from monthly_revenue)
Select month, revenue, prev_month_revenue, Concat(Round(((revenue-prev_month_revenue)/prev_month_revenue)*100,1),'%') as growth
from revenue_with_LAG;
-- Business hows inconsistent month on month growth with no clear upward trend

-- 6. The company would like to investigvate the factors behind a negative growth in March'23.
-- let's start with order counts in Feb'23 vs Mar'23
select DATE_FORMAT(order_date, '%Y-%m') as month, count(order_id) as order_count
from orders
where DATE_FORMAT(order_date, '%Y-%m') IN ('2023-02' , '2023-03')
group by month
order by month;
-- so the order count declined in Mar'23. Less demand is one reason.
-- Let's now look at AOV
select DATE_FORMAT(order_date, '%Y-%m') as month, avg(total_amount) as Average_order_value
from orders
where DATE_FORMAT(order_date, '%Y-%m') IN ('2023-02' , '2023-03')
and order_status='delivered'
group by month
order by month;
-- AOV by city to deep dive further
Select r.city, DATE_FORMAT(o.order_date, '%Y-%m') as month, avg(o.total_amount) as Average_order_value
from restaurants r JOIN orders o ON  r.restaurant_id=o.restaurant_id
where DATE_FORMAT(o.order_date, '%Y-%m') IN ('2023-02' , '2023-03')
and order_status='delivered'
group by month, r.city
order by month;
-- AOV % decrease/increase by city
With AOV_BY_CITY as (Select r.city, DATE_FORMAT(o.order_date, '%Y-%m') as month, avg(o.total_amount) as Average_order_value
                     from restaurants r JOIN orders o ON  r.restaurant_id=o.restaurant_id
					 where DATE_FORMAT(o.order_date, '%Y-%m') IN ('2023-02' , '2023-03')
                     and order_status='delivered'
                     group by month, r.city
                     order by month),
PrevAOV as (Select city, month, Average_order_value, LAG(Average_order_value) OVER (PARTITION BY city ORDER BY month) as prev_month_AOV
from AOV_BY_CITY)
Select city, ((Average_order_value-prev_month_AOV)/prev_month_AOV)*100 as percent_change_in_AOV
from PrevAOV
where month='2023-03';
-- Bangalore is clearly the most affected city.

-- 7. Who are our top 10 customers by spend
with CTE as (select c.customer_id, c.customer_name, sum(o.total_amount) as total_spend , rank () over (order by sum(o.total_amount) DESC)as rnk
from customers c JOIN orders o ON c.customer_id=o.customer_id
group by c.customer_id, c.customer_name)
select *
from CTE
where rnk<=10;

-- 8. What % of customers are repeat customers i.e. customers ordered more than once
with order_count as (select customer_id, count(customer_id) as no_of_times_ordered
from orders o
where order_status='delivered'
group by customer_id)
SELECT 
    CASE
        WHEN no_of_times_ordered = 1  THEN '1 order (one-time)'
        WHEN no_of_times_ordered <= 3 THEN '2-3 orders'
        WHEN no_of_times_ordered <= 6 THEN '4-6 orders'
        ELSE '7+ orders (loyal)'
    END AS customer_segment,
    COUNT(*) AS total_customers,
    ROUND(COUNT(*) * 100.0 
          / SUM(COUNT(*)) OVER(), 1) AS pct_of_total
FROM order_count
GROUP BY customer_segment
ORDER BY total_customers DESC;

