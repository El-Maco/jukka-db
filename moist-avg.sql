SELECT
    strftime('%s', date(m.timestamp)) AS time,
    (
        (
            p.max_reading -
            AVG(
                CASE
                    WHEN m.value < p.min_reading THEN p.min_reading
                    WHEN m.value > p.max_reading THEN p.max_reading
                    ELSE m.value
                END
            )
        ) * 100.0 / (p.max_reading - p.min_reading)
    ) AS value,
    p.name AS metric
FROM measurement m
JOIN plant p
    ON m.plant_id = p.id
GROUP BY
    date(m.timestamp),
    p.id,
    p.name,
    p.min_reading,
    p.max_reading
ORDER BY time;
