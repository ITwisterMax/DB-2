-- 3. Показать все книги с их жанрами (дублирование названий книг не допускается).
SELECT
	[books].[b_id],
	[books].[b_name] AS [book],
	STRING_AGG([g_name], ', ') WITHIN GROUP (ORDER BY [g_name] ASC) AS [genres]
FROM [books]
	JOIN [m2m_books_genres] ON [books].[b_id] = [m2m_books_genres].[b_id]
	JOIN [genres] ON [m2m_books_genres].[g_id] = [genres].[g_id]
GROUP BY [books].[b_id], [books].[b_name]
ORDER BY [books].[b_name];

-- 11.	Показать книги, относящиеся к более чем одному жанру.
SELECT
	[books].[b_id],
	[books].[b_name] AS [book],
	COUNT([genres].[g_id]) AS [genres_count]
FROM [books]
	JOIN [m2m_books_genres] ON [books].[b_id] = [m2m_books_genres].[b_id]
	JOIN [genres] ON [m2m_books_genres].[g_id] = [genres].[g_id]
GROUP BY [books].[b_id], [books].[b_name]
HAVING COUNT([genres].[g_id]) > 1
ORDER BY [books].[b_name];

-- 15.	Показать всех авторов и количество книг (не экземпляров книг, а «книг как изданий») по каждому автору.
SELECT
	[authors].[a_id],
	[a_name] AS [author],
	COUNT([b_id]) AS [books_count]
FROM [authors]
	JOIN [m2m_books_authors] ON [authors].[a_id] = [m2m_books_authors].[a_id]
GROUP BY [authors].[a_id], [authors].[a_name]
ORDER BY [authors].[a_name];

-- 16.	Показать всех читателей, не вернувших книги, и количество невозвращённых книг по каждому такому читателю.
SELECT
	[s_id],
	[s_name] AS [subscribers],
	COUNT([sb_book]) AS [not_returned_books_count]
FROM [subscribers]
	JOIN [subscriptions] ON [subscribers].[s_id] = [subscriptions].[sb_subscriber]
WHERE [sb_is_active] = N'Y'
GROUP BY [subscribers].[s_id], [subscribers].[s_name]
ORDER BY [subscribers].[s_name];

-- 23.	Показать читателя, последним взявшего в библиотеке книгу.
SELECT TOP(1)
	[s_id],
	[s_name] AS [last_subscriber],
	MAX(sb_start) as [start]
FROM [subscribers]
	JOIN [subscriptions] ON [subscribers].[s_id] = [subscriptions].[sb_subscriber]
GROUP BY [subscribers].[s_id], [subscribers].[s_name]
ORDER BY [start] DESC;