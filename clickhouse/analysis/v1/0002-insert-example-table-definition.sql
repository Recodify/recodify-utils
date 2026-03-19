INSERT INTO system.table_definitions(database, table, category, description, create_ddl, populate_query)
values(
'sunbath', 
'lagoon_query_classification', 
'API', 
'Classified logs of all api requests made to lagoon and the queries they produced',  
$create$
CREATE TABLE IF NOT EXISTS sunbath.lagoon_query_classification
(
    request_time DateTime64(3, 'UTC'),
    response_time DateTime64(3, 'UTC'),
    request_response_duration_ms Float64,

    operation_name LowCardinality(String),
    endpoint LowCardinality(String),
    http_method LowCardinality(String),

    query_family LowCardinality(String),
    query_kind LowCardinality(String),
    intent LowCardinality(String),
    sql_operation LowCardinality(String),
    time_semantics LowCardinality(String),
    query_shape_id String,

    timeseries_name_count UInt32,
    timeseries_name_sample Array(String),
    identity_predicates Array(String),
    identity_predicates_value Array(String),

    filter_columns Array(String),
    filter_ops Array(String),
    filter_values Array(String),
    filter_dimension_source Array(String),
    filter_effective Array(UInt8),

    period_start_op LowCardinality(String),
    period_start_value String,
    period_end_op LowCardinality(String),
    period_end_value String,
    timestamp_op LowCardinality(String),
    timestamp_value String,
    baseline_datetime_op LowCardinality(String),
    baseline_datetime_value String,
    published_datetime_op LowCardinality(String),
    published_datetime_value String,
    asof_datetime_op LowCardinality(String),
    asof_datetime_value String,
    model_asof_datetime_op LowCardinality(String),
    model_asof_datetime_value String,
    loadbatch_timestamp_op LowCardinality(String),
    loadbatch_timestamp_value String,
    loadbatch_id_op LowCardinality(String),
    loadbatch_id_value String,

    raw_query String,
    source_file String,
    result_code String
)
ENGINE = MergeTree
ORDER BY (request_time, query_family, query_kind)
$create$,
$populate$
clickhouse-client   --host DCDLVLGNCH01   --user user   --password password   --port 9006   --query "
    INSERT INTO sunbath.lagoon_query_classification
    SETTINGS date_time_input_format='best_effort'
    FORMAT JSONEachRow
  "   < ./classify/20260317.jsonl
$populate$)
