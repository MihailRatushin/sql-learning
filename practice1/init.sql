-- Расширение для exclusion constraint по скалярному столбцу (space_id)
CREATE
EXTENSION IF NOT EXISTS btree_gist;

-- Типы пространств
CREATE TABLE space_type
(
    type_id     BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL UNIQUE,
    description TEXT
);

-- Пользователи
CREATE TABLE app_user
(
    user_id    BIGSERIAL PRIMARY KEY,
    email      TEXT        NOT NULL UNIQUE CHECK (position('@' IN email) > 1),
    full_name  TEXT        NOT NULL,
    role       TEXT        NOT NULL DEFAULT 'member'
        CHECK (role IN ('guest', 'member', 'admin')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Пространства (рабочие места / переговорные)
CREATE TABLE space
(
    space_id  BIGSERIAL PRIMARY KEY,
    code      TEXT    NOT NULL UNIQUE,
    capacity  INT     NOT NULL CHECK (capacity > 0),
    type_id   BIGINT  NOT NULL REFERENCES space_type (type_id) ON DELETE RESTRICT,
    is_active BOOLEAN NOT NULL DEFAULT true
);

-- Бронирования
CREATE TABLE booking
(
    booking_id BIGSERIAL PRIMARY KEY,
    space_id   BIGINT      NOT NULL REFERENCES space (space_id) ON DELETE RESTRICT,
    user_id    BIGINT      NOT NULL REFERENCES app_user (user_id) ON DELETE RESTRICT,
    time_range TSTZRANGE   NOT NULL,
    status     TEXT        NOT NULL DEFAULT 'CONFIRMED'
        CHECK (status IN ('CONFIRMED', 'CANCELLED', 'EXPIRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- интервал должен быть непустым и корректным
    CHECK (NOT isempty(time_range)),
    CHECK (lower(time_range) < upper(time_range)),

    -- запрет пересечения АКТИВНЫХ броней одного пространства
    EXCLUDE USING GIST (
        space_id WITH =,
        time_range WITH &&
    ) WHERE (status = 'CONFIRMED')
);

-- Стартовые данные (опционально)
INSERT INTO space_type (name, description)
VALUES ('Open space', 'Рабочие места в открытом пространстве'),
       ('Meeting room', 'Переговорная комната');