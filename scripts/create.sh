#!/bin/sh
# set -eo pipefail
echo "[create.sh]"

# Couple of variables to make local testing simpler
termination_log="/dev/termination-log"
acorn_output="/run/secrets/output"

# Make sure this script only replies to an Acorn creation event
if [ "${ACORN_EVENT}" = "delete" ]; then
   echo "ACORN_EVENT must be  [create, update], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Keep track of project_id
project_id=""

# Used to identify project and database created in this script
created_project=""
created_database=""

# Check if project with that name already exits
res=$(neonctl projects list -o json | jq -r --arg project_name "${PROJECT_NAME}" '.[] | select(.name == $project_name)')
if [ "$res" != "" ]; then
  echo "project ${PROJECT_NAME} already exists"
else
  echo "project ${PROJECT_NAME} does not exist => will be created"
  res=$(neonctl projects create --name ${PROJECT_NAME} --region-id ${REGION} -o json 2>&1)
  if [ $? -ne 0 ]; then
    echo "project ${PROJECT_NAME} cannot be created"
    echo $res | tee ${termination_log}
    exit 1
  fi
  echo "project ${PROJECT_NAME} created"
  
  # Get project identifier
  project_id=$(neonctl projects list -o json | jq -r --arg project_name "${PROJECT_NAME}" '.[] | select(.name == $project_name) | .id')
  echo "project identifier is [${project_id}]"

  # Keep track of created project (this will be checked in the deletion step)
  created_project=${project_id}
fi 

# Check if database with that name already exits for that project
res=$(neonctl databases list --project-id ${project_id} -o json | jq -r --arg database_name "$DB_NAME" '.[] | select(.name == $database_name)')
if [ "$res" != "" ]; then
  # echo "database ${DB_NAME} already exists" | tee /dev/termination-log
  echo "database ${DB_NAME} already exists"
else
  echo "database ${DB_NAME} does not exist => will be created"
  res=$(neonctl databases create --name ${DB_NAME} --project-id ${project_id} -o json 2>&1)
  if [ $? -ne 0 ]; then
    echo "database ${PROJECT_NAME} cannot be created"
    echo $res | tee ${termination_log}
    exit 1
  fi
  echo "database ${DB_NAME} created"

  # Keep track of created database (this will be checked in the deletion step)
  created_database=${DB_NAME}
fi

# Get connection information
echo "getting connection string for database ${DB_NAME}"
conn=$(neonctl connection-string --database-name "${DB_NAME}" --extended -o json)
connection_string=$(echo $conn | jq -r '.connection_string')
host=$(echo $conn | jq -r '.host')
db=$(echo $conn | jq -r '.database')
user=$(echo $conn | jq -r '.role')
pass=$(echo $conn | jq -r '.password')
echo "connection string: [${connection_string}]"

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

cat > ${acorn_output}<<EOF
services: neon: {
  address: "$host"
  secrets: ["user"]
  ports: "5432"
  data: {
    dbName: "$db"
  }
}
secrets: {
  user: {
    data: {
      username: "$user"
      password: "$pass"
    }
  }
  state: {
    data: {
      project_id: "${project_id}"
      created_project: "${created_project}"
      created_database: "${created_database}"
    }
  }
}
EOF