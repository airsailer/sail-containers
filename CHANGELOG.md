# Sail Containers changelog

## 0.2.0 - 2026-06-10

### Added
* **models:** `SailContainers::Models::Network` struct to support configuring multiple interfaces per container. Supports explicit `l2proxy` toggling.
* **infrastructure:** Toggleable `debug` mode in `LxcCliDriver`. When enabled, it automatically executes LXC with `TRACE` logging and writes the output directly into the container's directory (`/var/lib/lxc/<name>/trace.log`). Traces are automatically appended to Crystal exceptions on failure.
* **ci:** Complete End-to-End (E2E) GitHub Actions pipeline (`e2e.yml`) that runs real LXC operations and LVM loop-device provisioning. Securely gated behind the `run-e2e` PR label.

### Changed
* **client:** The `create` method now accepts an array of `Network` objects instead of a single IP, enabling multi-VLAN L3S support.
* **client:** Replaced `ram_mb` and `disk_gb` with dynamic `ram` and `disk` string arguments. Built-in normalizers now securely parse standard units (`K`, `M`, `G`, `T`, `P`).
* **client:** Remote template creation now strictly requires a `release` argument (e.g., `noble`).
* **client:** Added `local_template` boolean to `create` to cleanly branch between remote `linuxcontainers.org` downloads (`lxc-create`) and local offline container cloning (`lxc-copy`).
* **infrastructure:** `LxcConfigEditor` now supports wiping specific configuration prefixes (`clear_prefix`) to cleanly re-sync dynamically orchestrated network directives without leaving ghost interfaces.
* **safety:** Removed `.not_nil!` usages across the codebase in favor of safe nil-coalescing and strict Domain Exceptions.

### Fixed
* **infrastructure:** Gracefully trapped OS-level `File::NotFoundError` exceptions in `LxcCliDriver` (e.g., when the LXC binary isn't installed) and mapped them strictly to `SystemExecutionError` to protect the Hexagonal Architecture boundary.
* **networking:** Made `l2proxy` toggleable on a per-network basis to provide a clean workaround for the `EEXIST` routing collision bug present in Linux Kernel 6.8 / LXC 5.x on Ubuntu 24.04.

## 0.1.0 - 2026-06-05

### Added
* **client:** The main `SailContainers::Client` facade exposing the engine's primary API (`create`, `destroy`, `start`, `stop`, `restart`, `info`, `list`).
* **core:** Thread-safe `ResourceManager` utilizing Crystal 1.20 `Sync::Mutex` to allocate and track CPU core pinning in memory.
* **infrastructure:** `LxcConfigEditor` to orchestrate LXC configuration files. It specifically parses, manages, and updates orchestrated directives (`lxc.net.*`, `lxc.cgroup2.*`) while safely preserving any custom directives added manually by sysadmins.
* **infrastructure:** `StateBootstrapper` that reads reality directly from the filesystem upon initialization, effectively mapping allocated resources back into memory to strictly avoid "split-brain" database inconsistencies.
* **infrastructure:** `LxcCliDriver` adapter that executes system binaries using safely isolated `Process.capture_result` arrays, completely eliminating shell injection vulnerabilities.
* **models:** Introduction of the `Container` DTO for clean, serializable data transport.

### Architecture
* **design:** Strict Hexagonal (Ports and Adapters) architecture boundary. Domain logic has zero knowledge of the filesystem or external CLI tools.
* **safety:** Complete adherence to Crystal 1.20 Execution Contexts. Safe for highly concurrent, multi-threaded production environments.
* **storage:** Native environment-aware branching. Uses `dir` storage for local development, and enforces `lvm` thin pools for production workflows.

### Quality
* **tests:** 100% code coverage.
* **ci:** Complete GitHub Actions pipeline executing specs across both single-threaded and `-Dpreview_mt` multi-threaded Crystal execution contexts.

---

### Reboot

2026-06-05

Source code completely restarted to change from a working proof-of-concept to a more organized codebase.
Name also changed from Admira Containers to Sail Containers (to be used at Airsailer Cloud Platform).
CLI is expected to be created at the Airsailer Cloud Platform, for a higher level of usage and features. Sail Containers is responsible for managing LXC system containers in a single host without being concerned about cloud computing responsibilities, like projects, tenants, etc.

---

# Admira Containers - admiractl changelog

## 0.12.0 - 2024-07-14

* Added "--autostart" as a possible option to manage by the "set" command
* Added "--ip" as a possible option to manage by the "set" command (probably will be replaced by "ip4 add/remove") in future releases

## 0.11.0 - 2023-08-31

* Command "list" now provides resource usage stats for running containers

## 0.10.0 - 2023-08-31

* Added "--swap" as a possible resource to manage by the "set" command

## 0.9.0 - 2023-08-30

* Fully working "set" command for cpus

## 0.8.0 - 2023-08-26

* Improved "create" command with "--template" option
* Concluded persistency of hardware resource changes

## 0.7.0 - 2023-08-20

* Added "template [list]" command
* Added config folder creation
* Added caching for template list

## 0.6.0 - 2023-08-18

* Fully working "set" command for ram
* Fixed "enter" command output from the subshell

## 0.5.0 - 2023-08-12

* Added basic "set" command for cpus, ram, and hostname
* Added auto-completion to the cli

## 0.4.0 - 2023-08-10

* Added enter command
* Added verification of container status before start, stop and restart actions

## 0.3.0 - 2023-08-09

* Added delete, start, stop and restart commands
* cgroups v2 verification on runtime and information on readme

## 0.2.0 - 2023-08-08

* Added the basic list command - missing the version with resource usage stats

## 0.1.0 - 2023-08-07

* Added the create command - missing template flag
* Added the base for the cli project organization for modules, libraries and their directories
