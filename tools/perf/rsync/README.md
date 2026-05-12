# Rsync perf profiling benchmark suite.

Best comparable run:

```bash
./rsync-cifs-perf.sh \
  --files 1000 \
  --src /mnt/deepseainput/processed/20260430 \
  --dest /opt/data/test-rsync \
  --select median \
  --label median-1000
```

Then reuse the generated file list for ext4/XFS comparisons:
```bash
  ./rsync-cifs-perf.sh \
  --files 1000 \
  --src /mnt/deepseainput/processed/20260430 \
  --dest /opt/data/test-rsync \
  --file-list /tmp/rsync-cifs-perf-YYYYMMDDTHHMMSSZ/files.txt \
  --label fixed-list-1000
```