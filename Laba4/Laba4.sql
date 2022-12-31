-- 4. Отметить все выдачи с идентификаторами ≤ 50 как возвращённые.
UPDATE [subscriptions]
SET [sb_is_active] = N'N'
WHERE [sb_id] <= 50;

-- 5. Для всех выдач, произведённых до 1-го января 2012-го года, уменьшить значение дня выдачи на 3.
UPDATE [subscriptions]
SET [sb_start] = DATEADD(day, -3, [sb_start])
WHERE [sb_start] < CONVERT(date, '2012-01-01');

-- 6. Отметить как невозвращённые все выдачи, полученные читателем с идентификатором 2.
UPDATE [subscriptions]
SET [sb_is_active] = N'Y'
WHERE [sb_subscriber] = 2;

-- 7. Удалить информацию обо всех выдачах читателям книги с идентификатором 1.
DELETE FROM [subscriptions] WHERE [sb_book] = 1

-- 10.	Добавить в базу данных жанры «Политика», «Психология», «История».
MERGE INTO [genres]
USING (
	VALUES (N'Политика'), (N'Психология'), (N'История')
) AS [new_genres]([g_name])
ON [genres].[g_name] = [new_genres].[g_name]
WHEN NOT MATCHED BY TARGET THEN
	INSERT ([g_name])
	VALUES ([new_genres].[g_name]);