-- 1. Версия
SELECT version();

-- 2. Вставка корректных данных
INSERT INTO space (code, capacity, type_id)
VALUES ('A101', 4, 1),
       ('A102', 6, 1);

INSERT INTO app_user (email, full_name, role)
VALUES ('a@example.com', 'Alice', 'member'),
       ('b@example.com', 'Bob', 'member');

-- 3. Чтение
SELECT *
FROM space;
SELECT *
FROM app_user;

-- 4. Проверка exclusion constraint (негативный тест пересечения)
-- Сначала создаём корректную бронь:
INSERT INTO booking (space_id, user_id, time_range, status)
VALUES (1,
        1,
        tstzrange('2025-04-01 10:00+00', '2025-04-01 12:00+00'),
        'CONFIRMED');

-- Попытка вставить пересекающуюся бронь того же пространства:
-- ОЖИДАЕТСЯ ОШИБКА EXCLUSION VIOLATION
INSERT INTO booking (space_id, user_id, time_range, status)
VALUES (1,
        2,
        tstzrange('2025-04-01 11:00+00', '2025-04-01 13:00+00'),
        'CONFIRMED');

-- 5. Негативный тест FK
INSERT INTO booking (space_id, user_id, time_range)
VALUES (999999, 999999, tstzrange('2025-04-02 10:00+00', '2025-04-02 11:00+00'));
ОЖИДАЕТСЯ ОШИБКА FOREIGN KEY VIOLATION