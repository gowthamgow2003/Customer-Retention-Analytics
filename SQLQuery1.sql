
USE CustomerSegmentationDB;
GO

select * from CustomerSegmentationDB.INFORMATION_SCHEMA.COLUMNS;

select  * from dbo.olist_products_dataset;
select  * from dbo.product_category_name_translation;
select top 10 * from dbo.olist_order_payments_dataset;
select  * from dbo.olist_order_reviews_dataset;
select  * from dbo.olist_order_items_dataset
select  * from dbo.olist_sellers_dataset;
select  * from dbo.olist_geolocation_dataset;
select  * from dbo.olist_customers_dataset;
select  top 10 * from dbo.olist_orders_dataset;


select count(*) from dbo.olist_products_dataset;

select distinct product_category_name from dbo.olist_products_dataset;
select  distinct geolocation_city from dbo.olist_geolocation_dataset;
select  distinct payment_type from dbo.olist_order_payments_dataset;


EXEC sp_rename 'dbo.product_category_name_translation.column1', 'Product_name_brazil', 'COLUMN';
EXEC sp_rename 'dbo.product_category_name_translation.column2', 'Product_name_English', 'COLUMN';

select  * from dbo.olist_products_dataset pd 
left join dbo.product_category_name_translation pt 
on pt.Product_name_brazil=pd.product_category_name;

--FactSales

ALTER VIEW dbo.FactSales AS
SELECT
    o.order_id,
    o.customer_id,
    oi.product_id,
    oi.seller_id,

    CAST(o.order_purchase_timestamp AS DATE) AS OrderDate,
    CAST(o.order_delivered_carrier_date AS DATE) AS Order_delivered_carrier_date, 
    CAST(o.order_estimated_delivery_date AS DATE) AS Order_estimate_date,
    CAST(o.order_delivered_customer_date AS DATE) AS Order_delivered_To_customer_date,
    CAST(o.order_approved_at AS DATE) As Order_approved_date,
    o.order_status,
    oi.price,
    oi.freight_value,

    pay.payment_type,
    pay.payment_installments,
    pay.payment_value,

    r.review_score

FROM dbo.olist_orders_dataset o

LEFT JOIN dbo.olist_order_items_dataset oi
    ON o.order_id = oi.order_id

LEFT JOIN dbo.olist_order_payments_dataset pay
    ON o.order_id = pay.order_id

LEFT JOIN dbo.olist_order_reviews_dataset r
    ON o.order_id = r.order_id;

--DimCustomer

CREATE VIEW dbo.DimCustomer AS
SELECT DISTINCT

    customer_id,
    customer_unique_id,
    customer_city,
    customer_state

FROM dbo.olist_customers_dataset;

--DimProduct

CREATE VIEW dbo.DimProduct AS
SELECT DISTINCT

    product_id,
    product_category_name,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm

FROM dbo.olist_products_dataset;

--DimSeller
CREATE VIEW dbo.DimSeller AS
SELECT DISTINCT

    seller_id,
    seller_city,
    seller_state

FROM dbo.olist_sellers_dataset;

--DimDate
ALTER VIEW dbo.DimDate AS
SELECT DISTINCT

    CAST(order_purchase_timestamp AS DATE) AS OrderDate,
    CAST(order_delivered_carrier_date AS DATE) AS Order_delivered_carrier_date, 
    CAST(order_estimated_delivery_date AS DATE) AS Order_estimate_date,
    CAST(order_delivered_customer_date AS DATE) AS Order_delivered_To_customer_date,
    CAST(order_approved_at AS DATE) As Order_approved_date,

    YEAR(order_purchase_timestamp) AS Year,

    MONTH(order_purchase_timestamp) AS MonthNumber,

    DATENAME(MONTH, order_purchase_timestamp) AS MonthName,

    DATEPART(QUARTER, order_purchase_timestamp) AS QUARTER,
    
    order_id

FROM dbo.olist_orders_dataset

ALTER VIEW dbo.DimProduct AS
SELECT DISTINCT

    PD.product_id,
    PD.product_category_name,
    PD.product_weight_g,
    PD.product_length_cm,
    PD.product_height_cm,  
    PD.product_width_cm,
    PDT.Product_name_English

FROM dbo.olist_products_dataset PD
Left Join dbo.product_category_name_translation PDT on pd.product_category_name = PDT.Product_name_brazil;

SELECT TOP 10 *
FROM dbo.DimProduct;

--All General KPIs for the Business:

select 'Total Sales' as measure_name, Round(SUM(price),2) as measure_value
FROM dbo.FactSales
union all
select 'Avg Price' as measure_name, Round(AVG(price),2) as measure_value
FROM dbo.FactSales
union all
select 'Total Orders' as measure_name, count(Distinct order_id) as measure_value
FROM dbo.FactSales
union all
select 'Total Products' as measure_name, count(Distinct product_id) as measure_value
FROM dbo.FactSales
union all
select 'Total Customers' as measure_name, count(Distinct customer_id) as measure_value
FROM dbo.FactSales
union all
select 'Total Sellers' as measure_name, count(Distinct seller_id) as measure_value
FROM dbo.FactSales

-- Magnitude Analysis:

--Total Sales by Customers
Select Top 5 C.customer_id, Round(Sum(price),2) as Total_Sales from dbo.DimCustomer C 
left join dbo.FactSales S on C.customer_id=S.customer_id
group by C.customer_id
order by Total_Sales DESC;


-- Total Customers by State
Select Top 5 customer_state,Count(Distinct customer_id) as Total_Customers from dbo.DimCustomer
group by customer_state
order by Total_Customers DESC;

---- Total Products by Category

Select Top 5 Product_name_English,Count(Distinct product_id) as Total_Products from dbo.DimProduct
group by Product_name_English
order by Total_Products DESC;

---- Top Sales by Product Category

Select Top 5 P.Product_name_English,Round(Sum(price),2) as Total_Products from dbo.DimProduct P
left join dbo.FactSales S on S.product_id = P.product_id
group by P.Product_name_English 
order by Total_Products DESC;

---- High Freight_Value Products by Product Category

Select Top 5 P.Product_name_English,Round(Sum(S.freight_value),2) as Total_Freight_Value from dbo.DimProduct P
left join dbo.FactSales S on S.product_id = P.product_id
group by P.Product_name_English 
order by Total_Freight_Value DESC;

---- Top Sales by City and State

Select Top 5 customer_city,customer_state,Round(Sum(price),2) as Total_Products from dbo.FactSales S
left join dbo.DimCustomer C on C.customer_id=S.customer_id 
group by customer_city,customer_state
order by Total_Products DESC;

-- Check Duplicate Values:

with Dup_val as
    (
        select order_id,product_id,seller_id,customer_id, 
        ROW_NUMBER() over(Partition by order_id,product_id,seller_id,customer_id ORDER BY order_id) as rnk from dbo.FactSales 
    )

Select * from Dup_val where rnk > 1;


--- Sales Performance by over time:

Select Year(OrderDate) as Order_year,Round(Sum(price),2) as Total_Sales,
count(Distinct customer_id) as Total_customers,
Count(Distinct product_id) as Total_Products,
count(Distinct seller_id) as Total_sellers
from dbo.FactSales
Group by Year(OrderDate)
Order by Order_year;

-- Changes over time analysis

-- Total Sales per month
Select Datetrunc(month, OrderDate) as Order_Date,Round(Sum(price),2) as Total_Sales
from dbo.FactSales  
where OrderDate is not null
Group by Datetrunc(month, OrderDate)
Order by Order_Date;

-- Cumulative Analysis

-- The running total of Sales over time

select Order_Date,Total_Sales,sum(Total_Sales) over (order by Order_Date) as Running_total_sales,
avg(Total_Sales) over (order by Order_Date) as Running_avg_sales
from 
    (Select Datetrunc(Year, OrderDate) as Order_Date,Round(Sum(price),2) as Total_Sales
    from dbo.FactSales  
    where OrderDate is not null
    Group by Datetrunc(Year, OrderDate)
    Order by Order_Date) DT

-- Performance Analysis
with Per_Pro AS 
        (Select Datetrunc(Year, OrderDate) as Order_Date,P.Product_name_English,Round(Sum(price),2) as Current_sales
        from dbo.FactSales S
        left join dbo.DimProduct P on S.product_id = P.product_id
        where OrderDate is not null
        Group by Datetrunc(Year, OrderDate),P.Product_name_English
        )
select Order_Date,Product_name_English,Current_sales,
avg(Current_sales) over(partition by Product_name_English) as Avg_sales,
Current_sales - avg(Current_sales) over(partition by Product_name_English) as Diff_avg,
case when Current_sales - avg(Current_sales) over(partition by Product_name_English) > 0 Then 'Above Avg'
     when Current_sales - avg(Current_sales) over(partition by Product_name_English) < 0 Then 'Below Avg'
     Else 'Avg'
    End as Avg_change,
Lag(Current_sales) over (partition by Product_name_English order by Order_Date) as Py_sales,
Current_sales - Lag(Current_sales) over (partition by Product_name_English order by Order_Date) as Py_diff,
case when Lag(Current_sales) over (partition by Product_name_English order by Order_Date) > 0 Then 'Increase'
     when Lag(Current_sales) over (partition by Product_name_English order by Order_Date) < 0 Then 'Decrease'
     Else 'Avg'
End As Py_change
from Per_Pro
where Product_name_English is not null;

--Categories contribute the most to overall sales:

With category_sales As 
(
        select Product_name_English,sum(price) as Tota_Sales from dbo.FactSales S 
        left join dbo.DimProduct P on S.product_id=P.product_id
        Group by Product_name_English
)
Select Product_name_English,Tota_Sales,sum(Tota_Sales) over() Overall_Sales,
CONCAT(Round((cast(Tota_Sales As float)/sum(Tota_Sales) over())*100 ,2), '%')as Percentage
from category_sales
order by Tota_Sales desc;

-- Handle NULL Values

--DateTable
SELECT
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) PurchaseDate_Nulls,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) DeliveredDate_Nulls,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) ApprovedDate_Nulls,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) Status_Nulls
FROM dbo.olist_orders_dataset;

--Product Table
SELECT
SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) CategoryNulls,
SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) WeightNulls,
SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END) LengthNulls,
SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END) HeightNulls,
SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END) WidthNulls
FROM dbo.olist_products_dataset;

--Replace NULL Category
UPDATE dbo.olist_products_dataset
SET product_category_name='Unknown'
WHERE product_category_name IS NULL;

--Replace Nulls in Product Weight Column
UPDATE dbo.olist_products_dataset
SET product_weight_g=
(
SELECT AVG(product_weight_g)
FROM dbo.olist_products_dataset
)
WHERE product_weight_g IS NULL;

--Replace Nulls in Product Length Column

UPDATE dbo.olist_products_dataset
SET product_length_cm=
(
SELECT AVG(product_length_cm)
FROM dbo.olist_products_dataset
)
WHERE product_length_cm IS NULL;

----Top Customers by Revenue
SELECT TOP 10
    C.customer_unique_id,
    C.customer_city,
    C.customer_state,
    COUNT(DISTINCT S.order_id) AS Total_Orders,
    ROUND(SUM(S.price),2) AS Total_Revenue
FROM dbo.FactSales S
LEFT JOIN dbo.DimCustomer C
    ON S.customer_id = C.customer_id
GROUP BY
    C.customer_unique_id,
    C.customer_city,
    C.customer_state
ORDER BY Total_Revenue DESC;

---Customer Segmentation

SELECT
    C.customer_unique_id,
    COUNT(DISTINCT S.order_id) AS Total_Orders,
    ROUND(SUM(S.price),2) AS Total_Revenue,

    CASE
        WHEN COUNT(DISTINCT S.order_id)=1
            THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS Customer_Type

FROM dbo.FactSales S
LEFT JOIN dbo.DimCustomer C
    ON S.customer_id=C.customer_id

GROUP BY
    C.customer_unique_id

ORDER BY Total_Revenue DESC;

-- Number of Repeat vs One-Time Customers
WITH CustomerOrders AS
(
    SELECT
        C.customer_unique_id,
        COUNT(DISTINCT S.order_id) AS Total_Orders
    FROM dbo.FactSales S
    LEFT JOIN dbo.DimCustomer C
        ON S.customer_id=C.customer_id
    GROUP BY C.customer_unique_id
)

SELECT
    CASE
        WHEN Total_Orders=1
            THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END AS Customer_Type,

    COUNT(*) AS Total_Customers

FROM CustomerOrders

GROUP BY
    CASE
        WHEN Total_Orders=1
            THEN 'One-Time Customer'
        ELSE 'Repeat Customer'
    END;

--Revenue by Payment Type

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS Total_Orders,
    ROUND(SUM(payment_value),2) AS Total_Revenue
FROM dbo.FactSales
GROUP BY payment_type
ORDER BY Total_Revenue DESC;

--Payment Installments Analysis
SELECT
    payment_type,
    ROUND(AVG(payment_installments),2) AS Avg_Installments,
    MAX(payment_installments) AS Max_Installments,
    MIN(payment_installments) AS Min_Installments
FROM dbo.FactSales
GROUP BY payment_type
ORDER BY Avg_Installments DESC;

-- Distribution of Installments
SELECT
    payment_installments,
    COUNT(*) AS Total_Orders,
    ROUND(SUM(payment_value),2) AS Revenue
FROM dbo.FactSales
GROUP BY payment_installments
ORDER BY payment_installments;


-- Average Payment by Payment Type
SELECT
    payment_type,
    ROUND(AVG(payment_value),2) AS Average_Payment
FROM dbo.FactSales
GROUP BY payment_type
ORDER BY Average_Payment DESC;

-- Highest Payment Orders
SELECT TOP 10
    order_id,
    customer_id,
    payment_type,
    payment_value
FROM dbo.FactSales
ORDER BY payment_value DESC;

-- Payment Type Contribution %

WITH PaymentRevenue AS
(
     SELECT top 10
        payment_type,
        SUM(payment_value) AS Total_Revenue
    FROM dbo.FactSales
    GROUP BY payment_type
)

SELECT
    payment_type,
    ROUND(Total_Revenue,2) AS Total_Revenue,
    ROUND(
        Total_Revenue * 100.0 /
        SUM(Total_Revenue) OVER(),
        2
    ) AS Revenue_Percentage
FROM PaymentRevenue
where payment_type is not null
ORDER BY Total_Revenue DESC;



select * FROM dbo.DimDate;


-- RFM query


WITH CustomerRFM AS
(
    SELECT
        C.customer_unique_id,

        MAX(S.OrderDate) AS Last_Purchase_Date,

        DATEDIFF(
            DAY,
            MAX(S.OrderDate),
            (SELECT MAX(OrderDate) FROM dbo.FactSales)
        ) AS Recency,

        COUNT(DISTINCT S.order_id) AS Frequency,

        ROUND(SUM(ISNULL(S.price,0)),2) AS Monetary,

        ROUND(SUM(ISNULL(S.price,0)),2) AS Total_Revenue,

        COUNT(DISTINCT S.order_id) AS Total_Orders

    FROM dbo.FactSales S
    LEFT JOIN dbo.DimCustomer C
        ON S.customer_id = C.customer_id

    GROUP BY
        C.customer_unique_id
),

RFMScore AS
(
    SELECT

        customer_unique_id,
        Last_Purchase_Date,
        Recency,
        Frequency,
        Monetary,
        Total_Revenue,
        Total_Orders,

        -- Lower Recency = Better
        6 - NTILE(5) OVER(ORDER BY Recency DESC) AS R_Score,

        -- Higher Frequency = Better
        NTILE(5) OVER(ORDER BY Frequency ASC) AS F_Score,

        -- Higher Monetary = Better
        NTILE(5) OVER(ORDER BY Monetary ASC) AS M_Score

    FROM CustomerRFM
)

SELECT

    customer_unique_id,

    Last_Purchase_Date,

    Recency,

    Frequency,

    Monetary,

    Total_Revenue,

    Total_Orders,

    R_Score,

    F_Score,

    M_Score,

    CONCAT(R_Score,F_Score,M_Score) AS RFM_Score,

    CASE

        WHEN R_Score >= 4
         AND F_Score >= 4
         AND M_Score >= 4
            THEN 'Champions'

        WHEN R_Score >= 4
         AND F_Score >= 4
            THEN 'Loyal Customers'

        WHEN R_Score >= 4
         AND F_Score >= 3
            THEN 'Potential Loyalists'

        WHEN R_Score = 5
         AND F_Score = 1
            THEN 'New Customers'

        WHEN R_Score >= 3
         AND F_Score <= 2
            THEN 'Promising'

        WHEN R_Score = 2
         AND F_Score >= 3
            THEN 'Need Attention'

        WHEN R_Score = 1
         AND F_Score >= 4
            THEN 'At Risk'

        WHEN R_Score = 1
         AND F_Score <= 2
            THEN 'Lost Customers'

        ELSE 'Hibernating'

    END AS Customer_Segment

FROM RFMScore

ORDER BY
    Monetary DESC;