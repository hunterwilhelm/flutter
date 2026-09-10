# Android IME visibility after app resume (#52599)

## What was happening

When a Flutter Android app with a focused `TextField` was backgrounded and then
resumed, Android dismissed the IME. `FlutterView` could still report that it
had focus when it became visible again, so simply calling `requestFocus()` was
a no-op and Android never recreated the input connection.

The fix records whether the IME was visible when the window first loses focus.
On restore, only when a framework text-input client remains active and the IME
was previously visible, `FlutterView` restarts Android focus with
`clearFocus()` followed by `requestFocus()`. This preserves an explicitly
hidden keyboard: it is not reopened after resume.

## Tests

`imeRemainsVisibleAfterActivityResume` is a physical-device instrumentation
test in `dev/integration_tests/android_hardware_smoke_test`. It renders an
autofocused Flutter `TextField`, waits for the IME, launches an opaque Android
activity, finishes that activity, and asserts that the IME remains visible when
the Flutter activity regains window focus.

The normal Gradle command uses the SDK's prebuilt embedding. It is useful for
demonstrating the regression, but cannot validate unshipped Java source
changes. To validate a local `FlutterView.java` edit, rebuild the Android JAR
and run Gradle against the local engine Maven repository. The `just` recipes
below do that setup automatically.

## Prerequisites

* `depot_tools` installed at `/Users/hunterwilhelm/depot_tools`.
* Engine dependencies synced. `just engine-sync` uses the documented shallow
  fallback, `gclient sync -D --no-history`.
* Xcode's Metal Toolchain installed for the local host engine:
  `xcodebuild -downloadComponent MetalToolchain`.
* A connected Android device. Set `device` when invoking a recipe if its serial
  differs from the default.

## Common commands

```sh
just engine-sync
just build-android-jar
just build-host-engine
just test-local
just run-debug-app
```

`test-local` creates an ephemeral Maven-layout repository under `/private/tmp`
that symlinks the locally built embedding and ARM64 engine JARs. It then runs
the focused instrumentation test only. `run-debug-app` launches
`/Users/hunterwilhelm/dev/flutter_temp_debug` through FVM with the same local
engine outputs, so a manual app-switch check uses the actual modified JAR.

## Red/green workflow for an embedding change

After changing Android embedding source such as `FlutterView.java`, run:

```sh
just build-android-jar
just test-local
```

The test must pass with the changed JAR. To demonstrate that it actually
catches the regression, temporarily revert or stash the candidate fix, rebuild
the Android JAR, and run `just test-local` again: it should fail. Restore the
fix, rebuild the JAR once more, and rerun `just test-local`: it should pass.

Rebuilding is essential. Gradle otherwise can reuse an APK that already
contains a previous local engine JAR, making a source-only revert appear to
pass.

To run the regression against only the normal prebuilt embedding instead:

```sh
cd dev/integration_tests/android_hardware_smoke_test/android
./gradlew :app:connectedDebugAndroidTest \
  -Pandroid.testInstrumentationRunnerArguments.class=com.example.android_hardware_smoke_test.FlutterActivityTest#imeRemainsVisibleAfterActivityResume
```
