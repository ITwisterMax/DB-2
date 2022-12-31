-- 9. �������� ������ ������� � �������� ���������� ������� (�.�. �� -> ��).
SELECT * FROM [authors] ORDER BY [a_name] DESC;

-- 10. �������� �����, ���������� ����������� ������� ������ �������� �� ����������.
SELECT * FROM [books] WHERE [b_quantity] < (SELECT AVG(CAST([b_quantity] AS FLOAT)) FROM [books]);

-- 15. ��������, ������� � ������� ����������� ���� ���� � ����������.
SELECT AVG(CAST([b_quantity] AS FLOAT)) AS [avg_books_count] FROM [books];

-- 16. �������� � ����, ������� � ������� ������� �������� ��� ���������������� � ���������� (�������� ����������� ������� �������� �� ������ ���� ��������� ��������� ����� �� ������� ����).
SELECT AVG(CAST([days] AS FLOAT)) as [avg_days]
FROM (
	SELECT DATEDIFF(day, MIN([sb_start]), CONVERT(date, GETDATE())) as [days]
	FROM [subscriptions]
	GROUP BY [sb_subscriber]
) [all_days];

-- 17. ��������, ������� ���� ���� ���������� � �� ���������� � ���������� (���� ������ ����������� ��������� ���������� ���� sb_is_active (�.�. �Y� � �N�), � ����� �������� �������� �Y� � �N� ������ ���� ������������� � �Returned� � �Not returned�).
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