# Бронирование коворкинга — PostgreSQL Practice 1

Репозиторий содержит анализ требований, обоснование выбора СУБД, сравнение SQL/NoSQL, локальное окружение PostgreSQL и smoke-тесты.

## Выбор СУБД

### Сравнительная таблица

| Критерий | PostgreSQL | MySQL | SQL Server / Oracle |
|---|---|---|---|
| **Модель данных и JSONB** | Полноценный JSONB с GIN-индексами, операторами `@>`, `?`, `#>`[reference:0] | JSON есть, но индексация и операторы ограничены[reference:1] | SQL Server: JSON через `JSON_VALUE`/`OPENJSON`; Oracle: JSON поддержан, но гибкость ниже[reference:2] |
| **Транзакции и MVCC** | Полноценный MVCC, уровни изоляции `READ COMMITTED` … `SERIALIZABLE` | InnoDB MVCC, но исторически слабее в сложных конкурентных сценариях[reference:3] | SQL Server: MVCC через `READ COMMITTED SNAPSHOT`; Oracle: мощный MVCC, но дорогой |
| **Ограничения целостности (FK, CHECK, EXCLUDE)** | FK, CHECK, **EXCLUDE USING GIST** (через `btree_gist`) — уникальная возможность для запрета пересечений[reference:4] | FK, CHECK; exclusion-ограничений нет | SQL Server: FK, CHECK; exclusion нет. Oracle: FK, CHECK; exclusion нет |
| **RLS и безопасность** | **Нативный Row-Level Security**[reference:5][reference:6] | RLS только через представления[reference:7] | RLS через представления / политики |
| **Экосистема и инструменты (EXPLAIN, pg_stat_statements)** | `EXPLAIN (ANALYZE, BUFFERS)`, `pg_stat_statements`, `auto_explain`, богатые расширения[reference:8] | `EXPLAIN`, performance_schema; менее гибко | SQL Server: Query Store, execution plans; Oracle: AWR, но проприетарно |
| **Стоимость / облако** | Полностью open-source; дешёвый managed (RDS, Cloud SQL, Supabase) | Open-source (GPL) + коммерческая лицензия; managed дешёвый | SQL Server: дорогие лицензии; Oracle: очень дорого |

### Вывод

Для проекта **выбран PostgreSQL 16**, потому что:
1. Требование «запрет пересечения активных броней» наилучшим образом реализуется через **exclusion constraint** (`EXCLUDE USING GIST (space_id WITH =, time_range WITH &&) WHERE (status = 'CONFIRMED')`), который напрямую поддерживается только в PostgreSQL среди рассмотренных СУБД.
2. Нужна надёжная **ACID-транзакционность** для конкурентных операций бронирования — PostgreSQL обеспечивает строгую изоляцию и MVCC.
3. В перспективе может потребоваться **RLS** для разграничения доступа сотрудников к своим броням — в PostgreSQL это нативный механизм.
4. PostgreSQL бесплатен и хорошо документирован, что снижает стоимость владения и ускоряет разработку.

---

## SQL vs NoSQL

### Выбранный сценарий: хранение событий бронирования (audit log)

**Что нужно хранить:** каждое изменение брони — создание, отмена, истечение, изменение интервала. События должны быть упорядочены по времени и привязаны к брони и пользователю.

**Необходимые запросы:**
- История событий по конкретной брони.
- События за период (для отчётов и аудита).
- События по пользователю (для разбора инцидентов).
- Агрегация: количество отмен за месяц.

**Нужны ли JOIN и транзакции:**
- JOIN нужен для связи события с `booking`, `app_user`, `space`.
- Транзакции нужны, чтобы запись события была атомарной с изменением статуса брони.

### Схема в реляционном варианте (PostgreSQL)

```sql
CREATE TABLE booking_event (
    event_id   BIGSERIAL PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES booking(booking_id),
    event_type TEXT NOT NULL CHECK (event_type IN ('CREATED','CANCELLED','EXPIRED')),
    payload    JSONB,          -- опционально: снимок данных
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```
Плюсы: строгая целостность (FK), транзакционность, удобные JOIN и агрегаты, знакомый SQL

### Схема в документной модели
```
{
  "_id": "evt_123",
  "bookingId": 42,
  "userId": 7,
  "spaceId": 3,
  "eventType": "CANCELLED",
  "timestamp": "2025-03-15T10:00:00Z",
  "payload": { "reason": "user_request" }
}
```
Плюсы: гибкая схема, быстрая запись событий, естественное хранение вложенных данных.
Минусы: нет FK-целостности (можно записать событие для несуществующей брони), JOIN-ы эмулируются на уровне приложения ($lookup), транзакции между коллекциями ограничены.