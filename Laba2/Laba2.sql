-- 9. Показать список авторов в обратном алфавитном порядке (т.е. «Я -> А»).
SELECT * FROM [authors] ORDER BY [a_name] DESC;

-- 10. Показать книги, количество экземпляров которых меньше среднего по библиотеке.
SELECT * FROM [books] WHERE [b_quantity] < (SELECT AVG(CAST([b_quantity] AS FLOAT)) FROM [books]);

-- 15. Показать, сколько в среднем экземпляров книг есть в библиотеке.
SELECT AVG(CAST([b_quantity] AS FLOAT)) AS [avg_books_count] FROM [books];

-- 16. Показать в днях, сколько в среднем времени читатели уже зарегистрированы в библиотеке (временем регистрации считать диапазон от первой даты получения читателем книги до текущей даты).
SELECT AVG(CAST([days] AS FLOAT)) as [avg_days]
FROM (
	SELECT DATEDIFF(day, MIN([sb_start]), CONVERT(date, GETDATE())) as [days]
	FROM [subscriptions]
	GROUP BY [sb_subscriber]
) [all_days];

-- 17. Показать, сколько книг было возвращено и не возвращено в библиотеку (СУБД должна оперировать исходными значениями поля sb_is_active (т.е. «Y» и «N»), а после подсчёта значения «Y» и «N» должны быть преобразованы в «Returned» и «Not returned»).
SELECT (
	CASE
		WHEN [sb_is_active] = 'Y'
		THEN 'Not returned'
		ELSE 'Returned'
	END
) AS [books_status],
COUNT([sb_id]) AS [books_count]
FROM [subscriptions]
GROUP BY (
	CASE
		WHEN [sb_is_active] = 'Y'
		THEN 'Not returned'
		ELSE 'Returned'
	END
)