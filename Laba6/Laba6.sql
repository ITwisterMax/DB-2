-- 1. —оздать хранимую функцию, получающую на вход идентификатор читател€ и возвращающую список идентификаторов книг, которые он уже прочитал и вернул в библиотеку.
CREATE FUNCTION GET_BOOK_IDS_BY_SUBSCRIBER_ID(@subscriber_id INT)
RETURNS @book_ids TABLE ([book_id] INT)
AS
BEGIN
	INSERT @book_ids
	SELECT [sb_book]
	FROM [subscriptions]
	WHERE [sb_subscriber] = @subscriber_id AND [sb_is_active] = N'N';

	RETURN;
END;
GO

-- 3. —оздать хранимую функцию, получающую на вход идентификатор читател€ и возвращающую 1, если у читател€ на руках сейчас менее дес€ти книг, и 0 в противном случае.
CREATE FUNCTION CHECK_BOOKS_COUNT_BY_SUBSCRIBER_ID(@subscriber_id INT)
RETURNS BIT
AS
BEGIN
	DECLARE @books_count INT;

	SELECT @books_count = COUNT([sb_book])
	FROM [subscriptions]
	WHERE [sb_subscriber] = @subscriber_id AND [sb_is_active] = N'Y';

	RETURN CASE
		WHEN (@books_count < 10) THEN 1 ELSE 0
	END;
END;
GO

-- 4. —оздать хранимую функцию, получающую на вход год издани€ книги и возвращающую 1, если книга издана менее ста лет назад, и 0 в противном случае.
CREATE FUNCTION CHECK_BOOK_CREATED_YEAR(@book_created_year INT)
RETURNS BIT
AS
BEGIN
	DECLARE @current_year INT = YEAR(CONVERT(date, GETDATE()));

	RETURN CASE
		WHEN (@current_year - @book_created_year < 100) THEN 1 ELSE 0
	END;
END;
GO

-- 9. —оздать хранимую процедуру, автоматически создающую и наполн€ющую данными таблицу Ђarrearsї, в которой должны быть представлены идентификаторы и
-- имена читателей, у которых до сих пор находитс€ на руках хот€ бы одна книга, по которой дата возврата установлена в прошлом относительно текущей даты.
CREATE PROCEDURE CREATE_ARREARS_TABLE AS
BEGIN
	IF NOT EXISTS (
		SELECT [name]
		FROM sys.tables
		WHERE [name] = 'arrears'
	)
		BEGIN
			CREATE TABLE [arrears] (
				[subscriber_id] INT NOT NULL,
				[subscriber_name] NVARCHAR(150) NOT NULL
			);
			INSERT INTO [arrears] (
				[subscriber_id],
				[subscriber_name]
			)
			SELECT [sb_subscriber] AS [subscriber_id], [s_name] AS [subscriber_name]
			FROM [subscriptions]
			JOIN [subscribers] ON [sb_subscriber] = [s_id]
			WHERE [sb_is_active] = N'Y' AND [sb_finish] < CONVERT(date, GETDATE())
			GROUP BY [sb_subscriber], [s_name];
		END
	ELSE
		BEGIN
			UPDATE [arrears] SET
				[arrears].[subscriber_id] = [src].[subscriber_id],
				[arrears].[subscriber_name] = [src].[subscriber_name]
			FROM [arrears]
			JOIN (
				SELECT [sb_subscriber] AS [subscriber_id], [s_name] AS [subscriber_name]
				FROM [subscriptions]
				JOIN [subscribers] ON [sb_subscriber] = [s_id]
				WHERE [sb_is_active] = N'Y' AND [sb_finish] < CONVERT(date, GETDATE())
				GROUP BY [sb_subscriber], [s_name]
			) AS [src] ON 1 = 1;
		END;
END;
GO

-- 11. —оздать хранимую процедуру, удал€ющую все представлени€, дл€ которых SELECT COUNT(1) FROM представление возвращает значение меньше дес€ти.
CREATE PROCEDURE DROP_VIEWS AS
BEGIN
	DECLARE @view_name SYSNAME;
	DECLARE @view_rows_count INT;
	DECLARE @query_text NVARCHAR(2000);
	DECLARE views_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT [table_name] FROM [information_schema].[views]

	OPEN views_cursor;
	FETCH NEXT FROM views_cursor INTO @view_name;
	WHILE @@FETCH_STATUS = 0
		BEGIN
			SET @query_text = CONCAT('SELECT @count = COUNT(1) FROM [', @view_name, ']');
			EXECUTE sp_executesql @query_text, N'@count INT OUT', @view_rows_count OUTPUT;
			IF (@view_rows_count < 10)
				BEGIN
					SET @query_text = CONCAT('DROP VIEW [', @view_name, ']');
					EXECUTE sp_executesql @query_text;
				END;
			FETCH NEXT FROM views_cursor INTO @view_name;
		END;
	CLOSE views_cursor;
	DEALLOCATE views_cursor;
END;
GO