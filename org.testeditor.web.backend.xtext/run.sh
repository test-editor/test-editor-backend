#!/bin/bash

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

sed -i "s|%TARGET_REPO%|$TARGET_REPO|g" config.yml
sed -i "s|%REPO_ROOT%|$REPO_ROOT|g" config.yml
sed -i "s|%BRANCH_NAME%|$BRANCH_NAME|g" config.yml
sed -i "s|%API_TOKEN_SECRET%|$API_TOKEN_SECRET|g" config.yml

export HOME=/opt/testeditor

bin/org.testeditor.web.backend.xtext server config.yml
