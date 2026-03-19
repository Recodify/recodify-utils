
create table system.table_definitions
(
   database String,
   table LowCardinality(String),
   category LowCardinality(String),
   description String,
   create_ddl String,
   populate_query String,
   example_query_1 String,
   example_query_2 String,
   example_query_3 String,
   example_query_4 String,
   example_query_5 String,
   doc String,
   created_at DateTime64(3) DEFAULT Now64(),
    updated_at DateTime64(3) DEFAULT Now64()
)
ENGINE=ReplacingMergeTree(created_at)
ORDER BY (database, category, table)
COMMENT  'A custom system table used to organise and document analytical queries.'
