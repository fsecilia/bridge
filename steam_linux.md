# Steam Linux Runtime 4 SDK builds

Bridge builds Steam Linux applications inside Valve's [Steam Linux Runtime 4 SDK](https://gitlab.steamos.cloud/steamrt/steamrt4/sdk). The SDK supplies the compiler, system libraries, and SDL version that a Steam build uses. The `steam-gcc-debug` and `steam-gcc-release` CMake presets select SDK-installed SDL and omit SDL and host desktop-integration files from the installed game. Runtime window icons remain under `bin/icons/`. They do not launch a container themselves.

This guide covers Arch Linux and Arch-based development hosts. The [Steam Runtime documentation](https://github.com/ValveSoftware/steam-runtime#building-in-the-runtime) recommends building inside an SDK container to avoid accidentally depending on libraries from the host distribution.

## Prepare an Arch host

Install rootless Podman and, if you want a persistent interactive container, Distrobox:

```sh
sudo pacman -Syu --needed podman distrobox
podman info
```

Run `podman` as your normal user, **without `sudo`**. If rootless Podman fails, check your user's entries in `/etc/subuid` and `/etc/subgid` and the kernel's unprivileged user-namespace setting. See the [ArchWiki Podman rootless setup](https://wiki.archlinux.org/title/Podman#Rootless_Podman). Fix rootless Podman before using Bridge's launcher; do not work around the problem by running the SDK as root.

Choose an official SDK OCI image and pin it by its full SHA-256 digest. A floating tag is deliberately rejected by Bridge's runner. The value below is a template, not a valid digest:

```sh
export BRIDGE_STEAMRT4_SDK_IMAGE='registry.gitlab.steamos.cloud/steamrt/steamrt4/sdk@sha256:<verified-digest>'
```

Keep the actual value in your user shell configuration or set it before each build. The SLR4 **SDK image** is required; the SteamLinuxRuntime_4 installation used to run games is not a replacement for the SDK.

## Disposable Podman shell (default)

From the *consumer application's* source root (for example, Tinderbox), enter the SDK through Bridge's launcher:

```sh
./external/bridge/runner/bridge-steamrt4.sh
```

Run standard CMake commands in that shell:

```sh
cmake --preset steam-gcc-debug
cmake --build --preset steam-gcc-debug
ctest --preset steam-gcc-debug --output-on-failure
```

Release builds use `steam-gcc-release` in the same commands. For a single invocation from the host, forward a command instead of opening a shell:

```sh
./external/bridge/runner/bridge-steamrt4.sh cmake --workflow --preset steam-gcc-release
```

The launcher is a thin wrapper around `runner/bridge-steamrt4-sdk.sh`: it obtains the pinned image from `BRIDGE_STEAMRT4_SDK_IMAGE`, selects the current directory as the workspace, and forwards commands and exit codes to Podman. The lower-level script also accepts explicit `--image`, `--workspace`, and `--dependency-prefix` arguments. `BRIDGE_PODMAN_EXECUTABLE` can override the Podman executable.

The container is deleted when the shell exits (`podman run --rm`), but source files and CMake build trees persist because the workspace is mounted from the host. Bridge puts ccache and graphics caches in `build/.cache/steamrt4/`, not in the source root's `.cache/`; that build-local directory persists between SDK sessions. Interactive shells disable persistent Bash and `less` history files. If an older runner left `.cache/` in the source root, you can remove it after exiting the SDK; Git's ignore rules do not exclude it from tar archives. The runner uses your host UID/GID, which does **not** give you a root password or working `sudo` inside the container. Do not try `sudo apt install` in this disposable shell: it is not a persistent way to install SDK dependencies.

An optional `BRIDGE_STEAMRT4_PREFIX` points to a private prefix of dependencies built **inside this SDK**, outside the project source and build trees. The launcher mounts the prefix and sets `CMAKE_PREFIX_PATH`. Never reuse host-built libraries in an SDK prefix. A missing required dependency must produce a visible configure error, not silently resolve from the host.

## Persistent Distrobox shell (optional)

[Distrobox](https://distrobox.it/) offers an alternative when you need to install Debian packages inside the SDK and keep those changes between sessions. It uses Podman under the hood, integrates your normal user account, and initializes the container with tools such as `sudo`. Create a separate environment from the *same pinned official SDK image*:

```sh
distrobox create --name bridge-steamrt4 --image "$BRIDGE_STEAMRT4_SDK_IMAGE"
distrobox enter bridge-steamrt4
```

Within Distrobox, use the same `cmake --preset`, `cmake --build --preset`, and `ctest --preset` commands. The container remains available after `exit`. If the container needs additional SDK development packages, install them there with `sudo apt update` and `sudo apt install <package>`; this changes only the persistent container, not your Arch host. You can also have Distrobox install them during initial setup using `distrobox create --additional-packages 'package-one package-two'`. Distrobox initialization of the official SLR4 image is an **optional path that still needs validation on the development machine**; Bridge's tested integration is the direct Podman runner.

A persistent Distrobox and the disposable runner do not necessarily expose the same installed packages. Choose one environment for a given Steam build tree, or clear the tree before switching, so the CMake cache never mixes different dependency sets.

## SDK identity, dependencies, and validation

Bridge's `toolchains/bridge-steamrt4.cmake` runs during CMake configuration and checks `/etc/os-release` for `ID=steamrt`, `VERSION_ID=4`, and `VARIANT=SDK`. The toolchain does **not** set a cross-compilation target, change the compiler, or launch Podman: Steam Linux is still a native Linux target inside the SDK. It also sets `BRIDGE_STEAMRT4_SDK` for consumers that need to distinguish SDK builds when choosing development-only targets.

The guard rejects configuration on the Arch host or in a runtime-only image. It does **not** intercept direct host execution of Ninja against an already configured Steam build directory. Remove any `build/steam-gcc-*` trees previously configured against the host before configuring them inside the SDK, and keep those trees SDK-owned afterward.

The SDK-provided SDL 3.4.18 is sufficient for consumers requiring SDL 3.2.x APIs within major version 3. Additional project dependencies are the consumer's responsibility. For example, Tinderbox normally disables its asset-generation programs for Steam, so `libpng-dev` and `libjson-c-dev` are **not** required for a standard Steam build; opting those programs back in requires both packages in the SDK environment.

An SDK configure/build/test pass establishes a build against the SDK, not native Steam client behavior, depot staging, or publication. Runtime testing under Steam Linux Runtime 4 and Steamworks integration remain separate validation steps.

## Distribution collection from the host

Consumers can register an SLR4 Release workflow as a producer through `bridge_add_distribution_collection(WORKFLOW_BUILD_TREES ...)` and collect its manifest alongside Windows distributions. The launcher executes configure, build, and CTest inside the SDK, then builds the producer's packaging target there. The ordinary native coordinator runs only on the host; the Steam producer must not recursively register that coordinator in its SDK build. See `cmake/BridgeDistribution.cmake` for the workflow entry format and the [distribution guide](README.md#distribution-targets-and-collection) for the manifest and validator contract.

The package may be built in a disposable SDK container even though the build directory and caches persist on the host's bind-mounted source tree. Running the installed Release game under the separate Steam Linux Runtime 4 remains the consumer's runtime acceptance check, not a step implicitly performed by the build workflow.
