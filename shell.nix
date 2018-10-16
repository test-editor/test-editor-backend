with import <nixpkgs> {};

stdenv.mkDerivation {
    name = "test-editor-xtext-gradle";
    buildInputs = [
        jdk10
        travis
    ];
    shellHook = ''
        # do some gradle "finetuning"
        alias g="./gradlew"
        alias g.="../gradlew"
        export GRADLE_OPTS="$GRADLE_OPTS -Dorg.gradle.daemon=false -Dfile.encoding=utf-8"
        # in case of any local java installations
        export JAVA_HOME=$(readlink $(dirname $(which java)))/..
    '';
}
