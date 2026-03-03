USE [Swiggy Database];
GO;

select * from swiggy_data;

--Data Cleaning AND Validation
--Null check
SELECT
SUM(CASE WHEN State IS NULL THEN 1 ELSE 0 END) AS null_state,
SUM(CASE WHEN City IS NULL THEN 1 ELSE 0 END) AS null_city,
SUM(CASE WHEN Order_date IS NULL THEN 1 ELSE 0 END) AS null_orderdate,
SUM(CASE WHEN Restaurant_name IS NULL THEN 1 ELSE 0 END) AS null_restaurantname,
SUM(CASE WHEN Location IS NULL THEN 1 ELSE 0 END) AS null_location,
SUM(CASE WHEN Category IS NULL THEN 1 ELSE 0 END) AS null_category,
SUM(CASE WHEN Dish_Name IS NULL THEN 1 ELSE 0 END) AS null_dishname,
SUM(CASE WHEN Price_INR IS NULL THEN 1 ELSE 0 END) AS null_price,
SUM(CASE WHEN Rating IS NULL THEN 1 ELSE 0 END) AS null_rating,
SUM(CASE WHEN Rating_count IS NULL THEN 1 ELSE 0 END) AS null_ratingcount
FROM swiggy_data;

--Blank or Empty Strings
SELECT * 
FROM swiggy_data
WHERE State=' ' OR City=' ' OR Restaurant_Name=' ' OR Location=' ' OR Category=' ' 
OR Dish_Name=' ';

--Duplication Detection
SELECT CITY,ORDER_DATE,RESTAURANT_NAME,LOCATION,CATEGORY,
DISH_NAME,PRICE_INR,RATING,RATING_COUNT,COUNT(*) AS COUNT
FROM swiggy_data
GROUP BY CITY,ORDER_DATE,RESTAURANT_NAME,LOCATION,CATEGORY,
DISH_NAME,PRICE_INR,RATING,RATING_COUNT
HAVING COUNT(*)>1;

--REMOVAL OF DUPLICATION
;WITH CTE AS(
 SELECT *,ROW_NUMBER() OVER(PARTITION BY CITY,ORDER_DATE,RESTAURANT_NAME,LOCATION,CATEGORY,
DISH_NAME,PRICE_INR,RATING,RATING_COUNT 
ORDER BY(SELECT NULL)
) AS RN
FROM swiggy_data
)
DELETE FROM CTE WHERE RN>1;
DROP TABLE IF EXISTS fact_swiggy_orders;
DROP TABLE IF EXISTS dim_dish;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_restaurant;
DROP TABLE IF EXISTS dim_location;
DROP TABLE IF EXISTS dim_date;
--Dimension Tables
--Date Table
CREATE TABLE dim_date(
Date_Id INT IDENTITY(1,1) PRIMARY KEY,
Full_Date DATE,
Year INT,
Month INT,
Month_name varchar(20),
Quarter INT,
Day INT,
Week INT
);

CREATE TABLE dim_location(
Location_Id INT IDENTITY(1,1) PRIMARY KEY,
State VARCHAR(100),
City VARCHAR(100),
Location VARCHAR(200)
);
CREATE TABLE dim_restaurant(
Restaurant_Id INT IDENTITY(1,1) PRIMARY KEY,
Restaurant_name VARCHAR(200)
);

CREATE TABLE dim_category(
Category_Id INT IDENTITY(1,1) PRIMARY KEY,
Category VARCHAR(200)
);

CREATE TABLE dim_dish(
Dish_Id INT IDENTITY(1,1) PRIMARY KEY,
Dish_Name VARCHAR(200)		
);

--FACT TABLE
CREATE TABLE fact_swiggy_orders(
order_id INT IDENTITY(1,1) PRIMARY KEY,

Date_Id INT,
Price_INR DECIMAL(10,2),
Rating DECIMAL(4,2),
Rating_count INT,

Location_Id INT,
Restaurant_Id INT,
Category_Id INT,
Dish_Id INT,

FOREIGN KEY (Date_Id) REFERENCES dim_date(Date_Id),
FOREIGN KEY (Location_Id) REFERENCES dim_location(Location_Id),
FOREIGN KEY (Restaurant_Id) REFERENCES dim_restaurant(Restaurant_Id),
FOREIGN KEY (Category_Id) REFERENCES dim_category(Category_Id),
FOREIGN KEY (Dish_Id) REFERENCES dim_dish(Dish_Id)
);

SELECT * FROM fact_swiggy_orders;

--INSER DATA INTO TABLES
--dim_date

INSERT INTO dim_date(Full_Date, Year, Month, Month_name, Quarter, Day, Week)
SELECT DISTINCT 
   Order_Date,
   Year(Order_Date),
   Month(Order_Date),
   DATENAME(Month,Order_Date),
   DATEPART(Quarter, Order_Date),
   Day(Order_Date),
   DATEPART(Week,Order_Date)
FROM swiggy_data
WHERE Order_Date IS NOT NULL;

select * from dim_date;

--dim_location
INSERT INTO dim_location(State, City, Location)
SELECT DISTINCT
   State,  
   City,
   Location
From swiggy_data

select * from dim_location;

--dim_restaurant
INSERT INTO dim_restaurant(Restaurant_name)
SELECT DISTINCT
   Restaurant_name
FROM swiggy_data;

SELECT * from dim_restaurant;

--dim_category
INSERT INTO dim_category(Category)
SELECT DISTINCT
   Category
FROM swiggy_data;

SELECT * from dim_category;

--dim_dish
INSERT INTO dim_dish(Dish_Name)
SELECT DISTINCT
   Dish_name
FROM swiggy_data;

SELECT * from dim_dish;

--INSERT VALUES INTO FACT TABLE

INSERT INTO fact_swiggy_orders
(
Date_Id,
Price_INR,
Rating,
Rating_count,
Location_Id,
Restaurant_Id,
Category_Id,
Dish_Id
)

SELECT 
    dd.Date_Id,
    s.Price_INR,
    s.Rating,
    s.Rating_count,

    dl.Location_Id,
    dr.Restaurant_Id,
    dc.Category_Id,
    dsh.Dish_Id
FROM swiggy_data s

JOIN dim_date dd
   ON dd.Full_Date = s.Order_Date

JOIN dim_Location dl
   On dl.State = s.State
   AND dl.City = s.City
   AND dl.Location= s.Location

JOIN dim_restaurant dr
   ON dr.Restaurant_name = s.Restaurant_Name

JOIN dim_category dc
   ON dc.Category = s.Category

JOIN dim_dish dsh
   ON dsh.Dish_Name = s.Dish_Name;

SELECT * FROM fact_swiggy_orders;


SELECT * FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id=d.Date_Id
JOIN dim_location l ON f.Location_Id=l.Location_Id
JOIN dim_restaurant r ON f.Restaurant_Id=r.Restaurant_Id
JOIN dim_category c ON f.Category_Id=c.Category_Id
JOIN dim_dish di ON f.Dish_Id=di.Dish_Id;

--KPIs
--Total Orders
SELECT COUNT(*) AS Total_Orders
FROM fact_swiggy_orders;

--Total Revenue
SELECT FORMAT(SUM(CONVERT(float,Price_INR))/1000000,'N2') + ' INR MILLION'
AS Total_Revenue
FROM fact_swiggy_orders;

--Average Dish Price
SELECT FORMAT(AVG(CONVERT(float,Price_INR)),'N2') + ' INR MILLION'
AS Total_Revenue
FROM fact_swiggy_orders;

--Average Rating
SELECT AVG(Rating) AS Average_Rating
FROM fact_swiggy_orders;

--Deep Dive Business Analytics
--Monthly Order Trends
SELECT 
d.Year,
d.Month,
d.Month_Name,
count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id=d.Date_Id
GROUP BY d.Year,
d.Month,
d.Month_Name;

SELECT 
d.Year,
d.Month,
d.Month_Name,
SUM(Price_INR) AS Total_Revenue
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id=d.Date_Id
GROUP BY d.Year,
d.Month,
d.Month_Name
Order by SUM(Price_INR) Desc;


--QUARTERLY ORDER TRENDS
SELECT 
d.Year,
d.Quarter,
count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id=d.Date_Id
GROUP BY
d.Year,
d.Quarter
ORDER BY COUNT(*) DESC;

--YEARLY ORDER TRENDS
SELECT 
d.Year,
count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d ON f.Date_Id=d.Date_Id
GROUP BY
d.Year
ORDER BY COUNT(*) DESC;

--ORDERS BY DAY OF WEEK(SUN-MON)
SELECT 
     DATENAME(WEEKDAY, d.Full_Date) AS Day_Name,
     COUNT(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_date d
ON f.Date_Id=d.Date_Id
GROUP BY DATENAME(WEEKDAY, d.Full_Date),DATEPART(WEEKDAY, d.Full_Date)
ORDER BY DATEPART(WEEKDAY, d.Full_Date);

--Top 10 Cities BY Order
SELECT TOP 10
l.City,
Count(*) AS Total_Orders
from fact_swiggy_orders f
JOIN dim_location l ON f.Location_Id=l.Location_Id
GROUP BY l.City
ORDER BY Count(*) DESC;

--Revenue Contribution By States
SELECT TOP 10
l.City,
SUM(f.Price_INR) AS Total_Total_Revenue
from fact_swiggy_orders f
JOIN dim_location l ON f.Location_Id=l.Location_Id
GROUP BY l.City
ORDER BY SUM(f.Price_INR) DESC;

--Food Performane
--Top 10 Restaurants By Orders
Select TOP 10
r.Restaurant_name,
Count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_restaurant r
ON f.Restaurant_Id=r.Restaurant_Id
GROUP BY r.Restaurant_name
ORDER BY Count(*) DESC;

--Top Categories
Select TOP 10
c.Category,
Count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c
ON f.Category_Id=c.Category_Id
GROUP BY c.Category
ORDER BY Count(*) DESC;

--Most Ordered Dishes
Select TOP 10
ds.Dish_Name,
Count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_dish ds
ON f.Dish_Id=ds.Dish_Id
GROUP BY ds.Dish_Name
ORDER BY Count(*) DESC;


--CUISINE PERFORMANCE -->Orders+Avg Rating
Select TOP 10
c.Category,FORMAT(AVG(CONVERT(DECIMAL,Rating)),'N2') AS Avg_Rating,
Count(*) AS Total_Orders
FROM fact_swiggy_orders f
JOIN dim_category c
ON f.Category_Id=c.Category_Id
GROUP BY c.Category
ORDER BY Count(*) DESC;

--Customer Spending Insights
SELECT 
     CASE
         WHEN CONVERT(FLOAT,Price_INR)<100 THEN 'Under 100'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 400 AND 499 THEN '400 - 499'
         ELSE '500+'
        END AS Price_Range,
        COUNT(*) AS Total_Orders
FROM fact_swiggy_orders
GROUP BY 
     CASE
         WHEN CONVERT(FLOAT,Price_INR)<100 THEN 'Under 100'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 100 AND 199 THEN '100 - 199'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 200 AND 299 THEN '200 - 299'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 300 AND 399 THEN '300 - 399'
         WHEN CONVERT(FLOAT,Price_INR) BETWEEN 400 AND 499 THEN '400 - 499'
         ELSE '500+'
        END;
        
--RATING COUNT DISTRIBUTION
SELECT 
    Rating,
    Count(*) AS Rating_Count
    FROM fact_swiggy_orders
    GROUP BY Rating
    ORDER BY Rating;