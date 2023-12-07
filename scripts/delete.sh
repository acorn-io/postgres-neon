#!/bin/sh
# set -eo pipefail

echo "[delete.sh]"

# Make sure this script only replies to an Acorn deletion event
if [ "${ACORN_EVENT}" != "delete" ]; then
   echo "ACORN_EVENT must be [delete], currently is [${ACORN_EVENT}]"
   exit 0
fi
 
# Delete the project and database created by this service (if any)
echo "PROJECT ID: ${PROJECT_ID}"
echo "CREATED_PROJECT: ${CREATED_PROJECT}"
echo "CREATED_DATABASE: ${CREATED_DATABASE}"

if [ "$CREATED_PROJECT" = "" ]; then
  echo "project not created by the service => will not be deleted"

  if [ "$CREATED_DATABASE" = "" ]; then
    echo "database not created by the service => will not be deleted"
  else
    res=$(neonctl database delete ${CREATED_DATABASE} --project-id ${PROJECT_ID})
    if [ $? -ne 0 ]; then
      echo "error deleting database: $res"
    else
      echo "database deleted" 
    fi
  fi
else
  echo "project was created by the service => will be deleted"
  res=$(neonctl projects delete ${CREATED_PROJECT})
  if [ $? -ne 0 ]; then
    echo "error deleting project: $res"
  else
    echo "project deleted" 
  fi
fi

