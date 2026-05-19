sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null && sync && time cp -a --reflink=always /opt/data/library/. /opt/data/library_reflink_test/


time cp -a --reflink=always /opt/data/library/. /opt/data/library_reflink_test/
