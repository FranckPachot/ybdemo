
# while sleep 1 ; do [ deploy.sh -nt .tmp.js ] && sh deploy.sh ; done
 
aws lambda delete-function --function-name ybdemo-lambda

export AWS_PAGER="" 

cat > lambda-trust-policy.json <<'CAT'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
    "Action": "sts:AssumeRole"
    }
  ]
}
CAT


cat > ybdemo-lambda.js <<'CAT'

// a random number to identify the lambdi state reuse
const lambdaId=Math.floor(1000*Math.random())

// imports the PostgreSQL connector and create the pool (connection info from libpq environment variabels)
const { Pool, Client } = require('pg')
const xdb = new Pool({
 max: 1,
 idleTimeoutMillis:      300000,
 connectionTimeoutMillis: 15000,
})

const db=new Client()
    db.connect();

exports.handler = async(event) => {
 //var {callid}=event
  var resultString="."
    //const body = JSON.parse(event.body);
    //const query = {
        //text: "insert into test (text) values($1)",
        //values: [body.text],
    //};
    //const result = await db.query("select inet_server_addr(),pg_backend_pid()");
    //const result = await db.query("select format(' call#=%5s lambda= %3s backend= %6s host= %15s sessions= %3s time= %s ',$1::text,$2::text,pg_backend_pid(),inet_server_addr(),count(*),extract(epoch from now())) from pg_stat_activity where application_name='lambda'",[event["call#"],lambdaId]);
    const result = await db.query("with i as (insert into ybdemo_stat_activity select $1 callseq, $2 lambda, now(), inet_server_addr(),pg_backend_pid(),* from pg_stat_activity returning *) select $1 x,pid, now()-backend_start session_lifetime from i where pg_backend_pid=pid",[event["call#"],lambdaId]);
    resultString = JSON.stringify(result.rows);    

    //db.releaseCallback();

    const response = {
        "statusCode":200,
        "body":{resultString}
    };

    return response;

};

CAT


echo "$*" | grep role && {
aws iam create-role --role-name ybdemo-lambda-role --assume-role-policy-document file://lambda-trust-policy.json
sleep 1
}

npm install pg
node ybdemo-lambda.js && {
rm ybdemo-lambda-role.zip ; zip -r ybdemo-lambda-role.zip ybdemo-lambda.js node_modules ; aws lambda create-function \
    --function-name ybdemo-lambda \
    --runtime nodejs14.x \
    --zip-file fileb://ybdemo-lambda-role.zip \
    --handler ybdemo-lambda.handler \
    --environment 'Variables={PGAPPNAME=lambda,PGUSER=yugabyte,PGDBNAME=yugabyte,PGHOST=a0b821173a97b49ef90c6dd7d9b26551-79341159.eu-west-1.elb.amazonaws.com,PGPORT=5433}' \
    --role $( aws iam get-role --role-name ybdemo-lambda-role --output json | jq -r '."Role"."Arn"' )
#sleep 3
aws lambda wait function-updated --function-name ybdemo-lambda


psql -h a0b821173a97b49ef90c6dd7d9b26551-79341159.eu-west-1.elb.amazonaws.com -p 5433 -d yugabyte -U yugabyte -c "truncate ybdemo_stat_activity"

aws lambda put-function-concurrency \
    --function-name  ybdemo-lambda  \
    --reserved-concurrent-executions 10

sleep 5

seq=0
for s in {1..1000} ; do
for i in {1..10} ; do
seq=$(($seq + 1))
(
aws lambda invoke --function-name ybdemo-lambda --cli-binary-format raw-in-base64-out --payload '{"call#":"'$seq'"}' .tmp.js && jq . < .tmp.js
#awk '/resultString/{print $4,$6,$8,$10,$12,$14,$14-l;l=$14}' log.txt
) &
#sleep 1
done
wait
sleep $s
done | tee log.txt | ts


}

echo "$*" | grep role && {
aws iam delete-role --role-name ybdemo-lambda-role
}
