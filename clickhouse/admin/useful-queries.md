# Useful Queries


## Disk Space

```sql
SELECT table,
    formatReadableSize(sum(bytes)) as size,
    min(min_date) as min_date,
    max(max_date) as max_date,
    sum(rows) as rows
FROM system.parts
WHERE active
and table like '%reading%'
GROUP BY table
ORDER BY rows DESC
```

```sql
select database, table, parts.*,
    columns.compressed_size,
    columns.uncompressed_size,
    columns.compression_percentage
from (
    select table,database,
        formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
        formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
        round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes), 3) AS compression_ratio,
        round((100 - (sum(data_compressed_bytes) * 100) / sum(data_uncompressed_bytes)), 3) AS compression_percentage

    from system.columns
    where table like '%reading%'
    and database <> 'lightspeed'
    group by table, database

) columns
right join (
    select table,
        sum(rows) as rows,
        -- max(modification_time) as latest_modification,
        formatReadableSize(sum(bytes)) as disk_size,
        formatReadableSize(sum(primary_key_bytes_in_memory)) as primary_keys_size,
        any(engine) as engine,
        sum(bytes) as bytes_size
    from system.parts
    where active
    and table like '%reading%'
    and database <> 'lightspeed'
    group by database, table
) parts on columns.table = parts.table
order by parts.bytes_size desc;
```

## Query log

You can get a list of the most recent queries by running the following against CH:

```sql
select current_database,read_rows, read_bytes, result_rows, query_duration_ms, event_time, query, *
from system.query_log
where type = 'QueryFinish'
and query not like '%query_log%'
order by event_time desc limit 100;
```

### Slow queries:

```sql
select current_database,read_rows, read_bytes, result_rows, user, query_duration_ms, query_duration_ms / 1000 as query_duration_secs, event_time, query, *
from system.query_log
where type = 'QueryFinish'
and query not like '%query_log%'
order by query_duration_ms desc
limit 100;
```

## Processes

```sql
SELECT * FROM system.processes LIMIT 10 FORMAT Vertical;
```

## Table sizes on disk:

```sql
SELECT table,
    formatReadableSize(sum(bytes)) as size,
    min(min_date) as min_date,
    max(max_date) as max_date,
    sum(rows) as rows
FROM system.parts
WHERE active
GROUP BY table
ORDER BY rows DESC
```

## Table compression ratios:

```sql
select database, table, parts.*,
    columns.compressed_size,
    columns.uncompressed_size,
    columns.compression_percentage
from (
    select table,database,
        formatReadableSize(sum(data_uncompressed_bytes)) AS uncompressed_size,
        formatReadableSize(sum(data_compressed_bytes)) AS compressed_size,
        round(sum(data_compressed_bytes) / sum(data_uncompressed_bytes), 3) AS compression_ratio,
        round((100 - (sum(data_compressed_bytes) * 100) / sum(data_uncompressed_bytes)), 3) AS compression_percentage

    from system.columns
    group by table, database
) columns
right join (
    select table,
        sum(rows) as rows,
        -- max(modification_time) as latest_modification,
        formatReadableSize(sum(bytes)) as disk_size,
        formatReadableSize(sum(primary_key_bytes_in_memory)) as primary_keys_size,
        any(engine) as engine,
        sum(bytes) as bytes_size
    from system.parts
    where active
    group by database, table
) parts on columns.table = parts.table
order by parts.bytes_size desc;
```

# Tools

## Server Dashboard

You can access a basic server dashboard here: [http://localhost:8123/dashboard](http://localhost:8123/dashboard)

Additional 'panels/graphs' can be added to this dashboard using SQL queries. For example, the following query would add a top-10 slowest queries panel:

```sql
SELECT query_duration_ms, query, event_time, databases, tables
FROM system.query_log
WHERE type = 'QueryFinish' and query_kind='Select' ORDER BY query_duration_ms DESC LIMIT 10
```