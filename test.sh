#!/bin/bash

jira_token="YS5uYXVtZW5rb0BkaXJpb24uYml6OnFLODVnMk9DclRIUEtQSlM5MEhnOUIzQQ=="
jira_url="https://spacejob.atlassian.net"
jira_project_name="UMOBILE"

query=$(jq -n \
    --arg jql "project = $jira_project_name AND status = 'WAITING FOR DEPLOY' AND 'Platform[Dropdown]' = '🍏 iOS'" \
    '{ jql: $jql, startAt: 0, maxResults: 50, fields: [ "id", "summary" ], fieldsByKeys: false }'
);


json=$(curl -s \
    --request POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $jira_token" \
    --data "$query" \
    "$jira_url/rest/api/2/search"
);

count=$(echo $json | jq -r '.total')

result=""
for i in $(seq 1 $count);
do
    sum=$(echo $json | jq -r ".issues[$i-1].fields.summary")
    newline=$'\n'
    result="$result $newline $sum"
done

JIRA_DEPLOYED_LIST=$result

echo "$JIRA_DEPLOYED_LIST"
