
# for i in {0..3} ; do docker exec -it yb-tserver-$i bash /home/yugabyte/client/metrics_snap.sh & done

type jq || yum install -y jq
{
while sleep ${1:-5}
do
curl -s ${2:-$(hostname)}:9000/tablets?raw
curl -s ${2:-$(hostname)}:9000/metrics | jq -r '
.[] |
(.id) as $tablet_id|
(.attributes.namespace_name+" "+.attributes.table_name) as $table_name|
select(.type=="tablet" )|
.metrics[]|
select(.value>0)|
$tablet_id+"\t"+(.value|tostring)+"\t"+.name+"\t"+$table_name
'
echo "---"
done
} | awk -F"\t" '
/^---/{
 if (new == 1) print "" ; new=0
}
{
gsub("&lt;start&gt;","-inf")
gsub("&lt;end&gt;","+inf")
}
/^[a-f0-9]{32}\t[0-9]+\t(rows_inserted|rocksdb_number_db_seek|rocksdb_number_db_next)\t/ && $4 != "system metrics" {
 tabletmetric=sprintf("%25s in %-45s %-25s %-s",$3, $4, range[$1],host,$1)
 delta[tabletmetric]=$2-metrics[tabletmetric]
 if ( delta[tabletmetric] > 0 ) {
  printf "%10d %-s\n", delta[tabletmetric],tabletmetric
  new=1
 }
 metrics[tabletmetric]=$2
}
$0 ~ tserver_tablets {
range[gensub(tserver_tablets,"\\3",1)]=gensub(tserver_tablets,"\\4",1)
}
' host=$(hostname) tserver_tablets='^<tr><td>([^<]*)<[/]td><td>([^<]*)<[/]td><td>0000[0-9a-f]{4}00003000800000000000[0-9a-f]{4}<[/]td><td><a href="[/]tablet[?]id=([0-9a-f]{32})">[0-9a-f]{32}</a></td><td>([^<]*)<[/]td><td>([^<]*)<[/]td><td>false<[/]td><td>([0-9])<[/]td><td><ul><li>Total: [^<]*<li>Consensus Metadata: [^<]*<li>WAL Files: ([^<]*)<li>SST Files: ([^<]*)<li>SST Files Uncompressed: ([^<]*)<[/]ul><[/]td><td><ul>'



exit


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
