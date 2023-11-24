#!/bin/sh
# set -eo pipefail

echo "[delete.sh]"

# Make sure this script only replies to an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi

# Neon API URL
BASE_URL="https://console.neon.tech/api/v2"

# Make sure a project with the name provided exists
project=$(curl -s "$BASE_URL/projects" \
 -H "Accept: application/json" \
 -H "Authorization: Bearer $NEON_API_KEY" | jq -r --arg project_name "$PROJECT_NAME" '
  if .projects then
    .projects[] | select(.name == $project_name)
  else
    empty
  end
')
if [ "$project" = "" ]; then
  echo "project ${PROJECT_NAME} does not exist" | tee /dev/termination-log
  exit 1
fi 
echo "project ${PROJECT_NAME} exists"

# Get project identifier
project_id=$(echo $project | jq -r '.id')
echo "Project identifier is [$project_id]"

# Delete the project is the one created by this service
if [ "$project_id" != "${CREATED_PROJECT}" ]; then
  echo "project not created by the service => will not be deleted"
else
  echo "project was created by the service => will be deleted"
  res=$(curl -s -XDELETE "$BASE_URL/projects/$project_id" \
  -H "Accept: application/json" \
  -H "Authorization: Bearer $NEON_API_KEY" | jq)
  if [ $? -ne 0 ]; then
    echo "error deleting project: $res"
  else
    echo "project deleted" 
  fi
fi

