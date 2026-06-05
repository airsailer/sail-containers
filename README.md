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
# Create a container with strict limits (2 CPUs, 1024MB RAM, 10GB Disk)
client.create(
  name: "web-01",
  template: "ubuntu",
  cpus: 2,
  ram_mb: 1024,
  disk_gb: 10,
  ip: "10.0.0.50",
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
puts container.state      # => "running"
puts container.ip_address # => "10.0.0.50"

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

## Contributing

1. Fork it (<https://github.com/airsailer/sail-containers/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

This project is licensed under the MIT License.
