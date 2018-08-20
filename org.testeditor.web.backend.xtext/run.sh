#!/bin/bash

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

export JAVA_TOOL_OPTIONS="-Djdk.http.auth.tunneling.disabledSchemes= -Djavax.net.ssl.trustStore=${PROG_DIR}/testeditor.certs"
keytool -importkeystore -srckeystore $JAVA_HOME/jre/lib/security/cacerts -destkeystore ${PROG_DIR}/testeditor.certs -srcstorepass changeit -deststorepass changeit -noprompt
if [ "$PROXY_CERT" != "" ]; then
  keytool -importcert -file $PROXY_CERT -keystore ${PROG_DIR}/testeditor.certs -storepass changeit -noprompt -trustcacerts
fi

if [ "$GRADLE_PROPS" != "" ]; then
  if [ "$http_proxyUser" != "" ]; then
    sed -i "s|%http_proxyUser%|$http_proxyUser|g" ${GRADLE_PROPS}
    sed -i "s|%http_proxyPassword%|$http_proxyPassword|g" ${GRADLE_PROPS}
  fi
  mkdir ${PROG_DIR}/.gradle
  cp ${GRADLE_PROPS} ${PROG_DIR}/.gradle
fi

if [ "$TIMEZONE" != "" ]; then
  export TZ="/usr/share/zoneinfo/$TIMEZONE"
fi

if [ "$GIT_PRIVATE_KEY" != "" ]; then
  KEY_LOCATION=/etc/ssh-keys/ssh-privatekey
  mkdir -p `dirname $KEY_LOCATION`
  echo "$GIT_PRIVATE_KEY" > $KEY_LOCATION
  chmod 600 $KEY_LOCATION
fi

if [ "$KNOWN_HOSTS_CONTENT" != "" ]; then
  KNOWN_HOSTS=/etc/ssh-keys/known_hosts
  mkdir -p `dirname $KNOWN_HOSTS`
  echo "$KNOWN_HOSTS_CONTENT" > $KNOWN_HOSTS
fi

sed -i "s|%TARGET_REPO%|$TARGET_REPO|g" config.yml
sed -i "s|%REPO_ROOT%|$REPO_ROOT|g" config.yml
sed -i "s|%BRANCH_NAME%|$BRANCH_NAME|g" config.yml
sed -i "s|%API_TOKEN_SECRET%|$API_TOKEN_SECRET|g" config.yml
sed -i "s|%KEY_LOCATION%|$KEY_LOCATION|g" config.yml
sed -i "s|%KNOWN_HOSTS%|$KNOWN_HOSTS|g" config.yml

export HOME=/opt/testeditor

bin/org.testeditor.web.backend.xtext server config.yml
