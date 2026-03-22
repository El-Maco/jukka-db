# Grafana

```bash
sshfs maco@minimaco:/jukka ~/.sshfs/jukka \
    -o allow_other \
    -o uid=472 \
    -o gid=472
```



> Make sure to add the following line to `/etc/fuse.conf`:
> ```bash
> user_allow_other
> ```

In the docker install the sqlite plugin
```bash
grafana-cli plugins install frser-sqlite-datasource
```
