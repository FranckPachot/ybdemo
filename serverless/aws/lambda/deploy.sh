
# while sleep 1 ; do [ deploy.sh -nt .tmp.js ] && sh deploy.sh ; done
 

export AWS_PAGER="" 

cat > trust-policy.json <<'CAT'
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

exports.handler = async(event) => {
    const {Client} = require('pg');
    //const body = JSON.parse(event.body);
    //const query = {
        //text: "insert into test (text) values($1)",
        //values: [body.text],
    //};
    const client = new Client({
        user: 'yugabyte',
        host: 'a0b821173a97b49ef90c6dd7d9b26551-79341159.eu-west-1.elb.amazonaws.com',
        database: 'yugabyte',
        password: '',
        port: 5433,
    });
    client.connect();
    const result = await client.query("select * from yb_servers()");
    const resultString = JSON.stringify(result.rows[0]);    

    client.end();

    const response = {
        "statusCode":200,
        "body":resultString
    };

    return response;

};

CAT


echo "$*" | grep role && {
aws iam create-role --role-name ybdemo-lambda-role --assume-role-policy-document file://trust-policy.json
sleep 1
}

npm install pg
node ybdemo-lambda.js && {
rm ybdemo-lambda-role.zip ; zip -r ybdemo-lambda-role.zip ybdemo-lambda.js node_modules ; aws lambda create-function \
    --function-name ybdemo-lambda \
    --runtime nodejs14.x \
    --zip-file fileb://ybdemo-lambda-role.zip \
    --handler ybdemo-lambda.handler \
    --role $( aws iam get-role --role-name ybdemo-lambda-role --output json | jq -r '."Role"."Arn"' )
sleep 5

aws lambda invoke --function-name ybdemo-lambda --cli-binary-format raw-in-base64-out --payload '{"numberA":"21","numberB":"21"}' .tmp.js && jq . < .tmp.js

aws lambda delete-function --function-name ybdemo-lambda
}

echo "$*" | grep role && {
aws iam delete-role --role-name ybdemo-lambda-role
}
