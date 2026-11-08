SELECT
    strftime('%s', m.timestamp) AS time,
    (
        (p.max_reading -
            CASE
                WHEN m.value < p.min_reading THEN p.min_reading
                WHEN m.value > p.max_reading THEN p.max_reading
                ELSE m.value
            END
        ) * 100.0 / (p.max_reading - p.min_reading)
    ) AS value,
    p.name AS metric
FROM measurement m
JOIN plant p
    ON m.plant_id = p.id
ORDER BY time;
