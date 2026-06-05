# Sail Containers changelog

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
