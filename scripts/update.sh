#!/bin/sh
# set -eo pipefail
echo "[update.sh]"

# Make sure this script only replies to an Acorn creation event
if [ "${ACORN_EVENT}" != "update" ]; then
   echo "ACORN_EVENT must be [update], currently is [${ACORN_EVENT}]"
   exit 0
fi

echo "Update not taken into account yet" | tee /tmp/termination-log
exit 0