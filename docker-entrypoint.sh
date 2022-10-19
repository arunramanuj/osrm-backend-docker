#!/bin/bash

# Defaults
OSRM_MODE="CREATE"
OSRM_DATA_PATH=${OSRM_DATA_PATH:="/osrm-data"}
OSRM_DATA_LABEL=${OSRM_DATA_LABEL:="data"}
OSRM_GRAPH_PROFILE=${OSRM_GRAPH_PROFILE:="car"}
OSRM_GRAPH_PROFILE_URL=${OSRM_GRAPH_PROFILE_URL:=""}
OSRM_PBF_URL=${OSRM_PBF_URL:="http://download.geofabrik.de/asia/maldives-latest.osm.pbf"}
OSRM_MAX_TABLE_SIZE=${OSRM_MAX_TABLE_SIZE:="8000"}
# AWS S3 parameters
OSRM_S3_BUCKET=${OSRM_S3_BUCKET:="s3://osrm-geo-data"}


_sig() {
  kill -TERM $child 2>/dev/null
}
trap _sig SIGKILL SIGTERM SIGHUP SIGINT EXIT

if [ "$OSRM_MODE" == "CREATE" ]; then
  # Retrieve the PBF file
  curl -L $OSRM_PBF_URL --create-dirs -o $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osm.pbf

  # Set the graph profile path
  OSRM_GRAPH_PROFILE_PATH="/osrm-profiles/$OSRM_GRAPH_PROFILE.lua"

  # If the URL to a custom profile is provided override the default profile
  if [ ! -z "$OSRM_GRAPH_PROFILE_URL" ]; then
    # Set the custom graph profile path
    OSRM_GRAPH_PROFILE_PATH="/osrm-profiles/custom-profile.lua"
    # Retrieve the custom graph profile
    curl -L $OSRM_GRAPH_PROFILE_URL --create-dirs -o $OSRM_GRAPH_PROFILE_PATH
  fi

  # Build the graph
  osrm-extract $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osm.pbf -p $OSRM_GRAPH_PROFILE_PATH
  osrm-customize $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osrm

  # Save to AWS S3
  aws s3 cp $OSRM_DATA_PATH/. $OSRM_S3_BUCKET/$OSRM_DATA_LABEL
else # RESTORE DATA
  # Copy the OSRM data from S3
  aws s3 cp $OSRM_S3_BUCKET/$OSRM_DATA_LABEL $OSRM_DATA_PATH/.
fi

# Start serving requests
osrm-routed $OSRM_DATA_PATH/$OSRM_DATA_LABEL.osrm --algorithm mld &
child=$!
wait "$child"
