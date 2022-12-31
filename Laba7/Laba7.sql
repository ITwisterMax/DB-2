-- 1. Создать хранимую процедуру, которая:
-- a. добавляет каждой книге два случайных жанра;
-- b. отменяет совершённые действия, если в процессе работы хотя бы одна операция вставки завершилась ошибкой в силу дублирования
-- значения первичного ключа таблицы «m2m_books_genres» (т.е. у такой книги уже был такой жанр).
CREATE PROCEDURE TWO_RANDOM_GENRES AS
BEGIN
	DECLARE @b_id_value INT;
	DECLARE @g_id_value INT;
	DECLARE books_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT [b_id] FROM [books];
	DECLARE genres_cursor CURSOR LOCAL FAST_FORWARD FOR SELECT TOP 2 [g_id] FROM [genres] ORDER BY NEWID();
	DECLARE @fetch_books_cursor INT;
	DECLARE @fetch_genres_cursor INT;

	PRINT 'Starting transaction...';
	BEGIN TRANSACTION;
		OPEN books_cursor;
		FETCH NEXT FROM books_cursor INTO @b_id_value;
		SET @fetch_books_cursor = @@FETCH_STATUS;
		WHILE @fetch_books_cursor = 0
			BEGIN
				OPEN genres_cursor;
				FETCH NEXT FROM genres_cursor INTO @g_id_value;
				SET @fetch_genres_cursor = @@FETCH_STATUS;
				WHILE @fetch_genres_cursor = 0
					BEGIN TRY
						INSERT INTO [m2m_books_genres] ([b_id], [g_id])
						VALUES (@b_id_value, @g_id_value);
						FETCH NEXT FROM genres_cursor INTO @g_id_value;
						SET @fetch_genres_cursor = @@FETCH_STATUS;
					END TRY
					BEGIN CATCH
						CLOSE genres_cursor;
						CLOSE books_cursor;
						DEALLOCATE books_cursor;
						DEALLOCATE genres_cursor;

						PRINT 'Rolling transaction back...';
						ROLLBACK TRANSACTION;

						RETURN;
					END CATCH;
				CLOSE genres_cursor;
				FETCH NEXT FROM books_cursor INTO @b_id_value;
				SET @fetch_books_cursor = @@FETCH_STATUS;
			END;
		CLOSE books_cursor;
		DEALLOCATE books_cursor;
		DEALLOCATE genres_cursor;

		PRINT 'Committing transaction...';
		COMMIT TRANSACTION;
END;
GO

-- 2. Создать хранимую процедуру, которая:
-- a. увеличивает значение поля «b_quantity» для всех книг в два раза;
-- b. отменяет совершённое действие, если по итогу выполнения операции среднее количество экземпляров книг превысит значение 50.
CREATE PROCEDURE CHANGE_QUANTITY AS
BEGIN
	DECLARE @avg_quantity FLOAT;
	PRINT 'Starting transaction...';
	BEGIN TRANSACTION;
		UPDATE [books] SET [b_quantity] = [b_quantity] * 2;

		SET @avg_quantity = (SELECT AVG(CAST([b_quantity] AS FLOAT)) FROM [books]);
		IF (@avg_quantity > 50)
			BEGIN
				PRINT 'Rolling transaction back...';
				ROLLBACK TRANSACTION;
			END
		ELSE
			BEGIN
				PRINT 'Committing transaction...';
				COMMIT TRANSACTION;
			END;
END;
GO

-- 3. Написать запросы, которые, будучи выполненными параллельно, обеспечивали бы следующий эффект:
-- a. первый запрос должен считать количество выданных на руки и возвращённых в библиотеку книг и не
-- зависеть от запросов на обновление таблицы «subscriptions» (не ждать их завершения);
SELECT @@SPID;
SET IMPLICIT_TRANSACTIONS ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
BEGIN TRANSACTION;
	SELECT (
		CASE
			WHEN [sb_is_active] = N'Y'
			THEN N'Not returned'
			ELSE N'Returned'
		END
	) AS [books_status],
	COUNT([sb_id]) AS [books_count]
	FROM [subscriptions]
	GROUP BY (
		CASE
			WHEN [sb_is_active] = N'Y'
			THEN N'Not returned'
			ELSE N'Returned'
		END
	)
COMMIT TRANSACTION;
-- b. второй запрос должен инвертировать значения поля «sb_is_active» таблицы subscriptions с «Y» на «N»
-- и наоборот и не зависеть от первого запроса (не ждать его завершения).
SELECT @@SPID;
SET IMPLICIT_TRANSACTIONS ON;
BEGIN TRANSACTION;
	UPDATE [subscriptions] SET [sb_is_active] = CASE WHEN [sb_is_active] = N'Y' THEN N'N' ELSE N'Y' END;
COMMIT TRANSACTION;

-- 6. Создать на таблице «subscriptions» триггер, определяющий уровень изолированности транзакции,
-- в котором сейчас проходит операция обновления, и отменяющий операцию, если уровень изолированности транзакции отличен от REPEATABLE READ.
CREATE TRIGGER [subscriptions_transaction] ON [subscriptions] AFTER UPDATE AS
	DECLARE @isolation_level NVARCHAR(50);
	SET @isolation_level = (
		SELECT [transaction_isolation_level]
		FROM [sys].[dm_exec_sessions]
		WHERE [session_id] = @@SPID
	);

	IF (@isolation_level != 3)
		BEGIN
			RAISERROR ('Please, switch your transaction to REPEATABLE READ isolation level and return this UPDATE again.', 16, 1);
			ROLLBACK TRANSACTION;

			RETURN
		END;
GO

-- 7. Создать хранимую функцию, порождающую исключительную ситуацию в случае, если выполняются оба условия
-- (подсказка: эта задача имеет решение только для MS SQL Server):
-- a. режим автоподтверждения транзакций выключен;
-- b. функция запущена из вложенной транзакции.
CREATE FUNCTION NO_AUTOCOMMIT_AND_NESTED_TRANSACTION() RETURNS INT WITH SCHEMABINDING AS
BEGIN
	DECLARE @autocommit INT;
	IF (@@TRANCOUNT = 0 AND (@@OPTIONS & 2 = 0))
		BEGIN
			SET @autocommit = 1;
		END
	ELSE IF (@@TRANCOUNT = 0 AND (@@OPTIONS & 2 = 2))
		BEGIN
			SET @autocommit = 0;
		END
	ELSE IF (@@OPTIONS & 2 = 0)
		BEGIN
			SET @autocommit = 1;
		END
	ELSE
		BEGIN
			SET @autocommit = 0;
		END;
	IF (@autocommit = 1 AND @@TRANCOUNT >= 2)
		BEGIN
			RETURN CAST('Please, turn the autocommit off and do not use nested transaction.' AS INT);
		END;

	RETURN 0;
END;
GO