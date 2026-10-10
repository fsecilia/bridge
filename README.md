# Bridge

Bridge makes supported foreign targets behave as locally as practical from a Linux development host.

## Win32 prototype

Bridge's Win32 profile cross-compiles with LLVM-MinGW and executes target programs through Wine. A small POSIX `sh` runner keeps Wine's background processes detached from captured test output so CTest does not wait for Wine's idle shutdown after each executable. The toolchain first honors `BRIDGE_LLVM_MINGW_ROOT`, then the environment variable of the same name, then searches a target-prefixed LLVM-MinGW compiler already on `PATH` and `/opt/llvm-mingw`. Bridge also adds LLVM-MinGW's target runtime DLL directory to Wine's executable search path.

On Wayland hosts, the Wine runner checks `WAYLAND_DISPLAY` and its Unix socket. When the socket exists, Bridge unsets `DISPLAY` for all Wine child processes, including startup, so Wine can use its native Wayland driver. On X11-only hosts, `DISPLAY` is preserved. If Wayland is advertised but its socket is unavailable, Bridge reports the problem and keeps X11 when available. Once Wayland is selected, a Wine failure is reported without silently retrying X11. Bridge does not modify the Wine registry or the calling shell's environment.

A project using Bridge can include `external/bridge/cmake/BridgePresets.json` from its `CMakePresets.json`. Bridge's preset file includes Canon's presets and adds `win32-debug`, `win32-release`, `win32-asan`, `win32-tidy`, and `win32-coverage` with matching build, test, and workflow presets.
Preset composition reads Canon from `external/canon` in the consuming source tree, so Bridge and the consumer use the same Canon preset policy.

Bridge also exposes a consumer-facing Win32 run target, parallel to its Android
application run target. The run target depends on the consumer's executable,
invokes the same Wine runner used by Bridge tests, and preserves Wine's display
selection and LLVM-MinGW runtime configuration. Cross-compilation still works
without Wine installed; invoking the run target then fails explicitly.

```cmake
include(external/bridge/cmake/BridgeWin32Run.cmake)
bridge_add_win32_run_target(
    TARGET game_run
    APPLICATION_TARGET game_exe
)
```

Build and run with one command:

```sh
cmake --build --preset win32-debug --target game_run
```

The target is intended for IDE and developer workflows, not for CTest. CMake
Tools does not treat CMake custom build targets as debugger launch targets;
IDEs can invoke the build target through their task integration.

Windows executables also need their DLL dependencies in the build tree. Bridge
provides a separate staging API that copies CMake-managed runtime DLLs and,
for recognized llvm-mingw C++ compilers, `libc++.dll` and `libunwind.dll` next
to the executable after it links:

```cmake
include(external/bridge/cmake/BridgeWin32Runtime.cmake)
bridge_stage_win32_runtime(TARGET game_exe)
```

Call this from the CMake directory that defines `game_exe`, after creating the
executable. The helper requires a Windows target and does not require Wine.
For llvm-mingw it fails configuration if a required compiler DLL is missing.
It covers build-tree execution, not a release package or arbitrary DLLs loaded
at runtime outside the CMake dependency graph.

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

### Application icons and Linux desktop integration

Bridge accepts consumer-rendered PNGs. It does not render or resample icon
artwork. An icon directory contains the complete icons `icon-<size>.png` at
16, 24, 32, 48, 64, 72, 96, 128, 144, 192, 256, and 512 pixels, plus
`foreground-<size>.png` and `monochrome-<size>.png` at 108, 162, 216, 324,
and 432 pixels. Every file must be a square, non-interlaced, 8-bit RGB or
RGBA PNG with the specified dimensions. Bridge validates all 22 files at configuration time and revalidates when
generating Windows or Android resources. These packaging helpers require a
host Python 3 interpreter only when icon support is requested.

For Android, add the following arguments to `bridge_add_sdl_android_application`:

```cmake
ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
ADAPTIVE_ICON_BACKGROUND_COLOR "#070508"
```

Bridge places the complete icons in density-specific launcher resources,
creates the adaptive foreground and monochrome layers, supplies the solid
background color, and compiles the resources with AAPT2. The manifest points
to `@mipmap/ic_launcher`. Existing consumers can omit both icon arguments;
that preserves their previous behavior without an application icon. Supplying
only one of these two arguments is an error.

For a Windows executable, use:

```cmake
include(external/bridge/cmake/BridgeApplicationIcons.cmake)
bridge_add_win32_application_icon(
    TARGET game_exe
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

Bridge assembles the provided PNGs into a multi-resolution ICO and compiles a
Windows icon resource into the executable. The consumer retains ownership of
the executable target. The Bridge Win32 toolchain provides a resource compiler.

For Linux desktop installation, use:

```cmake
include(external/bridge/cmake/BridgeApplicationIcons.cmake)
bridge_install_linux_desktop_application(
    TARGET game_exe
    APPLICATION_ID com.example.game
    APPLICATION_NAME "Example Game"
    CATEGORIES Game
    ASSET_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/runtime"
    RUNTIME_TARGETS game_runtime SDL3::SDL3
    ICON_DIRECTORY "${CMAKE_SOURCE_DIR}/assets/icons"
)
```

This installs the executable, its explicit shared runtime targets, the
optional runtime assets beside the executable, `com.example.game.desktop`
under `share/applications`, and the desktop icons under `share/icons/hicolor`.
The executable and its packaged shared libraries receive install RPATHs
relative to the installation prefix. System libraries remain provided by the
host system; this is not a fully self-contained application bundle.
`CATEGORIES`, `ASSET_DIRECTORY`, and `RUNTIME_TARGETS` are optional. The application should use the same identifier
for its window system metadata so Wayland can associate its window with the
installed desktop entry. `SDL_SetWindowIcon()` remains the consumer's
responsibility and is independent of these install resources.
