This runs pgbench on each YugabyteDB to test the scalability

Start the nodes one after the others with 
```
 docker-compose up -d --scale yb=1
 docker-compose up -d --scale yb=2
 docker-compose up -d --scale yb=3
 docker-compose up -d --scale yb=4
...
```
