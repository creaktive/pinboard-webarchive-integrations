#!/bin/bash
webarchive=webarchive.json
webarchive_tmp=/tmp/webarchive.json

jq -crs '[.[] | select(.archived_snapshots.closest.status == "200")] | sort_by(.timestamp) | .[]' < $webarchive > $webarchive_tmp

if [ $? -ne 0 ]; then
    echo "jq error" &>2
else
    mv $webarchive "$webarchive.bak"
    mv $webarchive_tmp $webarchive
fi
