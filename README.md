# Bridge

Bridge makes supported foreign targets behave as locally as practical from a Linux development host.

## Win32 prototype

Bridge's Win32 profile cross-compiles with LLVM-MinGW and executes target programs through Wine. A small POSIX `sh` runner keeps Wine's background processes detached from captured test output so CTest does not wait for Wine's idle shutdown after each executable. The toolchain first honors `BRIDGE_LLVM_MINGW_ROOT`, then the environment variable of the same name, then searches a target-prefixed LLVM-MinGW compiler already on `PATH` and `/opt/llvm-mingw`. Bridge also adds LLVM-MinGW's target runtime DLL directory to Wine's executable search path.

A project using Bridge can include `external/bridge/cmake/BridgePresets.json` from its `CMakePresets.json`. Bridge's preset file includes Canon's presets and adds `win32-debug`, `win32-release`, `win32-asan`, `win32-tidy`, and `win32-coverage` with matching build, test, and workflow presets.
Preset composition reads Canon from `external/canon` in the consuming source tree, so Bridge and the consumer use the same Canon preset policy.

If LLVM-MinGW is installed in a nonstandard location, set the root explicitly when configuring:

```bash
cmake --preset win32-debug -DBRIDGE_LLVM_MINGW_ROOT=/path/to/llvm-mingw
```

Machine-local paths do not need to be committed or added globally to `PATH`.

## Android prototype

Bridge's Android profiles use the NDK's supported CMake toolchain file and deploy headless executables through `adb`. The Android toolchain is intentionally limited to target establishment: NDK, ABI, minimum API, and the NDK toolchain itself. Use CMake's standard `CMAKE_ANDROID_NDK` variable as the explicit NDK override when automatic discovery is not sufficient.

SDK and runtime discovery happen separately after the Android target has been established. Bridge prefers `<sdk>/platform-tools/adb` from the discovered SDK over a same-named host executable, and host-program fallback searches do not use Android target roots. `BRIDGE_ANDROID_SDK_ROOT` is an escape hatch for a nonstandard SDK location; ordinary installations should not require `PATH` or IDE environment changes.

Bridge provides `android-x86_64-*` and `android-arm64-*` profiles for every Canon intent. The default Android platform is API 21 and can be overridden with `BRIDGE_ANDROID_PLATFORM`.

The Android runner selects exactly one online device that supports the target ABI. If multiple compatible devices are connected, set `BRIDGE_ANDROID_SERIAL` to the desired adb serial. The runner pushes each headless executable to `/data/local/tmp`, marks it executable, and runs it through `adb shell` while preserving target arguments, stdout, stderr, and exit status.

This first headless runner does not claim to mirror the host process environment or host working-directory contents onto Android. Tests that need environment variables or runtime files need an explicit deployment contract rather than an implicit host-filesystem assumption.

### SDL3 APK packaging

Bridge can package an existing SDL3 Android shared-library target as a development APK. The consuming project still owns its targets. On Android, SDL requires the application entry point to live in a shared library that is loaded as `libmain.so`; Bridge does not rewrite an executable target into that form.

```cmake
add_library(main SHARED main.cpp)
target_link_libraries(main PRIVATE SDL3::SDL3-shared)

include(external/bridge/cmake/BridgeAndroidPackaging.cmake)
bridge_add_sdl_android_application(
    ALL
    TARGET game_apk
    APPLICATION_ID com.example.game
    APPLICATION_NAME "Example Game"
    MAIN_TARGET main
    SDL_TARGET SDL3::SDL3-shared
    SDL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/external/sdl3"
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets"
)
```

`ASSET_DIRECTORY` copies the directory contents into the APK's `assets/` tree. `RUNTIME_TARGETS` can name additional shared-library targets that must ship beside `libmain.so` and `libSDL3.so`. Bridge rejects duplicate packaged targets and fails if two runtime libraries would overwrite the same staged library name. The packaging target exposes its APK path through the `BRIDGE_ANDROID_APK` target property.

The packaging path uses a build-local debug signing key. Production signing, store packaging, and multi-ABI distribution remain separate concerns.

### Android application runner

Bridge can attach a developer run target to a packaged Android application. The run target depends on the APK, selects a compatible online device when invoked, installs or updates the package, stops any previous instance, and launches its Android activity. Device selection follows the same rule as headless execution: if more than one compatible device is online, set `BRIDGE_ANDROID_SERIAL`.

```cmake
include(external/bridge/cmake/BridgeAndroidRun.cmake)
bridge_add_android_run_target(
    TARGET game_run
    APPLICATION_TARGET game_apk
)
```

Then build and launch with one command:

```sh
cmake --build --preset android-arm64-debug --target game_run
```

The run target is developer tooling, not a test. It may build its APK dependency before installing it. CTest continues to execute only artifacts that the normal build graph has already produced.
