FROM openjdk:8-jdk

# This image needs one environment variables upon execution:
# * TARGET_REPO
#   Defines the git repository used (read only)

LABEL license="EPL 1.0" \
      name="testeditor/xtext"

ENV PROG_DIR=/opt/testeditor \
    GRADLE_USER_HOME=/opt/testeditor/.gradle \
    REPO_ROOT=/repo \
    JAVA_TOOL_OPTIONS="-Djdk.http.auth.tunneling.disabledSchemes="

COPY testeditor/ \
     config.template.yml \
     run.sh \
     gradle.properties \
     ${PROG_DIR}/

RUN \
    apt-get update && apt-get install -y --no-install-recommends \
		openssh-client \
	&& rm -rf /var/lib/apt/lists/* && \
    \
    groupadd -g 5555 -r testeditor && \
    useradd -u 5555 -r -g testeditor -G root -d ${PROG_DIR} -s /sbin/nologin -c "service user" testeditor && \
    \
    mkdir -p ${PROG_DIR} && \
    mkdir -p ${REPO_ROOT} && \
    \
    mkdir ${PROG_DIR}/.gradle && \
    cp ${PROG_DIR}/gradle.properties ${PROG_DIR}/.gradle && \
    mv ${PROG_DIR}/config.template.yml ${PROG_DIR}/config.yml &&\
    \
    chmod --recursive ug+rwX,o-rwX ${PROG_DIR} && \
    chown --recursive testeditor:root ${PROG_DIR} && \
    chmod --recursive ug+rw,o-rwX ${REPO_ROOT} && \
    chown --recursive testeditor:root ${REPO_ROOT}

# group testeditor:
#   -r : group of a system account
#   -g : set group id
#
# user testeditor:
#   -u : set user id
#   -r : create system account (no password expiration ...), for services only
#   -g : group is set to "..."
#   -G : additional group(s)
#   -d : set home directory to work directory
#   -s : standard shell for this user is a non interactive shell
#   -c : comment set to "..."

# Port  Description
# ---------------------
# 8080  http
# 8081  http admin port

EXPOSE 8080 8081

USER testeditor

WORKDIR ${PROG_DIR}

ENTRYPOINT [ "./run.sh" ]
