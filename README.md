[![License](http://img.shields.io/badge/license-EPL-blue.svg?style=flat)](https://www.eclipse.org/legal/epl-v10.html)

# Run

This repository contains two backend services. One for the persistence and one for the Xtext services.
Run them using Gradle:

``` shell
./gradlew :org.testeditor.web.backend.persistence:run
./gradlew :org.testeditor.web.backend.xtext:run
```
alternatively, start both in parallel: `./gradlew run --parallel`

# Development

## Setup development

Make sure to have a working [nix](https://nixos.org/nix/) installation. Please ensure that the `nixpkgs-unstable` channel is available. It
can be added with `nix-channel --add https://nixos.org/channels/nixpkgs-unstable`.

To enter the development environment, execute `NIXPKGS_ALLOW_UNFREE=1 nix-shell` in this repos root directory. For even more convenience,
please install [direnv](https://github.com/direnv/direnv) which will enter the development environment automatically for you.

Once within the development environment, run the steps under `Running` to resolve all necessary dependencies.


## Release

To release persistence and xtext backend, simply execute `./gradlew release` on the locally checked out master branch. This will build and test locally, and, if successful, tag the release with 'v${version}' (version is entered during the release process), commit it, write the new (entered) development version into `gradle.properties`, and commit again.
The Travis build will recognize tagged master branches and push docker images to docker hub, tagged accordingly.

## Local development

In order to allow building with non-published, locally built artifacts, gradle can be executed with the `-I` option.

E.g. building and running the backend services with a snapshot version of the test editor language (built locally and installed into maven local) and with a yet unpublished xtext-dropwizard version (built locally and installed into maven local) the following needs to be set up:
1. `init.gradle` with the following content:
``` groovy
allprojects {
    repositories {
        // add maven local repo to be able to fetch locally built artifacts
        mavenLocal()
    }
    ext.versions = [
        testEditorDropwizard: '0.17.0-SNAPSHOT',       // use locally built, not yet published version
        testEditorLanguage: '1.18.0-SNAPSHOT' // use locally built language version
    ]
    ext.localconfig = true // make sure to use config.local.yml as dropwizard configuration
}
```
2. config.local.yml (within `test-editor-backend/org.testeditor.web.backend.persistence`):
``` yaml
remoteRepoUrl: http://any.repo.of.your.choice
branchName: feature/some
repoConnectionMode: pullOnly

server:
  applicationConnectors:
  - type: http
    port: 9080
  adminConnectors:
  - type: http
    port: 9081
```
3. config.local.yml (within `test-editor-backend/org.testeditor.web.backend.xtext`):
``` yaml
remoteRepoUrl: http://any.repo.of.your.choice
branchName: feature/some
apiToken: secret
server:
  applicationConnectors:
  - type: http
    port: 8080
  adminConnectors:
  - type: http
    port: 8081
```

## Running

Having all these in place, executing `./gradlew -I init.gradle run --parallel` will automatically build the backend services with the dependency versions specified in `init.gradle` and use the `config.local.yml` when starting dropwizard.

## Running backend via docker with full pull/push of a github repo

Create a shell file 'start.test-repo-pull.local.sh' with the following content:
(make sure to have the right id_github_rsa key and the right branch name in place)
``` shell
#! /usr/bin/env bash
echo "starting persistence backend locally"
docker run -p 9080:8080 -e GIT_PRIVATE_KEY="$(cat ~/.ssh/id_github_rsa)" -e KNOWN_HOSTS_CONTENT="$(cat ~/.ssh/known_hosts)" -e TARGET_REPO=git@github.com:test-editor/language-examples.git -e BRANCH_NAME=test/pull-action testeditor/persistence:snapshot &
echo "starting xtext backend locally"
docker run -p 8080:8080 -e GIT_PRIVATE_KEY="$(cat ~/.ssh/id_github_rsa)" -e KNOWN_HOSTS_CONTENT="$(cat ~/.ssh/known_hosts)" -e TARGET_REPO=git@github.com:test-editor/language-examples.git -e BRANCH_NAME=test/pull-action testeditor/xtext:snapshot &
```

## Debugging

In order to debug the backend services you must start the backend services individually.
That is, for the persistence service:

``` shell
cd org.testeditor.web.backend.persistence
../gradlew -I ../init.gradle -Drun.debug=true run
```

This will run the persistence backend service (with all the configuration described above), stopping for an external debugger to connect. 

For eclipse you will have to create a `Debug configuration` for a `Remote Java Application` with the following configuration:

``` text
Connect:
  Project: org.testeditor.web.dropwizard.persistence
  Connection Type: Standard (Socket Attach)
  Connection Properties:
    Host: localhost
    Port: 5005
    [x] Allow termination of remote VM
```

Starting this `Debug configuration` will then connect to the process started via gradle, allowing you to use the eclipse debugging to introspect the running program.


### docker section

Execute `../gradlew docker` within org.testeditor.web.xtext.persistence

``` shell
docker run -p 8080:8080 -e GIT_PRIVATE_KEY="$(cat ~/.ssh/id_github_rsa)" -e KNOWN_HOSTS_CONTENT="$(cat ~/.ssh/known_hosts)" -e TARGET_REPO=git@github.com:test-editor/language-examples.git -e BRANCH_NAME=feature/some test-editor/xtext &
docker run -p 9080:8080 -e GIT_PRIVATE_KEY="$(cat ~/.ssh/id_github_rsa)" -e KNOWN_HOSTS_CONTENT="$(cat ~/.ssh/known_hosts)" -e TARGET_REPO=git@github.com:test-editor/language-examples.git -e BRANCH_NAME=feature/some test-editor/persistence &
```

Given an appropriate compose file (see https://github.com/test-editor/test-editor-web), the frontend including the backends can be started via a single `docker-compose` command.
``` shell
GIT_PRIVATE_KEY="$(cat ~/.ssh/id_github_rsa)" KNOWN_HOSTS_CONTENT="$(cat ~/.ssh/known_hosts)" docker-compose up
```

