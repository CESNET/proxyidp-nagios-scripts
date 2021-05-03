#!/bin/bash
#########################################################################
## Script to check for new commits in the specified local git repos.   ##
## Copares hash of the HEAD with the origin/production latest commit's ##
## hash.                                                               ##
## Status 0 indicates repository being up-to-date                      ##
## Status 1 indicates the commits are different and update can be made ##
## Status 2 indicates that given directory does not exist or it is not ##
## a valid git repository. Invalid repo is when it is not git repo at  ##
## all, or the origin/production branch does not exist in remote repo  ##
#########################################################################

# List of paths to check separated by space
REPOS=""

function print_result {
    echo "$1 git_pull_check_dir=$2"
}

for REPO_PATH in $REPOS
do
    if [[ -d $REPO_PATH ]]; then
        cd $REPO_PATH
        git status >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            STATUS=2
            STATUS_TEXT="CRITICAL - Directory $REPO_PATH is not a git repository"
            print_result "$STATUS" "$STATUS_TEXT"
            continue;
        fi
        git fetch origin >/dev/null 2>&1
        git ls-remote --exit-code --heads origin production >/dev/null 2>&1
        if [[ $? -ne 0 ]]; then
            STATUS=2
            STATUS_TEXT="CRITICAL - Repository $REPO_PATH does not have origin/production"
            print_result "$STATUS" "$STATUS_TEXT"
            continue;
        fi
        LOCAL_HASH=$(git rev-parse HEAD 2>/dev/null)
        REMOTE_HASH=$(git rev-parse origin/production 2>/dev/null)
        if [[ "$LOCAL_HASH" == "$REMOTE_HASH" ]] ; then
            STATUS=0
            STATUS_TEXT="OK"
        else
            STATUS=1
            STATUS_TEXT="WARNING - New commits available in $REPO_PATH"
        fi
    else
        STATUS=2
        STATUS_TEXT="CRITICAL - Directory $REPO_PATH does not exist"
    fi
    print_result "$STATUS" "$STATUS_TEXT"
done

