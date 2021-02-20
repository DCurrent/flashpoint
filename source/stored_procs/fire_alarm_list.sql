USE [EHSINFO]
GO
/****** Object:  StoredProcedure [dbo].[fire_alarm_list]    Script Date: 2/19/2021 10:49:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Create date: 2015-06-09
-- Description:	Get list of tickets, ordered and paged.
-- =============================================

ALTER PROCEDURE [dbo].[fire_alarm_list]
	
	-- Parameters
	
	-- paging
	@page_current		int				= 1,
	@page_rows			int				= 10,	
	@page_last			float			OUTPUT,
	@row_count_total	int				OUTPUT,	
	
	-- filter
	@create_from		datetime2		= NULL,
	@create_to			datetime2		= NULL,
	@update_from		datetime2		= NULL,
	@update_to			datetime2		= NULL,
	@status				int				= NULL,	
	
	-- sorting
	@sort_field			tinyint 		OUTPUT,
	@sort_order			bit				OUTPUT
	
AS	
	SET NOCOUNT ON;
	
	-- Set defaults.
		--filters
		
		-- Sorting field.	
		IF		@sort_field IS NULL 
				OR @sort_field = 0 
				OR @sort_field > 6 SET @sort_field = 4
		
		-- Sorting order.	
		IF		@sort_order IS NULL SET @sort_order = 1
		
		-- Current page.
		IF		@page_current IS NULL SET @page_current = 1
		ELSE IF @page_current < 1 SET @page_current = 1

		-- Rows per page maximum.
		IF		@page_rows IS NULL SET @page_rows = 10
		ELSE IF @page_rows < 1 SET @page_rows = 10

	-- Determine the first record and last record 
	DECLARE @row_first int, 
			@row_last int
	
	-- Set up table var so we can reuse results.		
	DECLARE @tempMain TABLE
	(
		row				int,
		id				int, 
		label			varchar(255),
		details			varchar(max),
		status			tinyint,
		log_create		datetime2,
		log_update		datetime2,
		building_code	varchar(4),
		building_name	varchar(20),
		room_code		varchar(6),
		room_id			varchar(10),
		time_reported	datetime2,
		public_details	varchar(max)
	)	
	
	-- Populate paging first and last row limits.
	SELECT @row_first = (@page_current - 1) * @page_rows
	SELECT @row_last = (@page_current * @page_rows + 1);	
		
	-- Populate main table var. This is the primary query. Order
	-- and query details go here.
	INSERT INTO @tempMain (row, id, label, details, status, log_create, log_update, building_code, building_name, room_code, room_id, time_reported, public_details)
	(SELECT ROW_NUMBER() OVER(ORDER BY 
								-- Sort order options here. CASE lists are ugly, but we'd like to avoid
								-- dynamic SQL for maintainability.
								CASE WHEN @sort_field = 1 AND @sort_order = 0	THEN _main.label	END ASC,
								CASE WHEN @sort_field = 1 AND @sort_order = 1	THEN _main.label	END DESC,
								
								CASE WHEN @sort_field = 2 AND @sort_order = 0	THEN _building.BuildingName END ASC, 
								CASE WHEN @sort_field = 2 AND @sort_order = 1	THEN _building.BuildingName	END DESC,
								
								CASE WHEN @sort_field = 3 AND @sort_order = 0	THEN _main.status			END ASC,
								CASE WHEN @sort_field = 3 AND @sort_order = 1	THEN _main.status			END DESC,
								
								CASE WHEN @sort_field = 4 AND @sort_order = 0	THEN _main.time_reported	END ASC,
								CASE WHEN @sort_field = 4 AND @sort_order = 1	THEN _main.time_reported	END DESC,
								
								CASE WHEN @sort_field = 5 AND @sort_order = 0	THEN _main.log_create		END ASC,
								CASE WHEN @sort_field = 5 AND @sort_order = 1	THEN _main.log_create		END DESC,
								
								CASE WHEN @sort_field = 6 AND @sort_order = 0	THEN _main.log_update		END ASC,
								CASE WHEN @sort_field = 6 AND @sort_order = 1	THEN _main.log_update		END DESC) 
		AS _row_number,
			_main.id, 
			_main.label, 
			_main.details, 
			_main.status, 
			_main.log_create, 
			_main.log_update,
			_main.building_code,
			_building.BuildingName,
			_main.room_code,
			_room.RoomID,
			_main.time_reported,
			_main.public_details
	FROM dbo.tbl_fire_alarm_new _main LEFT JOIN
                      UKSpace.dbo.Rooms AS _room ON _main.room_code = _room.LocationBarCodeID
                      LEFT JOIN
                      UKSpace.dbo.MasterBuildings AS _building ON _main.building_code = _building.BuildingCode
	WHERE (record_deleted IS NULL OR record_deleted = 0)
			AND (log_create >= @create_from	OR @create_from IS NULL OR @create_from = '') 
			AND (log_create <= @create_to	OR @create_to	IS NULL OR @create_to = '')
			AND (log_update >= @update_from OR @update_from IS NULL OR @update_from = '') 
			AND (log_update <= @update_to	OR @update_to	IS NULL OR @update_to = '')
			AND (status		= @status		OR @status		IS NULL OR @status = ''))	
	
	-- Extract paged rows from main tabel var.
	SELECT TOP (@row_last-1) *
	FROM @tempMain	 
	WHERE row > @row_first 
		AND row < @row_last
	ORDER BY row
	
	-- Get a count of records without paging. We'll need this for control
	-- code and for calculating last page. 
	SELECT @row_count_total = (SELECT COUNT(id) FROM @tempMain);
	
	-- Get last page. This is for use by control code.
	SELECT @page_last = (SELECT CEILING(CAST(@row_count_total AS FLOAT) / CAST(@page_rows AS FLOAT)))
	IF @page_last = 0 SET @page_last = 1
	
	
