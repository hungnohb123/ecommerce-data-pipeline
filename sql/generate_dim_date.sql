-- Mục đích: Sinh tự động toàn bộ ngày từ 2016 đến hết 2021 vào gold.dim_date
USE ecommerce_dw;
GO

SET NOCOUNT ON;

DECLARE @StarDate DATE = '2016-01-01';
DECLARE @EndDate DATE = '2021-12-31';

-- dUNG CTE de quy de sinh chuoi ngay lien tuc
WITH DateSeries AS (
	SELECT @StarDate AS [Date]
	UNION ALL
	SELECT DATEADD(DAY,1,[Date])
	FROM DateSeries
	WHERE [Date] < @EndDate
)
INSERT INTO gold.dim_date(
	date_id,
	full_date,
	year,
	quarter,
	month,
	month_name,
	day,
	day_of_week,
	day_name,
	is_weekend
)
SELECT 
	--date_id kiểu INT dạng YYYYMMDD
	YEAR([Date]) * 10000 + MONTH([Date]) * 100 + DAY([Date]) AS date_id,
	[Date] AS full_date,
	YEAR([Date]) AS year,
	DATEPART(QUARTER,[Date]) AS quarter,
	MONTH([Date]) AS month,
	DATENAME(MONTH,[Date]) AS month_name,
	DAY([Date]) AS day,
	DATEPART(WEEKDAY, [Date]) AS day_of_week,
	DATENAME(WEEKDAY, [Date]) as day_name,
	-- Cuối tuần (Thứ 7 = 7, Chủ nhật = 1 theo chuẩn SQL Server mặc định)
    CASE WHEN DATEPART(WEEKDAY, [Date]) IN (1, 7) THEN 1 ELSE 0 END AS is_weekend
FROM DateSeries
WHERE YEAR([Date]) * 10000 + MONTH([Date]) * 100 + DAY([Date]) NOT IN (SELECT date_id FROM gold.dim_date)
OPTION (MAXRECURSION 3000);
GO



-- Kiểm tra kết quả
SELECT COUNT(*) AS total_dates, MIN(full_date) AS min_date, MAX(full_date) AS max_date 
FROM gold.dim_date 
WHERE date_id <> -1;
GO