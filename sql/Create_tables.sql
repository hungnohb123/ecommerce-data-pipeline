USE ecommerce_dw;

GO
--1 Dam bao cac schema da ton tai
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'bronze') EXEC('CREATE SCHEMA bronze');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'silver') EXEC('CREATE SCHEMA silver');
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'gold') EXEC('CREATE SCHEMA gold');
GO

--Tang Bronze: Bang luu tru du lieu tho
--100% NVARCHAR,cho phep NULL de ingestion an toan
IF OBJECT_ID('bronze.raw_orders','U') IS NOT NULL DROP TABLE bronze.raw_orders;
CREATE TABLE bronze.raw_orders(
	order_id NVARCHAR(MAX),
	customer_id NVARCHAR(MAX),
	order_status NVARCHAR(MAX),
	order_purchase_timestamp NVARCHAR(MAX),
	order_approved_at NVARCHAR(MAX),
	order_delivered_carrier_date NVARCHAR(MAX),
	order_delivered_customer_date NVARCHAR(MAX),
	order_estimated_delivery_date NVARCHAR(MAX),
	_ingested_at DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('bronze.raw_order_items','U') IS NOT NULL DROP TABLE bronze.raw_order_items;
CREATE TABLE bronze.raw_order_items(
	order_id NVARCHAR(MAX),
	order_item_id NVARCHAR(MAX),
	product_id NVARCHAR(MAX),
	seller_id NVARCHAR(MAX),
	shipping_limit_date NVARCHAR(MAX),
	price NVARCHAR(MAX),
	freight_value NVARCHAR(MAX),
	_ingested_at DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('bronze.raw_customers','U') IS NOT NULL DROP TABLE bronze.raw_customers;
CREATE TABLE bronze.raw_customers (
	customer_id NVARCHAR(MAX),
	customer_unique_id NVARCHAR(MAX),
	customer_zip_code_prefix NVARCHAR(MAX),
	customer_city NVARCHAR(MAX),
	customer_state NVARCHAR(MAX),
	_ingested_at DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('bronze.raw_products', 'U') IS NOT NULL DROP TABLE bronze.raw_products;
CREATE TABLE bronze.raw_products (
	product_id NVARCHAR(MAX),
	product_category_name NVARCHAR(MAX),
	product_name_lenght NVARCHAR(MAX),
	product_description_lenght NVARCHAR(MAX),
	products_photos_qty NVARCHAR(MAX),
	product_weight_g NVARCHAR(MAX),
    product_length_cm NVARCHAR(MAX),
    product_height_cm NVARCHAR(MAX),
    product_width_cm NVARCHAR(MAX),
    _ingested_at DATETIME2 DEFAULT GETDATE()
);

IF OBJECT_ID('bronze.raw_sellers', 'U') IS NOT NULL DROP TABLE bronze.raw_sellers;
CREATE TABLE bronze.raw_sellers (
    seller_id NVARCHAR(MAX),
    seller_zip_code_prefix NVARCHAR(MAX),
    seller_city NVARCHAR(MAX),
    seller_state NVARCHAR(MAX),
    _ingested_at DATETIME2 DEFAULT GETDATE()
);
GO

--Tang silver: du lieu da lam sach va kiem tra tinh toan ven
IF OBJECT_ID('silver.cleaned_orders', 'U') IS NOT NULL DROP TABLE silver.cleaned_orders;
CREATE TABLE silver.cleaned_orders (
    order_id VARCHAR(32) NOT NULL,
    customer_id VARCHAR(32) NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_purchase_timestamp DATETIME2 NOT NULL,
    order_approved_at DATETIME2 NULL,
    order_delivered_carrier_date DATETIME2 NULL,
    order_delivered_customer_date DATETIME2 NULL,
    order_estimated_delivery_date DATETIME2 NOT NULL,
    is_anomaly_carrier BIT DEFAULT 0,
    CONSTRAINT PK_silver_orders PRIMARY KEY (order_id)
);

IF OBJECT_ID('silver.cleaned_order_items', 'U') IS NOT NULL DROP TABLE silver.cleaned_order_items;
CREATE TABLE silver.cleaned_order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    shipping_limit_date DATETIME2 NOT NULL,
    price DECIMAL(10, 2) NOT NULL CHECK (price > 0),
    freight_value DECIMAL(10, 2) NOT NULL CHECK (freight_value >= 0),
    CONSTRAINT PK_silver_order_items PRIMARY KEY (order_id, order_item_id)
);
GO

--Tang GOLD: Star schema (Fact & Dimension table)
--1.Bang Dimdate
IF OBJECT_ID('gold.fact_order_items','U') IS NOT NULL DROP TABLE gold.fact_order_items;
IF OBJECT_ID('gold.dim_customer', 'U') IS NOT NULL DROP TABLE gold.dim_customer;
IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL DROP TABLE gold.dim_product;
IF OBJECT_ID('gold.dim_seller', 'U') IS NOT NULL DROP TABLE gold.dim_seller;
IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL DROP TABLE gold.dim_date;

CREATE TABLE gold.dim_date (
	date_id INT NOT NULL,-- Dinh dang YYYMMĐ
	full_date DATE NOT NULL,
	year INT NOT NULL,
	quarter INT NOT NULL,
	month INT NOT NULL,
	month_name VARCHAR(15) NOT NULL,
	day INT NOT NULL,
	day_of_week INT NOT NULL,
	day_name VARCHAR(15) NOT NULL,
	is_weekend BIT NOT NULL,
	CONSTRAINT PK_gold_dim_date PRIMARY KEY(date_id)
);

--2.bANG Dim_customer
CREATE TABLE gold.dim_customer(
	customer_key INT IDENTITY(1,1) NOT NULL,
	customer_id VARCHAR(32) NOT NULL,
	customer_unique_id VARCHAR(32) NOT NULL,
	customer_city NVARCHAR(100) NULL,
	customer_state VARCHAR(5) NULL,
	CONSTRAINT PK_gold_dim_customer PRIMARY KEY (customer_key),
	CONSTRAINT UQ_gold_dim_customer_id UNIQUE (customer_id)
);

--3.Bang Dim_product
CREATE TABLE gold.dim_product (
    product_key INT IDENTITY(1, 1) NOT NULL,
    product_id VARCHAR(32) NOT NULL,
    category_name_english NVARCHAR(100) DEFAULT 'unknown',
    product_weight_g INT NULL,
    product_length_cm INT NULL,
    product_height_cm INT NULL,
    product_width_cm INT NULL,
    CONSTRAINT PK_gold_dim_product PRIMARY KEY (product_key),
    CONSTRAINT UQ_gold_dim_product_id UNIQUE (product_id)
);
-- 4. Bảng Dim Seller
CREATE TABLE gold.dim_seller (
    seller_key INT IDENTITY(1, 1) NOT NULL,
    seller_id VARCHAR(32) NOT NULL,
    seller_city NVARCHAR(100) NULL,
    seller_state VARCHAR(5) NULL,
    CONSTRAINT PK_gold_dim_seller PRIMARY KEY (seller_key),
    CONSTRAINT UQ_gold_dim_seller_id UNIQUE (seller_id)
);
--5 Bang Fact Order Items
-- 5. Bảng Fact Order Items
CREATE TABLE gold.fact_order_items (
    order_id VARCHAR(32) NOT NULL,
    order_item_id INT NOT NULL,
    customer_key INT NOT NULL,
    product_key INT NOT NULL,
    seller_key INT NOT NULL,
    order_date_id INT NOT NULL,
    delivered_date_id INT NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    freight_value DECIMAL(10, 2) NOT NULL,
    total_item_value DECIMAL(10, 2) NOT NULL,
    delivery_duration_days INT NULL,
    delivery_delay_days INT NULL,
    is_delayed TINYINT DEFAULT 0,
    
    CONSTRAINT PK_gold_fact_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT FK_fact_customer FOREIGN KEY (customer_key) REFERENCES gold.dim_customer(customer_key),
    CONSTRAINT FK_fact_product FOREIGN KEY (product_key) REFERENCES gold.dim_product(product_key),
    CONSTRAINT FK_fact_seller FOREIGN KEY (seller_key) REFERENCES gold.dim_seller(seller_key),
    CONSTRAINT FK_fact_order_date FOREIGN KEY (order_date_id) REFERENCES gold.dim_date(date_id),
    CONSTRAINT FK_fact_delivered_date FOREIGN KEY (delivered_date_id) REFERENCES gold.dim_date(date_id)
);
GO

--Co che khoa mac dinh -1
--Dam bao khong bi dut gay khoa ngoai khi ban ghi nguon bi NULL
-- Khóa -1 cho Dim Date
INSERT INTO gold.dim_date (date_id, full_date, year, quarter, month, month_name, day, day_of_week, day_name, is_weekend)
VALUES (-1, '1900-01-01', 1900, 0, 0, 'Unknown', 0, 0, 'Unknown', 0);

-- Khóa -1 cho Dim Customer
SET IDENTITY_INSERT gold.dim_customer ON;
INSERT INTO gold.dim_customer (customer_key, customer_id, customer_unique_id, customer_city, customer_state)
VALUES (-1, 'UNKNOWN_CUSTOMER', 'UNKNOWN_UNIQUE_ID', 'Unknown', 'NA');
SET IDENTITY_INSERT gold.dim_customer OFF;

-- Khóa -1 cho Dim Product
SET IDENTITY_INSERT gold.dim_product ON;
INSERT INTO gold.dim_product (product_key, product_id, category_name_english, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
VALUES (-1, 'UNKNOWN_PRODUCT', 'unknown', 0, 0, 0, 0);
SET IDENTITY_INSERT gold.dim_product OFF;

-- Khóa -1 cho Dim Seller
SET IDENTITY_INSERT gold.dim_seller ON;
INSERT INTO gold.dim_seller (seller_key, seller_id, seller_city, seller_state)
VALUES (-1, 'UNKNOWN_SELLER', 'Unknown', 'NA');
SET IDENTITY_INSERT gold.dim_seller OFF;
GO
