#!/usr/bin/env bash

# Source-safe ClickHouse file inspection helpers.
# Configure the binary with CLICKHOUSE_LOCAL_BIN=/path/to/clickhouse-local.

chhelp() {
  cat <<'EOF'
Usage: chhelp

ClickHouse file helpers:
  chcnt <file>                         Count rows
  chdesc <file>                        Show inferred schema
  chschema <file>                      Alias for chdesc
  chcols <file>                        Print inferred column names
  chpeek <file> [limit]                Show first rows
  chsample <file> [limit] [every]      Probabilistic sample, roughly 1/every rows
  chmin <file> <column>                Minimum value for a column
  chmax <file> <column>                Maximum value for a column
  chminmax <file> <column>             Minimum and maximum for a column
  chdistinct <file> <column> [limit]   Top values by frequency
  chnulls <file> [column]              Null counts for one column or all columns
  chsize <file>                        File size plus row count
  chfiletype <file>                    OS file info plus ClickHouse schema

All helpers use clickhouse-local. Set CLICKHOUSE_LOCAL_BIN to override it.
Use -h or --help on any helper for examples.
EOF
}

__ch_is_help() {
  [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]
}

__ch_die() {
  printf 'Error: %s\n' "$*" >&2
  return 1
}

__ch_bin() {
  printf '%s\n' "${CLICKHOUSE_LOCAL_BIN:-clickhouse-local}"
}

__ch_require_bin() {
  local bin
  bin="$(__ch_bin)"

  if ! command -v -- "$bin" >/dev/null 2>&1; then
    __ch_die "clickhouse-local not found; install it or set CLICKHOUSE_LOCAL_BIN"
    return 1
  fi
}

__ch_require_file() {
  local file="${1:-}"

  if [[ -z "$file" ]]; then
    __ch_die "file argument is required"
    return 1
  fi

  if [[ ! -e "$file" ]]; then
    __ch_die "file not found: $file"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    __ch_die "not a regular file: $file"
    return 1
  fi
}

__ch_require_limit() {
  local value="${1:-}"
  local name="${2:-limit}"

  if [[ -z "$value" || ! "$value" =~ ^[0-9]+$ ]]; then
    __ch_die "$name must be a non-negative integer"
    return 1
  fi
}

__ch_require_positive_integer() {
  local value="${1:-}"
  local name="${2:-value}"

  if [[ -z "$value" || ! "$value" =~ ^[1-9][0-9]*$ ]]; then
    __ch_die "$name must be a positive integer"
    return 1
  fi
}

__ch_sql_string() {
  local value="$1"
  local quote="'"
  local escaped_quote="\\'"

  value=${value//\\/\\\\}
  value=${value//${quote}/${escaped_quote}}
  printf "'%s'" "$value"
}

__ch_sql_identifier() {
  local value="$1"
  local tick='`'
  local escaped_tick='\`'

  value=${value//\\/\\\\}
  value=${value//${tick}/${escaped_tick}}
  printf '`%s`' "$value"
}

__ch_file_expr() {
  printf 'file(%s)' "$(__ch_sql_string "$1")"
}

__ch_run_query() {
  local query="$1"
  local bin

  __ch_require_bin || return 1
  bin="$(__ch_bin)"

  "$bin" --query "$query"
}

__ch_columns() {
  local file="$1"
  local rows

  rows="$(__ch_run_query "DESCRIBE $(__ch_file_expr "$file") FORMAT TabSeparated")" || return 1
  awk -F '\t' 'NF { print $1 }' <<< "$rows"
}

__ch_require_column() {
  local file="$1"
  local column="${2:-}"
  local columns

  if [[ -z "$column" ]]; then
    __ch_die "column argument is required"
    return 1
  fi

  columns="$(__ch_columns "$file")" || return 1

  if ! grep -Fxq -- "$column" <<< "$columns"; then
    printf 'Error: column not found: %s\n' "$column" >&2
    printf 'Known columns:\n' >&2
    sed 's/^/  /' <<< "$columns" >&2
    return 1
  fi
}

__ch_human_size() {
  local bytes="$1"

  if command -v numfmt >/dev/null 2>&1; then
    numfmt --to=iec --suffix=B "$bytes"
  else
    printf '%s bytes\n' "$bytes"
  fi
}

__ch_usage_cnt() {
  cat <<'EOF'
Usage: chcnt <file>

Count rows in a file using ClickHouse file inference.

Example:
  chcnt data.parquet
EOF
}

chcnt() {
  if __ch_is_help "${1:-}"; then __ch_usage_cnt; return 0; fi
  local file="${1:-}"

  __ch_require_file "$file" || return 1
  __ch_run_query "SELECT count() AS rows FROM $(__ch_file_expr "$file")"
}

__ch_usage_desc() {
  cat <<'EOF'
Usage: chdesc <file>

Show the schema ClickHouse infers for a file.

Example:
  chdesc data.parquet
EOF
}

chdesc() {
  if __ch_is_help "${1:-}"; then __ch_usage_desc; return 0; fi
  local file="${1:-}"

  __ch_require_file "$file" || return 1
  __ch_run_query "DESCRIBE $(__ch_file_expr "$file") FORMAT PrettyCompact"
}

chschema() {
  chdesc "$@"
}

__ch_usage_cols() {
  cat <<'EOF'
Usage: chcols <file>

Print one inferred column name per line.

Example:
  chcols data.parquet
EOF
}

chcols() {
  if __ch_is_help "${1:-}"; then __ch_usage_cols; return 0; fi
  local file="${1:-}"

  __ch_require_file "$file" || return 1
  __ch_columns "$file"
}

__ch_usage_peek() {
  cat <<'EOF'
Usage: chpeek <file> [limit]

Show the first rows from a file. The default limit is 5.

Examples:
  chpeek data.parquet
  chpeek data.parquet 20
EOF
}

chpeek() {
  if __ch_is_help "${1:-}"; then __ch_usage_peek; return 0; fi
  local file="${1:-}"
  local limit="${2:-5}"

  __ch_require_file "$file" || return 1
  __ch_require_limit "$limit" "limit" || return 1

  __ch_run_query "SELECT * FROM $(__ch_file_expr "$file") LIMIT $limit FORMAT PrettyCompact"
}

__ch_usage_sample() {
  cat <<'EOF'
Usage: chsample <file> [limit] [every]

Show a probabilistic sample without a global random sort.
The default limit is 10. The default every value is 100, meaning roughly
1 in 100 rows is eligible before the limit is applied.

Examples:
  chsample data.parquet
  chsample data.parquet 20
  chsample data.parquet 20 10
EOF
}

chsample() {
  if __ch_is_help "${1:-}"; then __ch_usage_sample; return 0; fi
  local file="${1:-}"
  local limit="${2:-10}"
  local every="${3:-100}"

  __ch_require_file "$file" || return 1
  __ch_require_limit "$limit" "limit" || return 1
  __ch_require_positive_integer "$every" "every" || return 1

  __ch_run_query "SELECT * FROM $(__ch_file_expr "$file") WHERE rand64() % $every = 0 LIMIT $limit FORMAT PrettyCompact"
}

__ch_usage_minmax() {
  local name="$1"
  cat <<EOF
Usage: $name <file> <column>

Calculate $name for a validated column.

Example:
  $name data.parquet timestamp
EOF
}

chmin() {
  if __ch_is_help "${1:-}"; then __ch_usage_minmax chmin; return 0; fi
  local file="${1:-}"
  local column="${2:-}"
  local ident

  __ch_require_file "$file" || return 1
  __ch_require_column "$file" "$column" || return 1
  ident="$(__ch_sql_identifier "$column")"

  __ch_run_query "SELECT min($ident) AS min_value FROM $(__ch_file_expr "$file") FORMAT PrettyCompact"
}

chmax() {
  if __ch_is_help "${1:-}"; then __ch_usage_minmax chmax; return 0; fi
  local file="${1:-}"
  local column="${2:-}"
  local ident

  __ch_require_file "$file" || return 1
  __ch_require_column "$file" "$column" || return 1
  ident="$(__ch_sql_identifier "$column")"

  __ch_run_query "SELECT max($ident) AS max_value FROM $(__ch_file_expr "$file") FORMAT PrettyCompact"
}

chminmax() {
  if __ch_is_help "${1:-}"; then __ch_usage_minmax chminmax; return 0; fi
  local file="${1:-}"
  local column="${2:-}"
  local ident

  __ch_require_file "$file" || return 1
  __ch_require_column "$file" "$column" || return 1
  ident="$(__ch_sql_identifier "$column")"

  __ch_run_query "SELECT min($ident) AS min_value, max($ident) AS max_value FROM $(__ch_file_expr "$file") FORMAT PrettyCompact"
}

__ch_usage_distinct() {
  cat <<'EOF'
Usage: chdistinct <file> <column> [limit]

Show the most frequent values for a column. The default limit is 20.

Examples:
  chdistinct data.parquet status
  chdistinct data.parquet status 50
EOF
}

chdistinct() {
  if __ch_is_help "${1:-}"; then __ch_usage_distinct; return 0; fi
  local file="${1:-}"
  local column="${2:-}"
  local limit="${3:-20}"
  local ident

  __ch_require_file "$file" || return 1
  __ch_require_column "$file" "$column" || return 1
  __ch_require_limit "$limit" "limit" || return 1
  ident="$(__ch_sql_identifier "$column")"

  __ch_run_query "SELECT $ident AS value, count() AS rows FROM $(__ch_file_expr "$file") GROUP BY $ident ORDER BY rows DESC LIMIT $limit FORMAT PrettyCompact"
}

__ch_usage_nulls() {
  cat <<'EOF'
Usage: chnulls <file> [column]

Show null counts. With a column argument, output rows/nulls/non_nulls/null_pct
for that column. Without a column, output one row with rows plus null_<column>
counts for every inferred column, using a single file scan.

Examples:
  chnulls data.parquet
  chnulls data.parquet status
EOF
}

chnulls() {
  if __ch_is_help "${1:-}"; then __ch_usage_nulls; return 0; fi
  local file="${1:-}"
  local column="${2:-}"
  local ident
  local columns
  local select_sql
  local part

  __ch_require_file "$file" || return 1

  if [[ -n "$column" ]]; then
    __ch_require_column "$file" "$column" || return 1
    ident="$(__ch_sql_identifier "$column")"
    __ch_run_query "SELECT count() AS rows, countIf(isNull($ident)) AS nulls, rows - nulls AS non_nulls, if(rows = 0, 0, round(nulls * 100 / rows, 4)) AS null_pct FROM $(__ch_file_expr "$file") FORMAT PrettyCompact"
    return
  fi

  columns="$(__ch_columns "$file")" || return 1
  select_sql="count() AS rows"

  while IFS= read -r column; do
    [[ -n "$column" ]] || continue
    ident="$(__ch_sql_identifier "$column")"
    part="countIf(isNull($ident)) AS $(__ch_sql_identifier "null_${column}")"
    select_sql="${select_sql}, ${part}"
  done <<< "$columns"

  __ch_run_query "SELECT $select_sql FROM $(__ch_file_expr "$file") FORMAT PrettyCompact"
}

__ch_usage_size() {
  cat <<'EOF'
Usage: chsize <file>

Show file size and row count.

Example:
  chsize data.parquet
EOF
}

chsize() {
  if __ch_is_help "${1:-}"; then __ch_usage_size; return 0; fi
  local file="${1:-}"
  local bytes
  local size
  local rows

  __ch_require_file "$file" || return 1

  bytes="$(stat -c '%s' -- "$file")" || return 1
  size="$(__ch_human_size "$bytes")" || return 1
  rows="$(__ch_run_query "SELECT count() AS rows FROM $(__ch_file_expr "$file")")" || return 1

  printf 'file\t%s\n' "$file"
  printf 'bytes\t%s\n' "$bytes"
  printf 'size\t%s\n' "$size"
  printf 'rows\t%s\n' "$rows"
}

__ch_usage_filetype() {
  cat <<'EOF'
Usage: chfiletype <file>

Show basic OS file metadata and ClickHouse's inferred schema.

Example:
  chfiletype data.parquet
EOF
}

chfiletype() {
  if __ch_is_help "${1:-}"; then __ch_usage_filetype; return 0; fi
  local file="${1:-}"
  local bytes
  local size

  __ch_require_file "$file" || return 1

  bytes="$(stat -c '%s' -- "$file")" || return 1
  size="$(__ch_human_size "$bytes")" || return 1

  printf 'file\t%s\n' "$file"
  printf 'bytes\t%s\n' "$bytes"
  printf 'size\t%s\n' "$size"
  printf 'modified\t%s\n' "$(stat -c '%y' -- "$file")"

  if command -v file >/dev/null 2>&1; then
    printf 'type\t%s\n' "$(file -b -- "$file")"
  fi

  printf '\nClickHouse schema:\n'
  chdesc "$file"
}
