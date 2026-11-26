-- Расширение для exclusion constraint (пересечение интервалов)
CREATE
EXTENSION IF NOT EXISTS btree_gist;

-- 1. Справочник типов пространств
CREATE TABLE space_type
(
    type_id     BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    description TEXT
);

COMMENT
ON TABLE space_type IS 'Справочник типов пространств (опенспейс, переговорная)';

-- 2. Пользователи
CREATE TABLE app_user
(
    user_id    BIGSERIAL PRIMARY KEY,
    email      TEXT        NOT NULL UNIQUE CHECK (position('@' IN email) > 1),                     -- Альтернативный ключ + CHECK
    full_name  TEXT        NOT NULL,
    role       TEXT        NOT NULL DEFAULT 'member' CHECK (role IN ('guest', 'member', 'admin')), -- DEFAULT + CHECK
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT
ON COLUMN app_user.email IS 'Уникальный email, используется как альтернативный ключ';

-- 3. Оборудование
CREATE TABLE equipment
(
    equipment_id BIGSERIAL PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,
    description  TEXT
);

-- 4. Пространства (с рекурсивной связью)
CREATE TABLE space
(
    space_id        BIGSERIAL PRIMARY KEY,
    code            TEXT    NOT NULL UNIQUE,               -- Альтернативный ключ
    capacity        INT     NOT NULL CHECK (capacity > 0), -- CHECK
    type_id         BIGINT  NOT NULL REFERENCES space_type (type_id) ON DELETE RESTRICT,
    -- RESTRICT: нельзя удалить тип, если к нему привязаны пространства (защита целостности)
    parent_space_id BIGINT  REFERENCES space (space_id) ON DELETE SET NULL,
    -- SET NULL: если родительское пространство удалено, дочерние становятся корневыми
    is_active       BOOLEAN NOT NULL DEFAULT true
);

COMMENT
ON COLUMN space.parent_space_id IS 'Рекурсивная связь: определяет родительское пространство (например, этаж)';

-- 5. Связь M:N (Слабая сущность)
CREATE TABLE space_equipment
(
    space_id     BIGINT NOT NULL REFERENCES space (space_id) ON DELETE CASCADE,
    -- CASCADE: при удалении пространства удаляется и запись об его оснащении
    equipment_id BIGINT NOT NULL REFERENCES equipment (equipment_id) ON DELETE RESTRICT,
    -- RESTRICT: нельзя удалить оборудование, если оно где-то числится
    quantity     INT    NOT NULL DEFAULT 1 CHECK (quantity > 0),
    PRIMARY KEY (space_id, equipment_id) -- Составной первичный ключ
);

-- 6. Бронирования
CREATE TABLE booking
(
    booking_id BIGSERIAL PRIMARY KEY,
    space_id   BIGINT      NOT NULL REFERENCES space (space_id) ON DELETE RESTRICT,
    -- RESTRICT: нельзя удалить пространство, по которому есть история броней
    user_id    BIGINT      NOT NULL REFERENCES app_user (user_id) ON DELETE RESTRICT,
    -- RESTRICT: нельзя удалить пользователя с историей броней
    time_range TSTZRANGE   NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'CONFIRMED' CHECK (status IN ('CONFIRMED', 'CANCELLED', 'EXPIRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (NOT isempty(time_range)),
    CHECK (lower(time_range) < upper(time_range)),

    -- Исключение пересечений активных броней
    EXCLUDE USING GIST (
        space_id WITH =,
        time_range WITH &&
    ) WHERE (status = 'CONFIRMED')
);