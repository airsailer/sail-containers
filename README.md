# Sail Containers

**Sail Containers** is a highly efficient, opinionated System Container Engine and Node-Level Manager for LXC, built in Crystal.

It operates exclusively on a single host node and is responsible for the efficient execution of Linux containers, strict hardware resource tracking, and local network/storage setup. It serves as the foundational host-level engine for [Airsailer](https://github.com/airsailer/airsailer) (Cloud Orchestrator).

## Table of Contents
1. [Core Philosophy](#core-philosophy)
2. [Prerequisites](#prerequisites)
3. [Installation](#installation)
4. [Usage](#usage)
5. [Architecture](#architecture)
6. [Contributing](#contributing)
7. [License](#license)

## Core Philosophy

* **Strict Resource Management:** The engine maps and allocates hardware precisely. We prioritize performance predictability over over-provisioning.
* **Opinionated Simplicity:** We utilize built-in Linux primitives (cgroups v2, IPVLAN L3S, LVM thin pools) instead of heavy external overlays.
* **No Split-Brain:** Sail Containers does not use a secondary database (like SQLite) to track state. The filesystem (`/var/lib/lxc/*/config`) is the single source of truth, bootstrapped into memory on boot.
* **Library-First Design:** It is designed strictly as a modular Crystal library with a clean API, ready to be embedded into larger orchestrators.

## Prerequisites

* **OS:** Linux distribution with `cgroups v2` support (Ubuntu 22.04+, Debian 11+).
* **Dependencies:** `lxc` installed on the host node.
* **Crystal:** `1.20.0` or higher.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  sail_containers:
    github: airsailer/sail-containers
```

## Usage

Interaction with the engine is done entirely through the `SailContainers::Client` facade.

### Initialization

```crystal
require "sail_containers"

# 'local' uses directory-backed storage. 
# 'production' uses LVM thin-pools.
client = SailContainers::Client.new(env: "production")
```

### Creating and Managing Containers

```crystal
# Define the network topology (Multi-VLAN supported)
networks = [
  SailContainers::Models::Network.new(link: "sail0", ip: "10.0.0.50/24", l2proxy: true)
]

# Create a container with strict limits
client.create(
  name: "web-01",
  template: "ubuntu",
  release: "noble",
  cpus: 2,
  ram: "1G",
  disk: "10G",
  networks: networks,
  autostart: true
)

# Lifecycle management
client.stop("web-01")
client.start("web-01")
client.restart("web-01")

# Destruction
client.destroy("web-01")
```

### Inspection

```crystal
# Get information about a specific container
container = client.info("web-01")
puts container.state               # => "running"
puts container.networks.first.ip   # => "10.0.0.50/24"

# List all containers on the host
containers = client.list
containers.each do |c|
  puts "#{c.name} is currently #{c.state}"
end
```

## Architecture

Sail Containers strictly enforces a **Hexagonal (Ports and Adapters)** architecture:

* **Core (`/core`):** Pure domain logic (e.g., `ResourceManager`). Mathematical allocation of CPU pinning entirely isolated from the filesystem or host OS.
* **Infrastructure (`/infrastructure`):** Adapters for system execution (`LxcCliDriver`), file manipulation (`LxcConfigEditor`), and real-world state syncing (`StateBootstrapper`).
* **Hybrid Config Editor:** Orchestrated configurations (`lxc.net.*`, `lxc.cgroup2.*`) are managed dynamically, while unknown custom directives added by sysadmins are safely preserved at the bottom of the config files.

All system calls are protected against shell injection using Crystal's `Process.capture_result` with strict arrays, and all memory states are synchronized using `Sync::Mutex` for safe execution in Crystal's `preview_mt` multi-threaded contexts.

## Roadmap

Here is the proposed roadmap reflecting the single-node, opinionated scope of Sail Containers. You can place this in a `ROADMAP.md` or right into the `README.md`.

As features are completed, you simply change the ⬜ to ✅. 

#### Legend:
*   ✅ **Completed**
*   🚧 **In Progress**
*   ⬜ **Planned / To Do**

#### 🏗️ Architecture & Core Engine
*   ✅ **Hexagonal Architecture:** Strict boundary between Domain logic and Infrastructure calls.
*   ✅ **Memory-Mapped State:** Bootstrapping real-world state from filesystem upon initialization to prevent database split-brain.
*   ✅ **Shell Injection Prevention:** Execution restricted to Crystal `Process.capture_result` with strict arrays.
*   ✅ **Multi-Threading Safety:** Mutex-locked resource allocation mapped for Crystal `preview_mt` contexts.

#### 📦 Container Lifecycle & Templates
*   ✅ **Basic Lifecycle:** Start, Stop, Restart, Info, List, Destroy.
*   ✅ **Remote Provisioning:** Native fetching of `linuxcontainers.org` images via `lxc-create --template download`.
*   ✅ **Local Templating:** Copying/Cloning local offline containers via `lxc-copy`.
*   ⬜ **Architecture Detection:** Automatic detection of host CPU architecture (e.g., `amd64`, `arm64`) instead of hardcoded defaults.
*   ⬜ **Template Index Caching:** Built-in caching/syncing mechanism of the `index-system` meta API for rapid creation.
*   ⬜ **Snapshot Management:** Local volume snapshots and rollbacks using LVM native features.

#### ⚙️ Hardware Resource Management (Cgroups v2)
*   ✅ **CPU Allocation:** Strict mathematical core-pinning logic without over-provisioning (`lxc.cgroup2.cpuset.cpus`).
*   ✅ **Memory Limits:** Size-aware RAM string normalization and setting (`lxc.cgroup2.memory.max`).
*   ✅ **Swap Enforcement:** Opinionated default to zero-swap for predictable performance.
*   ⬜ **Disk I/O Throttling:** Read/Write MB/s limits and IOPS limiting.
*   ⬜ **Dynamic Resource Updates:** Update CPU/RAM constraints on a running container without requiring a restart.

#### 💾 Storage Management
*   ✅ **Environment Awareness:** `dir` backend for local/dev, LVM thin-pools for production workloads.
*   ✅ **Dynamic Volume Sizing:** Parsing sizes (M/G/T) into LXC `fssize` and `fstype ext4` parameters.
*   ⬜ **Online Expansion:** Native capability to safely resize/grow an ext4 thin volume while the container is running.
*   ⬜ **Offline Shrinking:** Safely unmount, shrink the filesystem, and resize the LVM volume while the container is stopped.

#### 🌐 Network Management
*   ✅ **L3S IPVLAN:** High-performance opinionated topology utilizing L3S routing and L2 Proxying.
*   ✅ **Hybrid Config Injection:** Safely writing `lxc.net.*` directives while preserving manual sysadmin overrides.
*   ✅ **Multiple Interface Support:** Permitting the engine to dynamically configure multiple VLAN interfaces (`lxc.net.0`, `lxc.net.1`) based on Orchestrator demands.
*   ⬜ **Network Rate Limiting:** Ingress/Egress bandwidth limitations natively applied to the container's virtual interfaces.

#### 📊 Telemetry & Observability
*   ⬜ **Live Resource Stats:** Wrapping `lxc-info` or reading `cgroups` directly to expose real-time CPU, RAM, and Network usage.
*   ⬜ **Host Node Capacity API:** Exposing available (unallocated) hardware resources to the Orchestrator for intelligent scheduling.

## Contributing

1. Fork it (<https://github.com/airsailer/sail-containers/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'feat/fix/refactor/test: description'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Open a new Pull Request

## License

MIT
