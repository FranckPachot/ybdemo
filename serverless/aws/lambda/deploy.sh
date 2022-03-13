
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
exports.handler = async function(event) {
  const { numberA, numberB} = event;

  return {
    "sumResult": numberA + numberB
  };
}
CAT

zip ybdemo-lambda-role.zip ybdemo-lambda.js

aws iam create-role --role-name ybdemo-lambda-role --assume-role-policy-document file://trust-policy.json
sleep 1

aws lambda create-function \
    --function-name ybdemo-lambda \
    --runtime nodejs14.x \
    --zip-file fileb://ybdemo-lambda-role.zip \
    --handler ybdemo-lambda.handler \
    --role $( aws iam get-role --role-name ybdemo-lambda-role --output json | jq -r '."Role"."Arn"' )
sleep 5

aws lambda invoke --function-name ybdemo-lambda --cli-binary-format raw-in-base64-out --payload '{"numberA":"21","numberB":"21"}' .tmp.js && jq . < .tmp.js
sleep 1

aws lambda delete-function --function-name ybdemo-lambda
aws iam delete-role --role-name ybdemo-lambda-role
