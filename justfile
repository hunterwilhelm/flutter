set shell := ["/bin/sh", "-eu", "-c"]

root := justfile_directory()
engine_src := root + "/engine/src/flutter"
android_out := root + "/engine/src/out/android_debug_unopt_arm64"
host_out := root + "/engine/src/out/host_debug_unopt_arm64"
hardware_android := root + "/dev/integration_tests/android_hardware_smoke_test/android"
debug_app := "/Users/hunterwilhelm/dev/flutter_temp_debug"
device := "R3CW201GVQY"

# Fetch the engine dependencies using the documented shallow-sync fallback.
engine-sync:
    /Users/hunterwilhelm/depot_tools/gclient sync -D --no-history

# Rebuild flutter_embedding_debug.jar and the ARM64 Android engine artifacts.
build-android-jar:
    cd {{engine_src}} && PATH=/Users/hunterwilhelm/depot_tools:$PATH ./bin/et build --config android_debug_unopt_arm64 //flutter/shell/platform/android:android_jar

# Build the local macOS host engine once; Flutter needs it for local-engine builds.
build-host-engine:
    cd {{engine_src}} && PATH=/Users/hunterwilhelm/depot_tools:$PATH ./bin/et build --config host_debug_unopt_arm64

# Run the IME resume regression test against the rebuilt local ARM64 engine.
test-local:
    #!/usr/bin/env bash
    set -euo pipefail

    repo_dir="$(mktemp -d /private/tmp/flutter-local-engine-repo.XXXXXX)"
    version_id="$(sed -n 's:.*<version>\(.*\)</version>.*:\1:p' {{android_out}}/flutter_embedding_debug.pom | head -1)"

    for artifact in flutter_embedding_debug arm64_v8a_debug; do
      artifact_dir="$repo_dir/io/flutter/$artifact/$version_id"
      mkdir -p "$artifact_dir"
      ln -s {{android_out}}/$artifact.maven-metadata.xml "$repo_dir/io/flutter/$artifact/maven-metadata.xml"
      ln -s {{android_out}}/$artifact.pom "$artifact_dir/$artifact-$version_id.pom"
      ln -s {{android_out}}/$artifact.jar "$artifact_dir/$artifact-$version_id.jar"
    done

    cd {{hardware_android}}
    ANDROID_SERIAL={{device}} ./gradlew :app:connectedDebugAndroidTest \
      -Plocal-engine-repo="$repo_dir" \
      -Plocal-engine-build-mode=debug \
      -Plocal-engine-out={{android_out}} \
      -Plocal-engine-host-out={{host_out}} \
      -Ptarget-platform=android-arm64 \
      -Pandroid.testInstrumentationRunnerArguments.class=com.example.android_hardware_smoke_test.FlutterActivityTest#imeRemainsVisibleAfterActivityResume

# Launch the manual debug app with FVM and the rebuilt local engine.
run-debug-app:
    cd {{debug_app}} && fvm flutter run -d {{device}} --local-engine=android_debug_unopt_arm64 --local-engine-src-path={{root}}/engine/src --local-engine-host=host_debug_unopt_arm64
