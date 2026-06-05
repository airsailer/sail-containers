require "./exceptions"
require "./core/resource_manager"
require "./infrastructure/lxc_driver"
require "./infrastructure/lxc_config_editor"
require "./infrastructure/state_bootstrapper"
require "./models/container"

module SailContainers
  class Client
    @driver : Infrastructure::LxcDriver
    @resources : Core::ResourceManager

    getter env : String
    getter lxc_base_path : String

    def initialize(
      @env : String = "local",
      driver : Infrastructure::LxcDriver? = nil,
      resources : Core::ResourceManager? = nil,
      @lxc_base_path : String = "/var/lib/lxc",
    )
      @driver = driver || Infrastructure::LxcCliDriver.new

      if resources
        @resources = resources
      else
        initial_state = Infrastructure::StateBootstrapper.load_cpu_allocations(@lxc_base_path)
        @resources = Core::ResourceManager.new(initial_allocations: initial_state)
      end
    end

    # --- Lifecycle Methods ---

    def start(name : String) : Nil
      ensure_exists!(name)
      @driver.start(name)
    end

    def stop(name : String) : Nil
      ensure_exists!(name)
      @driver.stop(name)
    end

    def restart(name : String) : Nil
      stop(name)
      start(name)
    end

    # --- Creation & Destruction ---

    def create(name : String, template : String, cpus : Int32, ram_mb : Int32, disk_gb : Int32, ip : String, autostart : Bool = true) : Nil
      pinned_cpus = @resources.allocate_cpus!(name, cpus)

      begin
        storage_args = resolve_storage_args(disk_gb)
        @driver.create(name, template, storage_args)

        config_path = File.join(@lxc_base_path, name, "config")
        inject_orchestrated_config!(config_path, name, pinned_cpus, ram_mb, ip, autostart)

        @driver.start(name) if autostart
      rescue ex : Exception
        @resources.release_cpus!(name)
        raise ex
      end
    end

    def destroy(name : String) : Nil
      ensure_exists!(name)
      @driver.destroy(name)
      @resources.release_cpus!(name)
    end

    # --- Inspection Methods ---

    # Retrieves real-time data about a specific container
    def info(name : String) : Models::Container
      ensure_exists!(name)

      config_path = File.join(@lxc_base_path, name, "config")
      editor = Infrastructure::LxcConfigEditor.new(config_path)
      is_running = @driver.running?(name)

      Models::Container.new(
        name: name,
        state: is_running ? "running" : "stopped",
        ip_address: editor.get("lxc.net.0.ipv4.address"),
        cpus: editor.get("lxc.cgroup2.cpuset.cpus"),
        ram: editor.get("lxc.cgroup2.memory.max")
      )
    end

    # Retrieves info for all containers managed by this engine
    def list : Array(Models::Container)
      search_pattern = File.join(@lxc_base_path, "*", "config")

      Dir.glob(search_pattern).map do |config_path|
        parts = config_path.split(File::SEPARATOR)
        name = parts[-2]
        info(name)
      end
    end

    # --- Private Helpers ---

    private def ensure_exists!(name : String) : Nil
      config_path = File.join(@lxc_base_path, name, "config")
      unless File.exists?(config_path)
        raise Exceptions::ContainerNotFoundError.new("Container '#{name}' does not exist")
      end
    end

    private def inject_orchestrated_config!(path : String, name : String, cpus : String, ram_mb : Int32, ip : String, autostart : Bool) : Nil
      config = Infrastructure::LxcConfigEditor.new(path)

      config.set("lxc.uts.name", name)
      config.set("lxc.cgroup2.cpuset.cpus", cpus)
      config.set("lxc.cgroup2.memory.max", "#{ram_mb}M")
      config.set("lxc.cgroup2.memory.swap.max", "0")
      config.set("lxc.start.auto", autostart ? "1" : "0")
      config.set("lxc.net.0.type", "ipvlan")
      config.set("lxc.net.0.ipvlan.mode", "l3s")
      config.set("lxc.net.0.l2proxy", "1")
      config.set("lxc.net.0.ipv4.address", ip)

      config.save!
    end

    private def resolve_storage_args(disk_gb : Int32) : Array(String)
      if @env == "production"
        ["-B", "lvm", "--vgname", "vg0", "--thinpool", "airsailer", "--fssize", "#{disk_gb}G"]
      else
        ["-B", "dir"]
      end
    end
  end
end
