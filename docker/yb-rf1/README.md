

```
docker-compose up --scale yb-tserver-n=0 -d
psql postgresql://localhost:5433
 create table demo(id int primary key) split into 2 tablets;
 insert into demo select generate_series(1,1000);
```

