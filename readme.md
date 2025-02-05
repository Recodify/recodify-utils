# System Utils

A collection of command-line utilities designed to help system administrators and developers with common tasks, diagnostics, and performance measurements.

## Available Tools

### tx-benchmark

A file transfer benchmarking tool that measures read and write performance across different file sizes and scenarios.

#### Features

- Single large file performance testing
- Multiple small files performance testing
- Configurable file sizes
- Detailed timing metrics (real, user, sys)
- Verbose mode for detailed timings
- Clean, tabulated output format

#### Usage

```bash
sudo ./tx-benchmark.sh -d <mount_directory> [options]

Options:
  -d, --directory <dir>    Mount directory to test
  -f, --file-sizes <sizes> Comma-separated list of sizes (e.g., '100M,500M,1G')
  -s, --single            Run single file tests (default: false)
  -m, --multiple          Run multiple small files tests (default: false)
  -v, --verbose           Verbose output with detailed timing (default: false)
  -q, --quiet             Quiet output, show results only (default: false)
```

NOTE: You need to run the script with sudo privileges.

#### Example Commands

```bash
# Run both single and multiple file tests with default sizes
./tx-benchmark.sh -d /mnt/test -s -m

# Test specific file sizes with verbose output
./tx-benchmark.sh -d /mnt/test -f "10M,50M,200M" -s -v

# Test only multiple small files
./tx-benchmark.sh -d /mnt/test -m
```

#### Example Output



``` bash
sudo ./tools/tx-benchmark.sh -d /mnt/test  -s -m
```

| TestId | Type  | Size | Files | Speed     | Time  |
|--------|-------|------|-------|-----------|-------|
| 0      | Read  | 10M  | 10    | 11.19 MB/s| 0.89s |
| 1      | Write | 10M  | 10    | 19.68 MB/s| 0.51s |
| 2      | Read  | 50M  | 50    | 6.99 MB/s | 7.14s |
| 3      | Write | 50M  | 50    | 26.96 MB/s| 1.85s |
| 4      | Read  | 100M | 100   | 17.63 MB/s| 5.67s |
| 5      | Write | 100M | 100   | 19.47 MB/s| 5.14s |
| 6      | Read  | 10M  | 1     | 34.24 MB/s| 0.29s |
| 7      | Write | 10M  | 1     | 19.45 MB/s| 0.51s |
| 8      | Read  | 50M  | 1     | 59.88 MB/s| 0.83s |
| 9      | Write | 50M  | 1     | 52.74 MB/s| 0.95s |
| 10     | Read  | 100M | 1     | 49.43 MB/s| 2.02s |
| 11     | Write | 100M | 1     | 55.61 MB/s| 1.80s |


``` bash
sudo ./tools/tx-benchmark.sh -d /mnt/test  -s -m -v
```


| TestId | Type  | Size | Files | Speed        | Real  | Sys   | User  |
|--------|-------|------|-------|--------------|-------|-------|-------|
| 0      | Read  | 10M  | 10    | 1000.00 MB/s| 0.01s | 0.00s | 0.01s |
| 1      | Write | 10M  | 10    | 1111.11 MB/s| 0.01s | 0.00s | 0.01s |
| 2      | Read  | 50M  | 50    | 1162.79 MB/s| 0.04s | 0.00s | 0.04s |
| 3      | Write | 50M  | 50    | 1219.51 MB/s| 0.04s | 0.00s | 0.04s |
| 4      | Read  | 100M | 100   | 1123.59 MB/s| 0.09s | 0.00s | 0.08s |
| 5      | Write | 100M | 100   | 1250.00 MB/s| 0.08s | 0.00s | 0.08s |
| 6      | Read  | 10M  | 1     | 1000.00 MB/s| 0.01s | 0.00s | 0.01s |
| 7      | Write | 10M  | 1     | 1111.11 MB/s| 0.01s | 0.00s | 0.01s |
| 8      | Read  | 50M  | 1     | 1250.00 MB/s| 0.04s | 0.00s | 0.04s |
| 9      | Write | 50M  | 1     | 1282.05 MB/s| 0.04s | 0.00s | 0.04s |
| 10     | Read  | 100M | 1     | 1265.82 MB/s| 0.08s | 0.00s | 0.08s |
| 11     | Write | 100M | 1     | 1333.33 MB/s| 0.08s | 0.00s | 0.08s |


#### Understanding the Output

The tool provides a tabulated summary of all tests, including:
- Test ID: Unique identifier for each test
- Type: Read or Write operation
- Size: Total data size processed
- Files: Number of files in the test
- Speed: Transfer speed in MB/s
- Time: Operation duration (and detailed timing in verbose mode)
-
#### Understanding Time Measurements

When analyzing the results when verbose is enabled, you'll see three time measurements for each operation:

- **real** - The actual wall-clock time the operation took. This is what you experience waiting for the operation to complete. For file transfers, this is the most relevant number.

- **user** - CPU time spent in user-space code. For file operations, this is usually small because most work happens in the kernel or waiting for the disk/network.

- **sys** - CPU time spent in kernel-space code. For file operations, this includes time spent managing file systems and network protocols, but not time spent waiting for the actual I/O.

When interpreting network file transfers:
- High 'real' time but low 'user'+'sys' time usually indicates a network/disk bottleneck
- High 'sys' time might indicate protocol overhead or CPU-intensive compression
- Small files typically show higher 'sys' time due to more file operations

## Installation

```bash
git clone https://github.com/username/system-utils.git
cd system-utils
chmod +x *.sh
```

## Roadmap

- More tools will be added in the future.

