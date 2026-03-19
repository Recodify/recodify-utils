create table analytics.tables ENGINE = MergeTree
order by
    table AS
select
    t.total_rows,
    t.uuid as table_uuid,
    a.database,
    a.table,
    a.source_table,
    a.source_database,
    a.create_ddl,
    a.populate_query,
    a.event_time,
    a.query as create_ddl_raw,
    t.create_table_query
from
    (
        select
            event_time,
            tables [1] as source_table_raw,
            tables [length(tables)] as table_raw,
            splitByChar('.', source_table_raw) [2] as source_table,
            splitByChar('.', table_raw) [2] as table,
            query,
            splitByRegexp('select', query, 2) as ddl,
            ddl [1] as create_ddl,
            concat('select', ddl [2]) as populate_query,
            tables,
            databases,
            splitByChar('.', source_table_raw) [1] as source_database,
            splitByChar('.', table_raw) [1] as database
        from
            system.query_log
        where
            type = 'QueryFinish'
            and query_kind = 'Create'
            and length(tables) > 1
    ) as a
    inner join system.tables t on t.name = a.table
    and t.database = a.database;

CREATE MATERIALIZED VIEW analytics.tables_mv TO analytics.tables AS
select
    t.total_rows,
    t.uuid as table_uuid,
    a.database,
    a.table,
    a.source_table,
    a.source_database,
    a.create_ddl,
    a.populate_query,
    a.event_time,
    a.query as create_ddl_raw,
    t.create_table_query
from
    (
        select
            event_time,
            tables [1] as table_raw,
            tables [length(tables)] as source_table_raw,
            splitByChar('.', source_table_raw) [2] as source_table,
            splitByChar('.', table_raw) [2] as table,
            query,
            splitByRegexp('select', query, 2) as ddl,
            ddl [1] as create_ddl,
            concat('select', ddl [2]) as populate_query,
            tables,
            databases,
            splitByChar('.', source_table_raw) [1] as source_database,
            splitByChar('.', table_raw) [1] as database
        from
            system.query_log
        where
            type = 'QueryFinish'
            and query_kind = 'Create'
            and length(tables) > 1
    ) as a
    inner join system.tables t on t.name = a.table
    and t.database = a.database;
