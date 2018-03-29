# Run

This repository contains two backend services. One for the persistence and one for the Xtext services.
Run them using Gradle:

``` shell
./gradlew :org.testeditor.web.backend.persistence:run
./gradlew :org.testeditor.web.backend.xtext:run
```
alternatively, start both in parallel: `./gradlew run --parallel`

# Development

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
        testEditorDropwizard: '0.11.0',       // use locally built, not yet published version
        testEditorLanguage: '1.12.0-SNAPSHOT' // use locally built language version
    ]
    ext.localconfig = true // make sure to use config.local.yml as dropwizard configuration
}
```
2. config.local.yml (within `test-editor-backend/org.testeditor.web.backend.persistence`):
``` yaml
remoteRepoUrl: http://any.repo.of.your.choice
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

