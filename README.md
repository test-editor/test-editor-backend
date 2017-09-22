# Run

This repository contains two backend services. One for the persistence and one for the Xtext services.
Run them using Gradle:

```
./gradlew :org.testeditor.web.backend.persistence:run
./gradlew :org.testeditor.web.backend.xtext:run
```

# Status

* currently user `admin` is used as being *logged in*
* make sure that in folder `repo/admin` a file is placed that is expected by the frontend (e.g. `example.tsl`)

