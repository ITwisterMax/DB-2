-- 1. —оздать представление, позвол€ющее получать список читателей с количеством наход€щихс€ у каждого читател€ на руках книг,
-- но отображающее только таких читателей, по которым имеютс€ задолженности, т.е. на руках у читател€ есть хот€ бы одна книга,
-- которую он должен был вернуть до наступлени€ текущей даты.
CREATE VIEW [subscribers_with_arrears] AS
	SELECT [subscribers].[s_id], [s_name], COUNT([sb_book]) AS [books_count]
	FROM [subscribers]
	JOIN [subscriptions] ON [subscribers].[s_id] = [subscriptions].[sb_subscriber]
	WHERE [sb_is_active] = N'Y' AND [sb_finish] < CONVERT(date, GETDATE())
	GROUP BY [subscribers].[s_id], [s_name];

-- 4. —оздать представление, через которое невозможно получить информацию о том, кака€ конкретно книга была выдана читателю в любой из выдач.
CREATE VIEW [books_anonymous] WITH SCHEMABINDING AS
	SELECT [sb_id], [sb_subscriber], [sb_start], [sb_finish], [sb_is_active]
FROM [dbo].[subscriptions];

-- 13. —оздать триггер, не позвол€ющий добавить в базу данных информацию о выдаче книги, если выполн€етс€ хот€ бы одно из условий:
-- a. дата выдачи или возврата приходитс€ на воскресенье;
-- b. читатель брал за последние полгода более 100 книг;
-- c. промежуток времени между датами выдачи и возврата менее трЄх дней.
CREATE TRIGGER [subscriptions_control] ON [subscriptions] AFTER INSERT AS
	DECLARE @bad_records NVARCHAR(max);
	DECLARE @msg NVARCHAR(max);
	-- a. дата выдачи или возврата приходитс€ на воскресенье
	SELECT @bad_records = STUFF((
		SELECT ', ' + CAST([sb_id] AS NVARCHAR) + ' (start: ' + CAST([sb_start] AS NVARCHAR) + '; ' + 'finish: ' + CAST([sb_finish] AS NVARCHAR) + ')'
		FROM [inserted]
		WHERE DATEPART(weekday, [sb_start]) = 1 OR DATEPART(weekday, [sb_finish]) = 1
		ORDER BY [sb_id]
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '');
	IF LEN(@bad_records) > 0
		BEGIN
			SET @msg = CONCAT('The following subscriptions has a start or finish date on sunday: ', @bad_records);
			RAISERROR (@msg, 16, 1);
			ROLLBACK TRANSACTION;
			RETURN
		END;
	-- b. читатель брал за последние полгода более 100 книг
	SELECT @bad_records = STUFF((
		SELECT ', ' + CAST([sb_subscriber] AS NVARCHAR) + ' (books count: ' + CAST(COUNT([sb_book]) AS NVARCHAR) + ')'
		FROM [subscriptions]
		WHERE [subscriptions].[sb_subscriber] IN (SELECT [sb_subscriber] FROM [inserted]) AND ABS(DATEDIFF(month, [sb_start], CONVERT(date, GETDATE()))) <= 6
		GROUP BY [sb_subscriber]
		HAVING COUNT([sb_book]) > 100
		ORDER BY [sb_subscriber]
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '');
	IF LEN(@bad_records) > 0
		BEGIN
			SET @msg = CONCAT('The following subscribers has more than 100 books in the last six months: ', @bad_records);
			RAISERROR (@msg, 16, 1);
			ROLLBACK TRANSACTION;
			RETURN
		END;
	-- c. промежуток времени между датами выдачи и возврата менее трЄх дней
	SELECT @bad_records = STUFF((
		SELECT ', ' + CAST([sb_id] AS NVARCHAR) + ' (start: ' + CAST([sb_start] AS NVARCHAR) + '; ' + 'finish: ' + CAST([sb_finish] AS NVARCHAR) + ')'
		FROM [inserted]
		WHERE ABS(DATEDIFF(day, [sb_start], [sb_finish])) < 3
		ORDER BY [sb_id]
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '');
	IF LEN(@bad_records) > 0
		BEGIN
			SET @msg = CONCAT('The following subscriptions has a the time interval between the start and finish date is less than three days: ', @bad_records);
			RAISERROR (@msg, 16, 1);
			ROLLBACK TRANSACTION;
			RETURN
		END;
GO

-- 14. —оздать триггер, не позвол€ющий выдать книгу читателю, у которого на руках находитс€ п€ть и более книг, при условии,
-- что суммарное врем€, оставшеес€ до возврата всех выданных ему книг, составл€ет менее одного мес€ца.
CREATE TRIGGER [subscriptions_control_books_count] ON [subscriptions] INSTEAD OF INSERT AS
	DECLARE @bad_records NVARCHAR(max);
	DECLARE @msg NVARCHAR(max);
	SELECT @bad_records = STUFF((
		SELECT ', ' + [list] FROM (
			SELECT
				CONCAT('(subsctiber id:', [sb_subscriber], '; books count: ', COUNT([sb_book]), ')') AS [list],
				SUM(
					CASE
						WHEN CONVERT(date, GETDATE()) >= [sb_finish]
						THEN 0
						ELSE DATEDIFF(day, CONVERT(date, GETDATE()), [sb_finish])
					END
				) as [days_sum]
			FROM [subscriptions]
			WHERE [sb_subscriber] IN (SELECT [sb_subscriber] FROM [inserted]) AND [sb_is_active] = N'Y'
			GROUP BY [sb_subscriber]
			HAVING COUNT([sb_book]) >= 5
		) AS [prepared_data]
		WHERE [days_sum] BETWEEN 0 and 30
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '');
	IF (LEN(@bad_records) > 0)
		BEGIN
			SET @msg = CONCAT('The following readers have more books than allowed (5 allowed): ', @bad_records);
			RAISERROR (@msg, 16, 1);
			ROLLBACK TRANSACTION;
			RETURN;
		END;
	SET IDENTITY_INSERT [subscriptions] ON;
	INSERT INTO [subscriptions] (
		[sb_id],
		[sb_subscriber],
		[sb_book],
		[sb_start],
		[sb_finish],
		[sb_is_active]
	)
	SELECT (
		CASE
			WHEN [sb_id] IS NULL OR [sb_id] = 0
			THEN
				IDENT_CURRENT('subscriptions') + IDENT_INCR('subscriptions') + ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1
			ELSE 
				[sb_id]
		END 
	) AS [sb_id],
		[sb_subscriber],
		[sb_book],
		[sb_start],
		[sb_finish],
		[sb_is_active]
	FROM [inserted];
SET IDENTITY_INSERT [subscriptions] OFF;
GO

-- 17. —оздать триггер, мен€ющий дату выдачи книги на текущую, если указанна€ в INSERT- или UPDATE-запросе дата выдачи книги меньше текущей на полгода и более.
-- INSERT-запрос
CREATE TRIGGER [subscriptions_start_date_insert] ON [subscriptions] INSTEAD OF INSERT AS
	DECLARE @bad_records NVARCHAR(max);
	DECLARE @msg NVARCHAR(max);
	SELECT @bad_records = STUFF((
		SELECT ', ' + '[' + CAST([sb_start] AS NVARCHAR) + '] -> [' + CAST(CONVERT(date, GETDATE()) AS NVARCHAR) + ']'
		FROM [inserted]
		WHERE DATEDIFF(month, [sb_start], CONVERT(date, GETDATE())) >= 6
		FOR XML PATH(''), TYPE
		).value('.', 'nvarchar(max)'), 1, 2, '');
	IF (LEN(@bad_records) > 0)
		BEGIN
			SET @msg = CONCAT('Some values were changed: ', @bad_records);
			PRINT @msg;
			RAISERROR (@msg, 16, 0);
		END;
	SET IDENTITY_INSERT [subscriptions] ON;
	INSERT INTO [subscriptions] (
		[sb_id],
		[sb_subscriber],
		[sb_book],
		[sb_start],
		[sb_finish],
		[sb_is_active])
	SELECT (
		CASE
			WHEN [sb_id] IS NULL OR [sb_id] = 0
			THEN
				IDENT_CURRENT('subscriptions') + IDENT_INCR('subscriptions') + ROW_NUMBER() OVER (ORDER BY (SELECT 1)) - 1
			ELSE
				[sb_id]
		END
	) AS [sb_id],
		[sb_subscriber],
		[sb_book],
		(
			CASE
				WHEN (DATEDIFF(month, [sb_start], CONVERT(date, GETDATE())) >= 6)
				THEN
					CONVERT(date, GETDATE())
				ELSE
					[sb_start]
			END
		) AS [sb_start],
		[sb_finish],
		[sb_is_active]
FROM [inserted];
SET IDENTITY_INSERT [subscriptions] OFF;
GO
-- UPDATE-запрос
CREATE TRIGGER [subscriptions_start_date_update] ON [subscriptions] INSTEAD OF UPDATE AS
	DECLARE @bad_records NVARCHAR(max);
	DECLARE @msg NVARCHAR(max);
	IF (UPDATE([sb_id]))
		BEGIN
		RAISERROR ('Please, do NOT update surrogate PK on table [subscriptions]', 16, 1);
		ROLLBACK TRANSACTION;
		RETURN;
	END;
	SELECT @bad_records = STUFF((
		SELECT ', ' + '[' + CAST([sb_start] AS NVARCHAR) + '] -> [' + CAST(CONVERT(date, GETDATE()) AS NVARCHAR) + ']'
		FROM [inserted]
		WHERE ABS(DATEDIFF(month, [sb_start], CONVERT(date, GETDATE()))) >= 6
		FOR XML PATH(''), TYPE
	).value('.', 'nvarchar(max)'), 1, 2, '');
	IF (LEN(@bad_records) > 0)
		BEGIN
			SET @msg = CONCAT('Some values were changed: ', @bad_records);
			PRINT @msg;
			RAISERROR (@msg, 16, 0);
		END;
	UPDATE [subscriptions]
	SET [subscriptions].[sb_subscriber] = [inserted].[sb_subscriber],
		[subscriptions].[sb_book] = [inserted].[sb_book],
		[subscriptions].[sb_start] = (
			CASE
				WHEN (DATEDIFF(month, [inserted].[sb_start], CONVERT(date, GETDATE())) >= 6)
				THEN
					CONVERT(date, GETDATE())
				ELSE
					[inserted].[sb_start]
			END
		),
		[subscriptions].[sb_finish] = [inserted].[sb_finish],
		[subscriptions].[sb_is_active] = [inserted].[sb_is_active]
	FROM [subscriptions] JOIN [inserted] ON [subscriptions].[sb_id] = [inserted].[sb_id];
GO