

create table system.table_definitions
(
   database String,
   table LowCardinality(String),
   category LowCardinality(String),
   description String,
   create_ddl String,
   populate_queries Array(Tuple(name String, description String, query String)),
   verify_queries Array(Tuple(name String, description String, query String)),
   analytics_queries Array(Tuple(name String, description String, note String, query String)),
   findings Array(Tuple(name String, description String, query String, data JSON, timestamp DateTime32)),
   docLinks Array(Tuple(name String, url String)),
   created_at DateTime64(3) DEFAULT Now64(),
   updated_at DateTime64(3) DEFAULT Now64()
)
ENGINE=ReplacingMergeTree(created_at)
ORDER BY (database, category, table)
COMMENT  'A custom system table used to organise and document analytical queries.'
