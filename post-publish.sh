#!/bin/sh

# --------------------------------------------------------------------------------------------

# There are four environment variables that need to be configured for the Jira integration: JIRA_AUTH, JIRA_BASE_URL and JIRA_TRANSITION_ID. To add a variable, follow these steps:

# Open your Codemagic app settings, and go to the Environment variables tab.
# Enter the desired Variable name, e.g. JIRA_AUTH.
# Enter the required value as Variable value.
# Enter the variable group name, e.g. jira_credentials. Click the button to create the group.
# Make sure the Secure option is selected.
# Click the Add button to add the variable.
# Repeat the process to add all of the required variables.

# --------------------------------------------------------------------------------------------

# Exit immediately if a pipeline returns a non-zero status.
set -e
# Print a trace of simple commands and their arguments after they are expanded and before they are executed.
set -x

IOS_ARTIFACT_TYPE=".ipa"
ANDROID_ARTIFACT_TYPE=".apk"

IOS_ARTIFACT_URL=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$IOS_ARTIFACT_TYPE"'")) | .url')
IOS_ARTIFACT_NAME=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$IOS_ARTIFACT_TYPE"'")) | .name')
IOS_TYPE=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$IOS_ARTIFACT_TYPE"'")) | .type')
IOS_BUNDLE=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$IOS_ARTIFACT_TYPE"'")) | .bundleId')

ANDROID_ARTIFACT_URL=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$ANDROID_ARTIFACT_TYPE"'")) | .url')
ANDROID_ARTIFACT_NAME=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$ANDROID_ARTIFACT_TYPE"'")) | .name')
ANDROID_TYPE=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$ANDROID_ARTIFACT_TYPE"'")) | .type')
ANDROID_BUNDLE=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$ANDROID_ARTIFACT_TYPE"'")) | .bundleId')


VERSION_NAME=$(echo $FCI_ARTIFACT_LINKS | jq -r '.[] | select(.name | endswith("'"$IOS_ARTIFACT_TYPE"'")) | .versionName')
BUILD_VERSION=$(( ${BUILD_NUMBER} + 1))

BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")

IOS_TEST_URL=$(echo "${IPA_URL}" | sed 's#/#\\/#g')

ANDROID_TEST_URL=$(echo "${APK_URL}" | sed 's#/#\\/#g')

# Get the commit hash from the commit that links to the epic f.e. 'PROJ-1234: increase version to 1.4.3'
COMMIT_HASH=$(echo "${FCI_COMMIT}" | sed 's/^\(........\).*/\1/;q')

GIT_COMMIT_MESSAGE=$(git log --format=%B -n 1 $FCI_COMMIT)

JIRA_ISSUE=$(git log --pretty=oneline -n 1 | grep -e '[A-Z]\+-[0-9]\+' -o)

# Populate the values in the .json template which will be used as the
# JSON payload that will be set as a comment in Jira.
sed -i.bak "s/\$BUILD_DATE/$BUILD_DATE/" .templates/jira.json
sed -i.bak "s/\$ANDROID_ARTIFACT_NAME/$ANDROID_ARTIFACT_NAME/" .templates/jira.json
sed -i.bak "s/\$IOS_ARTIFACT_NAME/$IOS_ARTIFACT_NAME/" .templates/jira.json
sed -i.bak "s/\$ANDROID_ARTIFACT_URL/$TEST_URL/" .templates/jira.json
sed -i.bak "s/\$IOS_ARTIFACT_URL/$TEST_URL/" .templates/jira.json
sed -i.bak "s/\$FCI_COMMIT/$COMMIT/" .templates/jira.json
sed -i.bak "s/\$GIT_COMMIT_MESSAGE/$GIT_COMMIT_MESSAGE/" .templates/jira.json
sed -i.bak "s/\$VERSION_NAME/$VERSION_NAME/" .templates/jira.json
sed -i.bak "s/\$BUILD_VERSION/$BUILD_VERSION/" .templates/jira.json
sed -i.bak "s/\$ANDROID_BUNDLE/$ANDROID_BUNDLE/" .templates/jira.json
sed -i.bak "s/\$IOS_BUNDLE/$IOS_BUNDLE/" .templates/jira.json
sed -i.bak "s/\$ANDROID_TYPE/$ANDROID_TYPE/" .templates/jira.json
sed -i.bak "s/\$IOS_TYPE/$IOS_TYPE/" .templates/jira.json

# Add a comment to Jira
# See https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-comments/#api-rest-api-3-comment-list-post for details
curl -X POST https://$JIRA_BASE_URL/rest/api/3/issue/$JIRA_ISSUE/comment -H "Authorization: Basic $JIRA_AUTH" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" --data @.templates/jira.json | jq "."


# Transition Jira issue to another status
# See https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-transitions-post for details
curl -X POST https://$JIRA_BASE_URL/rest/api/3/issue/$JIRA_ISSUE/transitions -H "Authorization: Basic $JIRA_AUTH" -H "X-Atlassian-Token: nocheck" -H "Content-Type: application/json" --data '{"transition":{"id":"'"$JIRA_TRANSITION_ID"'"}}' | jq "."