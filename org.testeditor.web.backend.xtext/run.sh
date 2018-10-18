#!/bin/bash

if [ "$BRANCH_NAME" == "" ]; then
  export BRANCH_NAME="master"
fi

##
# Options configuring JVM memory settings:
# * "XX:+UnlockExperimentalVMOptions" and "-XX:+UseCGroupMemoryLimitForHeap" instruct the JVM to base its heap memory limits on cgroups (/sys/fs/cgroup/memory/memory.limit_in_bytes), rather than the machine's total available RAM.
# * "Dsun.zip.disableMemoryMapping=true" disables memory mapping when handling zips and jars to alleviate a crash risk.
#     * In Java 9, the implementation of class ZipFile was adapted to remove the crash risk, and the above option will not be needed anymore. See https://bugs.openjdk.java.net/browse/JDK-8142508, https://bugs.openjdk.java.net/browse/JDK-8175192
# * "XX:+UseParallelGC", "XX:MinHeapFreeRatio=5", "XX:MaxHeapFreeRatio=10", "XX:GCTimeRatio=4", and "XX:AdaptiveSizePolicyWeight=90" tailor the JVM to more eagerly return free memory to the operating system.
##
export JAVA_TOOL_OPTIONS="-Djdk.http.auth.tunneling.disabledSchemes= -Djavax.net.ssl.trustStorePassword=changeit -Djavax.net.ssl.trustStore=${PROG_DIR}/testeditor.certs -XX:+UnlockExperimentalVMOptions -XX:+UseCGroupMemoryLimitForHeap -Dsun.zip.disableMemoryMapping=true -XX:+UseParallelGC -XX:MinHeapFreeRatio=5 -XX:MaxHeapFreeRatio=10 -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90"
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
fi

if [ "$KNOWN_HOSTS_CONTENT" != "" ]; then
  echo "configuring known hosts"
  KNOWN_HOSTS=${PROG_DIR}/ssh-keys/known_hosts
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
