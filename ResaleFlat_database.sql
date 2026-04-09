-- drop and recreate the database to ensure a clean environemt
DROP DATABASE IF EXISTS hdb_resale;
CREATE DATABASE hdb_resale;
USE hdb_resale;

-- stores unique town names
-- separating towns removes redunancy and supports normalisation
CREATE TABLE towns (
    town_id INT AUTO_INCREMENT PRIMARY KEY,
    town_name VARCHAR(50) NOT NULL UNIQUE
);

-- stores unique flat types
CREATE TABLE flat_types (
    flat_type_id INT AUTO_INCREMENT PRIMARY KEY,
    flat_type VARCHAR(50) NOT NULL UNIQUE
);

-- stores unique flat models
-- flat models repeat across many transactions and are normalised
CREATE TABLE flat_models (
    flat_model_id INT AUTO_INCREMENT PRIMARY KEY,
    flat_model VARCHAR(100) NOT NULL UNIQUE
);

-- time dimensions table storing year and month separately
CREATE TABLE time_dim (
    time_id INT AUTO_INCREMENT PRIMARY KEY,
    year INT NOT NULL,
    month INT NOT NULL,
    UNIQUE (year, month)
);

-- stores transaction data
CREATE TABLE resale_transactions (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    town_id INT NOT NULL,
    flat_type_id INT NOT NULL,
    flat_model_id INT NOT NULL,
    time_id INT NOT NULL,
    floor_area_sqm DECIMAL(5,2),
    lease_commencement_year INT,
    resale_price INT NOT NULL,
    FOREIGN KEY (town_id) REFERENCES towns(town_id),
    FOREIGN KEY (flat_type_id) REFERENCES flat_types(flat_type_id),
    FOREIGN KEY (flat_model_id) REFERENCES flat_models(flat_model_id),
    FOREIGN KEY (time_id) REFERENCES time_dim(time_id)
);

CREATE TABLE staging_resale (
    month VARCHAR(10),
    town VARCHAR(50),
    flat_type VARCHAR(50),
    flat_model VARCHAR(100),
    floor_area_sqm DECIMAL(5,2),
    lease_commencement_year INT,
    resale_price INT
);

-- load raw CSV data into staging table
LOAD DATA LOCAL INFILE '/home/coder/project/csv/ResaleFlatPricesBasedonApprovalDate19901999.csv'
INTO TABLE staging_resale
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

-- insert unique towns from the staging table
INSERT IGNORE INTO towns (town_name)
SELECT DISTINCT town FROM staging_resale
WHERE town IS NOT NULL;

-- insert unique flat types
INSERT IGNORE INTO flat_types (flat_type)
SELECT DISTINCT flat_type FROM staging_resale
WHERE flat_type IS NOT NULL;

-- insert unique flat models
INSERT IGNORE INTO flat_models (flat_model)
SELECT DISTINCT flat_model FROM staging_resale
WHERE flat_model IS NOT NULL;
 
-- insert unique year and month combinations into the time dimensions
INSERT IGNORE INTO time_dim (year, month)
SELECT DISTINCT
    CAST(SUBSTRING(month, 1, 4) AS UNSIGNED) as year,
    CAST(SUBSTRING(month, 6, 2) AS UNSIGNED) as month
FROM staging_resale
WHERE month IS NOT NULL AND month != '';

-- insert tranction records into the fact table
INSERT INTO resale_transactions (
    town_id,
    flat_type_id,
    flat_model_id,
    time_id,
    floor_area_sqm,
    lease_commencement_year,
    resale_price
)
SELECT
    t.town_id,
    ft.flat_type_id,
    fm.flat_model_id,
    td.time_id,
    s.floor_area_sqm,
    s.lease_commencement_year,
    s.resale_price
FROM staging_resale s
JOIN towns t
ON s.town = t.town_name
JOIN flat_types ft
ON s.flat_type = ft.flat_type
JOIN flat_models fm 
ON s.flat_model =  fm.flat_model
JOIN time_dim td
    ON CAST(SUBSTRING(TRIM(s.month), 1, 4) AS UNSIGNED) = td.year
    AND CAST(SUBSTRING(TRIM(s.month), 6, 2) AS UNSIGNED) = td.month;



-- Avergae price by year query
SELECT
    td.year,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    COUNT(*) as num_transactions
FROM resale_transactions rt
JOIN time_dim td ON rt.time_id = td.time_id
GROUP BY td.year
ORDER BY td.year;

-- top 10 most exp towns
SELECT
    t.town_name,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    COUNT(*) as num_transactions
FROM resale_transactions rt
JOIN towns t ON rt.town_id = t.town_id
GROUP BY t.town_name
ORDER BY avg_price DESC
LIMIT 10;

-- price by flat_type
SELECT
    ft.flat_type,
    ROUND(AVG(rt.resale_price), 2) as avg_price,
    ROUND(MIN(rt.resale_price), 2) as min_price,
    ROUND(MAX(rt.resale_price), 2) as max_price
FROM resale_transactions rt
JOIN flat_types ft ON rt.flat_type_id = ft.flat_type_id
GROUP BY ft.flat_type
ORDER BY avg_price DESC;

-- monthly transaction volume
SELECT
    td.year,
    td.month,
    COUNT(*) as num_transactions
FROM resale_transactions rt
JOIN time_dim td ON rt.time_id = td.time_id
GROUP BY td.year, td.month
ORDER BY td.year, td.month;

-- flat type and size anaslysis 
SELECT
    ft.flat_type,
    AVG(rt.resale_price) as avg_price,
    AVG(rt.floor_area_sqm) as avg_floor_area,
    AVG(rt.resale_price / rt.floor_area_sqm) as price_per_sqm,
    COUNT(*) as num_transactions,    
    MIN(rt.resale_price) as min_price,
    MAX(rt.resale_price) as max_price
FROM resale_transactions rt
JOIN flat_types ft ON rt.flat_type_id = ft.flat_type_id
WHERE rt.floor_area_sqm IS NOT NULL
GROUP BY ft.flat_type
ORDER BY avg_price DESC;


-- what combination most exp and most affordable transaction eg (town+flat type + year)
SELECT
    t.town_name,
    ft.flat_type,
    td.year,
    AVG(rt.resale_price) as avg_price,
    COUNT(*) as num_transactions
FROM resale_transactions rt
JOIN towns t ON rt.town_id = t.town_id
JOIN flat_types ft ON rt.flat_type_id = ft.flat_type_id
JOIN time_dim td ON rt.time_id = td.time_id
GROUP BY t.town_name, ft.flat_type, td.year
HAVING COUNT(*) >= 10
ORDER BY avg_price DESC
LIMIT 20;