#!/bin/bash

if [ -z "$jira_project_name" ]; then
    echo "Jira Project Name is required."
    usage
fi

if [ -z "$jira_url" ]; then
    echo "Jira Url is required."
    usage
fi

if [ -z "$jira_token" ]; then
    echo "Jira token is required."
    usage
fi

if [ -z "$from_status" ]; then
    echo "Status of tasks for deployment is required."
    usage
fi

length=${#jira_project_name}

from_git=1
if [ -z "$check_git" ]; then
    echo "check_git is null: $check_git"
    from_git=0
else
    from_git=$check_git
    echo "check_git is not null: $check_git"
fi

if [ $from_git -gt 0 ]; then
    echo "from git"
else
    echo "not from git"
fi


CLOSED_TASKS=$(git --no-pager log --pretty='format:%b' -n 100 | grep -oE "([A-Z]{$length}-[0-9]+)");

echo $CLOSED_TASKS

if [ -z "$CLOSED_TASKS" ]; then
    echo "No tasks to transition found in git log"
    exit 0
fi

query=$(jq -n \
    --arg jql "project = $jira_project_name AND status = '$from_status'" \
    '{ jql: $jql, startAt: 0, maxResults: 100, fields: [ "id" ], fieldsByKeys: false }'
);

echo "Query to be executed in Jira: $query"

tasks_to_close=$(curl -s \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $jira_token" \
    --request POST \
    --data "$query" \
    "$jira_url/rest/api/2/search" | jq -r '.issues[].key'
)

echo "Tasks to transition: $tasks_to_close"

for task in ${tasks_to_close}
do
    case "$CLOSED_TASKS" in
        *"$task"*)
            echo "Transitioning $task"
            if [[ -n "$version" && -n "$custom_jira_field" ]]; then
                echo "Setting version of $task to $version"
                    query=$(jq -n \
                        --arg version $version \
                        "{ fields: { $custom_jira_field:  \"$version\" } }"
                    );

                curl \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Basic $jira_token" \
                    --request PUT \
                    --data "$query" \
                    "$jira_url/rest/api/2/issue/$task"
            fi

            if [ -n "$to_status" ]; then
                echo "Getting possible transitions for $task"

                transition_id=$(curl -s \
                    -H "Authorization: Basic $jira_token" \
                    "$jira_url/rest/api/2/issue/$task/transitions" | \
                    jq -r ".transitions[] | select( .to.name == \"$to_status\" ) | .id")

                if [ -n "$transition_id" ]; then
                    echo "Transitioning $task to $to_status"
                    query=$(jq -n \
                        --arg transition_id $transition_id \
                        '{ transition: { id: $transition_id } }'
                    );

                    curl \
                        -H "Content-Type: application/json" \
                        -H "Authorization: Basic $jira_token" \
                        --request POST \
                        --data "$query" \
                        "$jira_url/rest/api/2/issue/$task/transitions"
                else
                    echo "No matching transitions from status '$from_status' to '$to_status' for $task"
                fi
            fi
            ;;
    esac
done

query=$(jq -n \
    --arg jql "project = $jira_project_name AND status = '$from_status' AND 'Platform[Dropdown]' = '🍏 iOS'" \
    '{ jql: $jql, startAt: 0, maxResults: 100, fields: [ "id", "summary" ], fieldsByKeys: false }'
);


json=$(curl -s \
    --request POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Basic $jira_token" \
    --data "$query" \
    "$jira_url/rest/api/2/search"
);

count=$(echo $json | jq -r '.total')

echo "issues count = $count"

result=""
for i in $(seq 1 $count);
do
    sum=$(echo $json | jq -r ".issues[$i-1].fields.summary")
    newline=$'\n'
    result="$result $newline $sum"
done

envman add --key JIRA_DEPLOYED_LIST --value "$result"
