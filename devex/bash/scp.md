# SCP

## Copy local → remote

### Copy file:

```bash
scp file.txt user@host:/remote/path/
```


### Copy directory:

```bash
scp -r mydir user@host:/remote/path/
```

### Copy and rename:

```bash
scp file.txt user@host:/remote/path/newname.txt
```

## Copy remote → local

### Copy file:

```bash
scp user@host:/remote/path/file.txt .
```

### Copy directory:

```bash
scp -r user@host:/remote/path/mydir .
```

### Copy remote → remote (via your machine)

```bash
scp user1@host1:/path/file user2@host2:/path/
```