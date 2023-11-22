#!/bin/sh
# set -eo pipefail
echo "[create.sh]"

# Make sure this script only replies to an Acorn creation event
if [ "${ACORN_EVENT}" != "create" ]; then
   echo "ACORN_EVENT must be [create], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Neon API URL
BASE_URL="https://console.neon.tech/api/v2"

# Check if project with that name already exits
res=$(curl -s "$BASE_URL/projects" \
 -H "Accept: application/json" \
 -H "Authorization: Bearer $NEON_API_KEY" | jq -r --arg project_name "$PROJECT_NAME" '
  if .projects then
    .projects[] | select(.name == $project_name)
  else
    empty
  end
')
if [ "$res" != "" ]; then
  echo "project ${PROJECT_NAME} already exists" | tee /dev/termination-log
  exit 1
fi 
echo "project ${PROJECT_NAME} does not exist"

# Create a project
echo "about to create project $PROJECT_NAME"
res=$(curl "$BASE_URL/projects" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $NEON_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{ 
        "project": { 
          "name": '\"${PROJECT_NAME}\"',
          "region_id": '\"${REGION}\"',
          "pg_version": '${DB_VERSION}'
        }
     }' | jq)

# Make sure the project was created correctly
if [ $? -ne 0 ]; then
  echo $res | tee /dev/termination-log
  exit 1
fi

# Get project identifier
project_id=$(echo $res | jq -r '.project.id')

# Get connection information
host=$(echo $res | jq -r '.connection_uris[0].connection_parameters.host')
db=$(echo $res | jq -r '.connection_uris[0].connection_parameters.database')
user=$(echo $res | jq -r '.connection_uris[0].connection_parameters.role')
pass=$(echo $res | jq -r '.connection_uris[0].connection_parameters.password')

# Extract proto and host from address returned
connection_string="postgres://$user:$pass@$host/$db?sslmode=require"
echo "connection string: $connection_string"

# Wait for db to be available
while true; do
    psql "$connection_string" -c "SELECT 1;" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "db available."
        break
    else
        echo "db not yet available. Waiting..."
        sleep 2
    fi
done

cat > /run/secrets/output<<EOF
services: neon: {
  address: "$host"
  secrets: ["user"]
  ports: "5432"
  data: {
    dbName: "$db"
  }
}
secret: user: {
  data:
    username: $user
    password: $pass
}
secret: state: {
  data: {
    created_project: $project_id
  }
}
EOF