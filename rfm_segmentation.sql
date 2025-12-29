-- Create a new database for the project
CREATE DATABASE rfm_analysis;

-- Use the database
USE rfm_analysis;

-- Check first few rows
SELECT * FROM retail_data LIMIT 10;

-- Add a new column to store invoice dates in proper datetime format for time-based analysis
ALTER TABLE retail_data
ADD COLUMN invoice_datetime DATETIME;
UPDATE retail_data
SET invoice_datetime = STR_TO_DATE(InvoiceDate, '%m/%d/%Y %H:%i');

-- Removes invalid or incomplete transaction records
DELETE FROM retail_data
WHERE CustomerID IS NULL
   OR Quantity <= 0
   OR UnitPrice <= 0;

-- Create a base table aggregating each customer's last purchase date, purchase frequency, and total spending
CREATE TABLE rfm_base AS
SELECT
    CustomerID,
    MAX(invoice_datetime) AS last_purchase_date,
    COUNT(DISTINCT InvoiceNo) AS frequency,
    SUM(Quantity * UnitPrice) AS monetary
FROM retail_data
GROUP BY CustomerID;

-- Add and calculate recency as the number of days since the customer's last purchase
ALTER TABLE rfm_base ADD recency INT;
UPDATE rfm_base
SET recency = DATEDIFF('2011-12-09', last_purchase_date);

-- Assigns RFM scores by ranking customers into quintiles based on recency, frequency, and monetary value
CREATE TABLE rfm_scores AS
SELECT
    *,
    NTILE(5) OVER (ORDER BY recency DESC) AS r_score,
    NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
    NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
FROM rfm_base;

-- Assigns customer segments based on combined RFM scores to categorize customer behavior
SELECT
    CustomerID,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_code,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Potential Loyalists'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'At Risk'
        ELSE 'Lost Customers'
    END AS customer_segment
FROM rfm_scores;
