# run this and make sure it only returns the bellow
sudo fuser -vm /opt/data || true

# you want to see this: 
root@DCDLVLGNCH02:~# sudo fuser -vm /opt/data || true
                     USER        PID ACCESS COMMAND
/opt/data:           root     kernel mount /opt/data

# STOP if you see somethign liek this:
root@DCDLVLGNCH02:~# sudo fuser -vm /opt/data || true
                     USER        PID ACCESS COMMAND
/opt/data:           root     kernel mount /opt/data
                     shiles    852148 ..c.. bash
                     root      872618 ..c.. sudo
                     root      872620 ..c.. sudo


sudo umount /opt/data

sudo mount -t xfs -o rw,relatime,attr2,nodiscard,inode64,logbufs=8,logbsize=32k,noquota \
  /dev/mapper/vgdata-lvdata /opt/data

  
findmnt -no OPTIONS /opt/data



sudo mount -t xfs -o rw,relatime,attr2,discard,inode64,logbufs=8,logbsize=32k,noquota \
  /dev/mapper/vgdata-lvdata /opt/data

findmnt -no OPTIONS /opt/data