mkdir -p /var/tmp/snap
type jq || yum install -y jq
type curl || yum install -y curl
(
cd /var/tmp/snap || exit
tservers=$(
curl -qs http://yb-master-0:7000/tablet-servers?raw | awk '
/http.*ALIVE/{sub(".*http:[/][/]","");sub(":.*","");print $0}' | paste -s
)
timestamp=$(date +%Y%m%d%H%M%s)
echo $timestamp $tservers

rm tmp.*.txt
true && for i in $tservers ; do
echo "=== $i"
true && (
 curl -qs http://${i}:9000/metrics |
 jq --arg epoch $(date +%s) --arg tserver $i -r '
 .[]
 |(.attributes.namespace_name+"."+.attributes.table_name+"/"+.id) as $tablet
 |select(.type=="tablet" and .attributes.namespace_name!="system")
 |.metrics[]
 |select(.value>0 and .name=="rocksdb_number_db_seek")
 |$tserver+":"+$tablet+":"+.name+"\t"+(.value|tostring)
' | sort -nk2 > tmp.$i.txt
[ -s tmp.$i.txt ] && {
rm -f $(find . -name ".$i." -type f -empty) 2>/dev/null
sort tmp.$i.txt > snap.$i.$timestamp.txt
#echo "=== snap from $i and report between  $(ls -rt snap.$i.*.txt | tail -2 | paste -s)"
join -a 1 $(ls -rt snap.$i.*.txt | tail -2) |
awk '$3>$2{printf "%22d %-s\n",$3-$2,$1;rc=rc+1;rc=1}
     END{if(rc>0) print ""}' | sort -n > "report.$i.$timestamp.txt"
}
)
done
wait
{
echo "=== $(date) $reports"
for i in $tservers ; do ls -rt report.$i.$timestamp.txt | tail -1 ; done | nl
sort -n $(for i in $tservers ; do ls -rt report.$i.$timestamp.txt | tail -1 ; done) | tail -20
} | tee all.$timestamp.log
)
