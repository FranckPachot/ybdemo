docker-compose down
# scale-up
for i in $(seq 1 ${1:-3})
do
 sleep 5
 echo "starting node $i"
 docker-compose up -d --scale yb=$i
done
# scale-down mist black list first
