This is a lab with a YugabyteDB database and Grafana to run various workloads and display some statistics

- Set parameters in `.env` (`YB_FLAGS` are the flags added to start `yb-master` and `yb-tserver`)
- start containers:
```
docker compose up -d
```
- view Grafana dashboard http://localhost:3000/

## Demo of Size Amplification algorithm

We set no threshold to start on a number of SST files already there `rocksdb_level0_file_num_compaction_trigger=2` and high number for the read amplification algorithm `rocksdb_universal_compaction_min_merge_width=100`. Note that this will stop at `sst_files_hard_limit=48`

```
docker compose --env-file demo-space-amplification-algo.env up -d 
```

More details in https://dev.to/yugabyte/testing-lsm-tree-merge-for-size-amplification-in-yugabytedb-2kh9

## Demo of Read Amplification algorithm

We set the same as before, but with `rocksdb_universal_compaction_min_merge_width=4` and `rocksdb_universal_compaction_size_ratio=20` so that when there are 4 new SST Files they will be merge with older ones until it is more than 20 larger.

```
docker compose --env-file demo-read-amplification-algo.env up -d 
```

