/* 
- Customer Segmentation:
- Segment customers into categories based on:
- RFM Analysis:
*/
-- 1- Recency: Days since last order. 
SELECT 
    CustomerID,
    MAX(OrderDate) AS LastOrderDate,
    ROUND(julianday('now') - julianday(MAX(OrderDate))) AS Recency
FROM Orders
GROUP BY CustomerID
ORDER BY Recency ASC

--Frequency: Total number of orders (volume).
SELECT 
    CustomerID,
    COUNT(DISTINCT OrderID) Frequency
FROM Orders
GROUP BY CustomerID
ORDER BY Frequency DESC
--Monetary Value: Total amount spent (revenue).
SELECT 
    o.CustomerID,
    SUM(od.UnitPrice * od.Quantity) AS MonetaryValue
FROM Orders o
JOIN "Order Details" od ON o.OrderID = od.OrderID
GROUP BY o.CustomerID
ORDER BY MonetaryValue DESC


--Create at least 3 customer segments:
--Champions Bought most Recently and most Often, and spent most
--Potential Loyalists Buy Most frequently or Spent Most
--At Risk Anyone else

-- Combine RFM analysis into one query
--------------------------------------------------------------------------------------------------------------------------
WITH RFM AS (
    SELECT 
        o.CustomerID,
        ROUND(julianday('now') - julianday(MAX(o.OrderDate))) AS Recency,
        COUNT(DISTINCT o.OrderID) AS Frequency,
        SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS MonetaryValue
    FROM Orders o
    JOIN "Order Details" od ON o.OrderID = od.OrderID
    GROUP BY o.CustomerID
  	
),
RFM_RANKED AS (
    SELECT 
        CustomerID,
        Recency,
        Frequency,
        MonetaryValue,
        NTile(3) OVER (ORDER BY Recency) AS R,
        NTile(3) OVER (ORDER BY Frequency DESC) AS F,
        NTile(3) OVER (ORDER BY MonetaryValue DESC) AS M
    FROM RFM
)
SELECT 
    CustomerID,
    Recency,
    Frequency,
    MonetaryValue,
    R,
    F,
    M,
    CASE
        WHEN R = 1 AND F = 3 AND M = 3 THEN 'Champion'
        WHEN (F = 2 OR F = 3) AND (M = 2 OR M = 3) THEN 'Potential Loyalist'
        ELSE 'At Risk'
    END AS Segment
FROM RFM_RANKED;
----------------------------------------------
--Another Solution With view
----------------------------------------------
CREATE VIEW RFM_Metrics AS
SELECT 
    o.CustomerID,
    ROUND(julianday('now') - julianday(MAX(o.OrderDate))) AS Recency,
    COUNT(DISTINCT o.OrderID) AS Frequency,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS MonetaryValue
FROM Orders o
JOIN "Order Details" od ON o.OrderID = od.OrderID
GROUP BY o.CustomerID;

CREATE VIEW RFM_Ranks AS
SELECT 
    CustomerID,
    Recency,
    Frequency,
    MonetaryValue,
    NTile(3) OVER (ORDER BY Recency ASC) AS R,
    NTile(3) OVER (ORDER BY Frequency DESC) AS F,
    NTile(3) OVER (ORDER BY MonetaryValue DESC) AS M
FROM RFM_Metrics;

SELECT 
    CustomerID,
    Recency,
    Frequency,
    MonetaryValue,
    R,
    F,
    M,
    CASE
        WHEN R = 1 AND F = 3 AND M = 3 THEN 'Champion'
        WHEN (F = 2 OR F = 3) AND (M = 2 OR M = 3) THEN 'Potential Loyalist'
        ELSE 'At Risk'
    END AS Segment
FROM RFM_Ranks
ORDER BY Segment;

-- I want to know each segment count
SELECT 
    Segment,
    COUNT(CustomerID) AS CustomerCount
FROM (
    SELECT 
        CustomerID,
        CASE
            WHEN R = 1 AND F = 3 AND M = 3 THEN 'Champion'
            WHEN (F = 2 OR F = 3) AND (M = 2 OR M = 3) THEN 'Potential Loyalist'
            ELSE 'At Risk'
        END AS Segment
    FROM RFM_Ranks
) Segments
GROUP BY Segment
ORDER BY CustomerCount DESC;

----------------------------------------------------------------------------------------------------------------------------------------
--Order Value:
--High-Value, Medium-Value, Low-Value customers based on their avarage order revenue value.

WITH REV AS (
    SELECT 
        o.CustomerID,
        AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS AverageRevenue
    FROM Orders o
    JOIN "Order Details" od ON od.OrderID = o.OrderID
    GROUP BY o.CustomerID
),
RankedRev AS (
    SELECT 
        CustomerID,
        AverageRevenue,
        NTile(3) OVER (ORDER BY AverageRevenue DESC) AS RevenueRank
    FROM REV
)
SELECT 
    CustomerID,
    AverageRevenue,
    RevenueRank,
    CASE
        WHEN RevenueRank = 1 THEN 'High-Value'
        WHEN RevenueRank = 2 THEN 'Medium-Value'
        ELSE 'Low-Value'
    END AS OrderValueSegment
FROM RankedRev
ORDER BY AverageRevenue DESC;

-------------------------------------------------------------------------------------------------------------------------------
--Product Analysis:
--Identify products with:
--High Revenue Value: Identify the top 10 revenue generator products
SELECT 
	p.productid,
    p.productname,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Revenue
FROM
	Products p
INNER JOIN 
	"Order Details" od
ON	
	p.ProductID=od.ProductID
GROUP BY 1,2
ORDER BY 3 DESC
LIMIT 10

--High Sales Volume: Determine the top 10 most frequently ordered products.
SELECT 
    p.ProductName, 
    COUNT(DISTINCT orderid) OrderFrequency
FROM 
    "Order Details" od
INNER JOIN 
    Products p ON od.ProductID = p.ProductID
GROUP BY 
    p.ProductName
ORDER BY 
    OrderFrequency DESC
LIMIT 10;

--Slow Movers: Identify products with low sales volume
SELECT 
    p.ProductID,
    p.ProductName,
    COUNT(DISTINCT orderid) OrderFrequency
FROM "Order Details" od
JOIN Products p ON od.ProductID = p.ProductID
GROUP BY p.ProductID, p.ProductName
ORDER BY OrderFrequency ASC
LIMIT 5;

---------------------------------------------------------------------------------------------------------------------------------------------------------
--Order Analysis:
--Analyze order trends:
--Seasonality: Identify any seasonal fluctuations in order volume
SELECT
    strftime('%Y-%m', OrderDate) AS Month,
    COUNT(orderid) OrderCount
FROM Orders 
GROUP BY 1
ORDER BY Month;
--Day-of-the-Week Analysis: Determine the most popular order days.
SELECT
    CASE 
        WHEN strftime('%w', OrderDate) = '0' THEN 'Sunday'
        WHEN strftime('%w', OrderDate) = '1' THEN 'Monday'
        WHEN strftime('%w', OrderDate) = '2' THEN 'Tuesday'
        WHEN strftime('%w', OrderDate) = '3' THEN 'Wednesday'
        WHEN strftime('%w', OrderDate) = '4' THEN 'Thursday'
        WHEN strftime('%w', OrderDate) = '5' THEN 'Friday'
        WHEN strftime('%w', OrderDate) = '6' THEN 'Saturday'
    END AS DayOfWeekName,
    COUNT(distinct orderid) OrderCount
FROM 
	Orders
GROUP BY 1

--Order Size Analysis: Analyze the distribution of order quantities 
SELECT
	orderid,
    SUM(quantity) OrderQty,
    CASE 
        WHEN SUM(Quantity) <= 500 THEN 'Small'
        WHEN SUM(Quantity) BETWEEN 501 AND 1000 THEN 'Medium'
        ELSE 'Large'
    END AS OrderSize,
    COUNT(OrderID) AS NumberOfOrders
FROM "Order Details" 
GROUP BY 1
ORDER BY 2 DESC
--------------------------------------------------------------------------------------------------------------------------------------------
--Employee Performance:
--valuate employee performance based on:
--Total Revenue Generated.
SELECT 
	Emp.EmployeeID,
    CONCAT(firstname,' ',lastname) EmployeeName,
    SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS Revenue
FROM 
	Employees Emp
INNER JOIN 
	Orders o
ON
	Emp.EmployeeID=o.EmployeeID
INNER join 
	"Order Details" od
ON
	od.OrderID=o.OrderID
GROUP BY 1,2
ORDER BY 3 DESC
	
--Total Sales Volume (Number of orders processed).
SELECT
	Emp.EmployeeID,
    CONCAT(firstname,' ',lastname) EmployeeName,
    COUNT(DISTINCT orderid)	NumberOfOrders
FROM 
	Employees Emp
INNER JOIN
	Orders o
ON 
	Emp.EmployeeID = o.EmployeeID
GROUP BY 1,2
ORDER BY 3 DESC

--Average order value.
SELECT 
	Emp.EmployeeID,
    CONCAT(firstname,' ',lastname) EmployeeName,
    AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)) AS AverageOrderValue,
    COUNT(DISTINCT	o.orderid)	NumberOfOrders
FROM 
	Employees Emp
INNER JOIN 
	Orders o
ON
	Emp.EmployeeID=o.EmployeeID
INNER join 
	"Order Details" od
ON
	od.OrderID=o.OrderID
GROUP BY 1,2
ORDER BY 3 DESC

