use live

declare @getNewID varchar(max);
DROP VIEW IF EXISTS dbo.getNewID;
select @getNewID = 'CREATE view [dbo].[getNewID] as select newid() as new_id';
exec (@getNewID);

declare @getRand varchar(max);
DROP VIEW IF EXISTS dbo.getRand;
select @getRand = 'CREATE view [dbo].[getRand] as select rand() as rand';
exec (@getRand);


drop function if exists [dbo].[Randomtimestamp];
declare @Randomtimestamp varchar(max);
select @Randomtimestamp = '
create function [dbo].[Randomtimestamp]()
returns datetime2
as
	begin

	declare @rand decimal(10,5);
	select @rand = [rand] from [dbo].[getRand];

	declare @floor int
	select @floor = floor((abs(@rand * @rand)+1)*10)*-1;

	declare @new_id uniqueidentifier
	select @new_id = [new_id] from [dbo].[getNewID]

	DECLARE @FromDate DATETIME2(0) = DATEADD(DAY, -90, GETDATE());
	DECLARE @ToDate DATETIME2(0) = GETDATE();
	DECLARE @RandomSeconds INT = ABS(CHECKSUM(@new_id)) % DATEDIFF(SECOND, @FromDate, @ToDate);
	DECLARE @RandomTimestamp DATETIME2(0) = DATEADD(SECOND, @RandomSeconds, @FromDate);

	return DATEADD(DD, @floor, @RandomTimestamp)
end
';
exec (@Randomtimestamp);

DROP TABLE if exists tblProduct;

CREATE TABLE [dbo].tblProduct(
	[ProductID] [int] IDENTITY(1,1) NOT NULL,
	[ProductName] [varchar](50) NULL,
	CONSTRAINT [PK_Product] PRIMARY KEY CLUSTERED 
	([ProductID] ASC)
)

DROP TABLE if exists tblCustomer;

CREATE TABLE [dbo].tblCustomer(
	[CustomerID] [int] IDENTITY(1,1) NOT NULL,
	[CustomerName] [varchar](50) NULL,
	CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED 
	([CustomerID] ASC)
)

DROP TABLE if exists [dbo].[tblEvent]
GO


CREATE TABLE [dbo].[tblEvent](
	[EventID] [int] IDENTITY(1,1) NOT NULL,
	[EventDateTime] [datetime] NOT NULL,
	[EventDate] [date] NULL,
	[EventYYMMDD] int NULL, 
	[EventValue] [decimal](10, 2) NOT NULL,
	[CustomerID] [int] NOT NULL,
	[ProductID] [int] NOT NULL,
 CONSTRAINT [PK_tblEvent] PRIMARY KEY CLUSTERED 
(
	[EventID] ASC
)
) ON [PRIMARY]
GO



DECLARE @a INT = 0, @z INT = 10

while  @a < @z 
begin
	insert into tblProduct(ProductName)
	select left(CONVERT(varchar(100), NEWID()),8)

	insert into tblCustomer([CustomerName])
	select left(CONVERT(varchar(100), NEWID()),8)
	select @a = @a+1		   
end

drop table if exists dbo.tblProductCategory;

select distinct ProductID, 
case 
	when ProductID <= 3 then 'Cat A'
	when ProductID <= 6 then 'Cat B'
	when ProductID <= 10 then 'Cat C'
end as ProductCategory
into tblProductCategory
from tblProduct


declare @sp_SeedEvents varchar(max);
select @sp_SeedEvents = '
CREATE OR ALTER   procedure [dbo].[sp_SeedEvents] as 
DECLARE @CustomerCounter INT = 1;
DECLARE @ProductID INT;

WHILE @CustomerCounter <= 10
	BEGIN
    
		SET @ProductID = 1; 

		WHILE @ProductID <= 10
		BEGIN

			declare @Rand decimal(10,2) 
			select @Rand = (select top 1 rand * 100 from [dbo].[getRand]) 
			insert into dbo.[tblEvent]([EventDateTime], EventValue, [CustomerID], [ProductID])
			select 
			dbo.RandomTimestamp() as RandomTimestamp, 
			@Rand,
			@CustomerCounter as CustomerID, 
			@ProductID as ProductID
			SET @ProductID = @ProductID + 1;
		END
    
		SET @CustomerCounter = @CustomerCounter + 1;
		
	END
';



exec (@sp_SeedEvents);

declare @i int, @j int 
select @i = 1, @j = 30
while @i <= @j
begin
	exec [dbo].sp_SeedEvents /*separate stored procedure to load an event table */
	select @i = @i + 1
end

update tblEvent set EventDate = cast(EventDateTime as date) ,
[EventYYMMDD] = concat(year(EventDate), format(month(EventDate), '00'), format(day(EventDate), '00'))

/*
EXEC spLoadData
*/

drop table if exists [dbo].[tblDateDimension]
select distinct 
EventDate as YYMMDD
,cast(concat(year(EventDate), format(month(EventDate), '00'), format(day(EventDate), '00')) as int)as EventYYMMDD
,cast(concat(year(EventDate), format(month(EventDate), '00')) as int) as EventYYMM
,year(EventDate) as EventYear
,month(EventDate) as EventMonth
,format(day(EventDate), '00') as EventDay
,Dense_Rank() over (order by EventDate) as EventDateRank
,Dense_Rank() over (order by EventDate desc) as EventDateRankReverse
,Dense_Rank() over (order by concat(year(EventDate), format(month(EventDate), '00'))) as EventMonthRank
,Dense_Rank() over (order by concat(year(EventDate), format(month(EventDate), '00')) desc) as EventMonthRankReverse
into [dbo].[tblDateDimension]
from tblEvent
order by 1




/*backup some events to use as missing or out or range */

drop table if exists [tblEventUpdates]

select * 
into [dbo].[tblEventUpdates]
from tblEvent 
where EventDate >= (
	select distinct YYMMDD from [tblDateDimension]
	where EventDateRankReverse <= 2
)

update tblEvent 
set [EventValue] = 0
where EventDate = (
	select distinct YYMMDD from [tblDateDimension]
	where EventDateRankReverse = 2
)

update tblEvent 
set [EventValue] = [EventValue] * -1
where EventDate = (
	select distinct YYMMDD from [tblDateDimension]
	where EventDateRankReverse = 1
)

select distinct 
d.EventYear
,d.[EventMonth]
,d.[EventDay]
,ProductID
, sum(EventValue) over (Partition by ProductID, d.EventYYMMDD order by d.EventYYMMDD) as DailyTotal
, sum(EventValue) over (Partition by ProductID, d.EventYYMM order by d.EventYYMMDD) as MonthlyRunningTotal
, sum(EventValue) over (Partition by ProductID, EventYear order by d.EventYYMMDD) as ProductYearlyRunningTotal
from tblEvent E
join tblDateDimension D
on e.EventYYMMDD = d.EventYYMMDD
where ProductID = 1
