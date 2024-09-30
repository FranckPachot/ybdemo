
echo "
Create an account on http://cloud.yugabyte.com
Create an API KEY
Save the API KEY, Account ID and Project ID
"
echo "API KEY:"
read YBM_API_KEY
echo "Account ID:"
read YBM_ACCOUNT_ID
echo "Project ID:"
read YBM_PROJECT_ID

set -x

echo ; set | grep ^YBM_ | cut -c1-80

YBM_SOFTWARE="Preview"

YBM_SOFTWARE_TRACK_ID=$(
curl -s --request GET \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/software-tracks \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' | \
  tee /dev/stderr |
  jq -r '.data[] | select(.spec.name=="'$YBM_SOFTWARE'") | .info.id '
)
echo ; set | grep ^YBM_ | cut -c1-80

YBM_ALLOW_LIST="home"

curl -s --request POST \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/allow-lists  \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "name": "'${YBM_ALLOW_LIST}'",
  "description": "Gathered from http://ifconfig.me",
  "allow_list": [
    "'$(curl -s ifconfig.me)'/32"
  ]
}'

YBM_ALLOW_LIST_ID=$(
curl -s --request GET \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/allow-lists \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' |
  tee /dev/stderr |
  jq -r '.data[] | select(.spec.name=="'${YBM_ALLOW_LIST}'") | .info.id'
)
echo ; set | grep ^YBM_ | cut -c1-80

YBM_CLUSTER="my-free-yugabytedb"
YBM_ADMIN_PASSWORD="**********"

curl -s --request POST \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/clusters \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' \
  --data '{
  "cluster_spec": {
    "name": "'$YBM_CLUSTER'",
    "cloud_info": {
      "code": "AWS",
      "region": "eu-west-1"
    },
    "cluster_info": {
      "cluster_tier": "FREE",
      "cluster_type": "SYNCHRONOUS",
      "num_nodes": 1,
      "fault_tolerance": "NONE",
      "node_info": {
        "num_cores": 2,
        "memory_mb": 4096,
        "disk_size_gb": 10
      },
      "is_production": false,
      "version": null
    },
    "network_info": {
      "single_tenant_vpc_id": null
    },
    "software_info": {
      "track_id": "'$YBM_SOFTWARE_TRACK_ID'"
    },
    "cluster_region_info": [
      {
        "placement_info": {
          "cloud_info": {
            "code": "AWS",
            "region": "eu-west-1"
          },
          "num_nodes": 1,
          "vpc_id": null,
          "num_replicas": 1,
          "multi_zone": false
        },
        "is_default": true,
        "is_affinitized": true,
        "accessibility_types": [
          "PUBLIC"
        ]
      }
    ]
  },
  "allow_list_info": [ "'"$YBM_ALLOW_LIST_ID"'" ],
  "db_credentials": {
    "ycql": {
      "username": "admin",
      "password": "'"$YBM_ADMIN_PASSWORD"'"
    },
    "ysql": {
      "username": "admin",
      "password": "'"$YBM_ADMIN_PASSWORD"'"
    }
  }
}'

YBM_CLUSTER_ID=$(
curl -s --request GET \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/clusters \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' | 
  tee /dev/stderr |
  jq -r '.data[] | select(.spec.name=="'$YBM_CLUSTER'") | .info.id'
)
echo ; set | grep ^YBM_ | cut -c1-80

curl -s --request POST \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/clusters/$YBM_CLUSTER_ID/pause \
  --header "Authorization: Bearer $YBM_API_KEY" --data ''

echo "Waiting that status is ACTIVE"

until curl -s --request GET   --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/clusters/$YBM_CLUSTER_ID   --header "Authorization: Bearer $YBM_API_KEY" |
 grep '"state":"ACTIVE"' ; do sleep 10 ; done

PGDATABASE=yugabyte
PGUSER="admin"
PGPASSWORD="$YBM_ADMIN_PASSWORD"
PGPORT="5433"
PGSSLMODE=require

PGHOST=$(
curl -s --request GET \
  --url https://cloud.yugabyte.com/api/public/v1/accounts/$YBM_ACCOUNT_ID/projects/$YBM_PROJECT_ID/clusters \
  --header "Authorization: Bearer $YBM_API_KEY" \
  --header 'Content-Type: application/json' | 
  tee /dev/stderr |
  jq -r '.data[] | select(.spec.name=="'$YBM_CLUSTER'") | .info.cluster_endpoints[0].host '
)
echo ; set | grep ^PG
export PGDATABASE PGUSER PGHOST PGPORT PGPASSWORD PGSSLMODE
