#!/bin/bash

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

if [ "$REPO_MODE" == "" ]; then
  if [ "$GIT_PRIVATE_KEY" != "" -o "$KEY_LOCATION" != "" ]; then
    export REPO_MODE="pullPush"
  else
    export REPO_MODE="pullOnly"
  fi
fi

# Additional options to be passed to the JVM can be provided via the
# TE_JAVA_OPTIONS environment variable
export JAVA_TOOL_OPTIONS="${TE_JAVA_OPTIONS} -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStore=${PROG_DIR}/testeditor.certs"
keytool -importkeystore -srckeystore $JAVA_HOME/lib/security/cacerts -destkeystore ${PROG_DIR}/testeditor.certs -srcstorepass changeit -deststorepass changeit -noprompt
if [ "$PROXY_CERT" != "" ]; then
  echo "importing certificate into java certificate store"
  keytool -importcert -file $PROXY_CERT -keystore ${PROG_DIR}/testeditor.certs -storepass changeit -noprompt -trustcacerts
fi

GRADLE_PROPS_TARGET_FILE=${PROG_DIR}/.gradle/gradle.properties
if [ "$GRADLE_PROPS_CONTENT" != "" ]; then
  echo "using gradle properties with content passed through env"
  mkdir -p `dirname $GRADLE_PROPS_TARGET_FILE`
  echo "$GRADLE_PROPS_CONTENT" > $GRADLE_PROPS_TARGET_FILE
elif [ "$GRADLE_PROPS" != "" ]; then
  echo "using gradle properties from file location passed through env"
  mkdir -p `dirname $GRADLE_PROPS_TARGET_FILE`
  cp ${GRADLE_PROPS} ${GRADLE_PROPS_TARGET_FILE}
fi

if [ -f $GRADLE_PROPS_TARGET_FILE -a "$http_proxyUser" != "" ]; then
  echo "configuring gradle properties with proxy credentials"
  sed -i "s|%http_proxyUser%|$http_proxyUser|g" ${GRADLE_PROPS_TARGET_FILE}
  sed -i "s|%http_proxyPassword%|$http_proxyPassword|g" ${GRADLE_PROPS_TARGET_FILE}
fi

if [ "$TIMEZONE" != "" ]; then
  echo "configuring timezone"
  export TZ="/usr/share/zoneinfo/$TIMEZONE"
fi

if [ "$GIT_PRIVATE_KEY" != "" ]; then
  echo "configuring private key for repo access"
  KEY_LOCATION=${PROG_DIR}/ssh-keys/ssh-privatekey
  mkdir -p `dirname $KEY_LOCATION`
  echo "$GIT_PRIVATE_KEY" > $KEY_LOCATION
  chmod 600 $KEY_LOCATION
  sha1sum $KEY_LOCATION
fi

KNOWN_HOSTS=${PROG_DIR}/ssh-keys/known_hosts
touch $KNOWN_HOSTS
if [ "$KNOWN_HOSTS_CONTENT" != "" ]; then
  echo "configuring known hosts"
  mkdir -p `dirname $KNOWN_HOSTS`
  echo "$KNOWN_HOSTS_CONTENT" > $KNOWN_HOSTS
fi

if [ "$ADD_KNOWN_HOSTS_DOMAIN" != "" ]; then
  echo "configuring additional known host domains: $ADD_KNOWN_HOSTS_DOMAIN"
  mkdir -p `dirname $KNOWN_HOSTS`
  DOMAIN="${ADD_KNOWN_HOSTS_DOMAIN%:*}"
  PORT="${ADD_KNOWN_HOSTS_DOMAIN/[a-z]*:/}"
  echo "using domain: $DOMAIN port: $PORT"
  ssh-keyscan -p $PORT $DOMAIN >> $KNOWN_HOSTS
fi

sed -i "s|%REPO_MODE%|$REPO_MODE|g" config.yml
sed -i "s|%TARGET_REPO%|$TARGET_REPO|g" config.yml
sed -i "s|%REPO_ROOT%|$REPO_ROOT|g" config.yml
sed -i "s|%BRANCH_NAME%|$BRANCH_NAME|g" config.yml
sed -i "s|%API_TOKEN_SECRET%|$API_TOKEN_SECRET|g" config.yml
sed -i "s|%KEY_LOCATION%|$KEY_LOCATION|g" config.yml
sed -i "s|%KNOWN_HOSTS%|$KNOWN_HOSTS|g" config.yml

export HOME=/opt/testeditor

export DISPLAY=:99.0

# /sbin/start-stop-daemon --start --quiet --pidfile /tmp/custom_xvfb_99.pid --make-pidfile --background --exec /usr/bin/Xvfb -- :99 -ac -screen 0 1920x1080x16

exec xvfb-run -w 30 -e xvfb.error.log --server-args="-screen 1 1920x1080x16" /usr/bin/bash -c "bin/org.testeditor.web.backend.persistence server config.yml"
# exec bin/org.testeditor.web.backend.persistence server config.yml
