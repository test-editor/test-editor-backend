#!/bin/bash

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

if [ "$REPO_MODE" == "" ]; then
  if [ "$GIT_PRIVATE_KEY" != "" ]; then
    export REPO_MODE="pullPush"
  else
    export REPO_MODE="pullOnly"
  fi
fi

if [ "$GIT_PRIVATE_KEY" != "" ]; then
  echo "$GIT_PRIVATE_KEY" > /opt/testeditor/id_git_rsa
else
  touch /opt/testeditor/id_git_rsa
fi
sed -i "s|%KEY_LOCATION%|/opt/testeditor/id_git_rsa|g" config.yml

if [ "$KNOWN_HOSTS" != "" ]; then
  echo "$KNOWN_HOSTS" > /opt/testeditor/known_hosts
else
  touch /opt/testeditor/known_hosts
fi
sed -i "s|%KNOWN_HOSTS%|/opt/testeditor/known_hosts|g" config.yml

sed -i "s|%REPO_MODE%|$REPO_MODE|g" config.yml
sed -i "s|%TARGET_REPO%|$TARGET_REPO|g" config.yml
sed -i "s|%REPO_ROOT%|$REPO_ROOT|g" config.yml
sed -i "s|%BRANCH_NAME%|$BRANCH_NAME|g" config.yml
sed -i "s|%API_TOKEN_SECRET%|$API_TOKEN_SECRET|g" config.yml

export HOME=/opt/testeditor

export DISPLAY=:99.0

/sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -ac -screen 0 1920x1080x16

bin/org.testeditor.web.backend.persistence server config.yml
