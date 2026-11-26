-- =====================================================================
-- ПОДГОТОВКА ДАННЫХ
-- =====================================================================
INSERT INTO space_type (name) VALUES ('Meeting room');
INSERT INTO app_user (email, full_name) VALUES ('test@example.com', 'Test User');
INSERT INTO space (code, capacity, type_id) VALUES ('R101', 10, 1);
INSERT INTO equipment (name) VALUES ('Projector');
INSERT INTO space_equipment (space_id, equipment_id, quantity) VALUES (1, 1, 1);

-- =====================================================================
-- 1. CHECK (capacity > 0) - Негативный тест
-- =====================================================================
-- Ожидаемая ошибка: new row for relation "space" violates check constraint "space_capacity_check"
-- INSERT INTO space (code, capacity, type_id) VALUES ('R102', 0, 1);

-- =====================================================================
-- 2. CHECK (position('@' IN email) > 1) - Негативный тест
-- =====================================================================
-- Ожидаемая ошибка: violates check constraint "app_user_email_check"
-- INSERT INTO app_user (email, full_name) VALUES ('invalid-email', 'No At Sign');

-- =====================================================================
-- 3. UNIQUE (code) - Негативный тест
-- =====================================================================
-- Ожидаемая ошибка: duplicate key value violates unique constraint "space_code_key"
-- INSERT INTO space (code, capacity, type_id) VALUES ('R101', 5, 1);

-- =====================================================================
-- 4. FOREIGN KEY (ON DELETE RESTRICT) - Негативный тест
-- =====================================================================
-- Ожидаемая ошибка: update or delete on table "space_type" violates foreign key constraint
-- DELETE FROM space_type WHERE type_id = 1;

-- =====================================================================
-- 5. EXCLUSION CONSTRAINT (пересечение броней) - Позитив и Негатив
-- =====================================================================
-- Позитивный: создаем первую бронь
INSERT INTO booking (space_id, user_id, time_range, status)
VALUES (1, 1, tstzrange('2025-05-01 10:00+00', '2025-05-01 12:00+00'), 'CONFIRMED');

-- Негативный: пытаемся создать пересекающуюся бронь на то же пространство
-- Ожидаемая ошибка: conflicting key value violates exclusion constraint "booking_space_id_time_range_excl"
-- INSERT INTO booking (space_id, user_id, time_range, status)
-- VALUES (1, 1, tstzrange('2025-05-01 11:00+00', '2025-05-01 13:00+00'), 'CONFIRMED');

-- Позитивный (граничный): создаем бронь с отмененным статусом (не должна конфликтовать)
INSERT INTO booking (space_id, user_id, time_range, status)
VALUES (1, 1, tstzrange('2025-05-01 11:00+00', '2025-05-01 13:00+00'), 'CANCELLED');