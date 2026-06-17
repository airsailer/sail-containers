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

    def create(
      name : String,
      template : String,
      release : String? = nil,
      local_template : Bool = false,
      cpus : Int32 = 1,
      ram : String | Int32 = "512M",
      disk : String | Int32 = "10G",
      networks : Array(Models::Network) = [] of Models::Network,
      autostart : Bool = true,
    ) : Nil
      if !local_template && !release
        raise Exceptions::ConfigurationError.new("A 'release' must be specified when using a remote template.")
      end

      normalized_ram = normalize_ram(ram)
      normalized_disk = normalize_disk(disk)

      pinned_cpus = @resources.allocate_cpus!(name, cpus)

      begin
        storage_args = resolve_storage_args(normalized_disk)
        @driver.create(name, template, release, local_template, storage_args)

        config_path = File.join(@lxc_base_path, name, "config")
        inject_orchestrated_config!(config_path, name, pinned_cpus, normalized_ram, networks, autostart)

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

    def info(name : String) : Models::Container
      ensure_exists!(name)

      config_path = File.join(@lxc_base_path, name, "config")
      editor = Infrastructure::LxcConfigEditor.new(config_path)
      is_running = @driver.running?(name)

      # Extract all dynamically generated networks
      parsed_networks = [] of Models::Network
      editor.managed_config.keys.select { |k| k.matches?(/^lxc\.net\.\d+\.link$/) }.each do |key|
        index = key.split(".")[2] # Extract the "N" from "lxc.net.N.link"
        link = editor.get(key) || ""
        ip = editor.get("lxc.net.#{index}.ipv4.address") || ""
        parsed_networks << Models::Network.new(link: link, ip: ip)
      end

      Models::Container.new(
        name: name,
        state: is_running ? "running" : "stopped",
        networks: parsed_networks,
        cpus: editor.get("lxc.cgroup2.cpuset.cpus"),
        ram: editor.get("lxc.cgroup2.memory.max")
      )
    end

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

    private def inject_orchestrated_config!(path : String, name : String, cpus : String, ram : String, networks : Array(Models::Network), autostart : Bool) : Nil
      config = Infrastructure::LxcConfigEditor.new(path)

      config.set("lxc.uts.name", name)
      config.set("lxc.cgroup2.cpuset.cpus", cpus)
      config.set("lxc.cgroup2.memory.max", ram)
      config.set("lxc.cgroup2.memory.swap.max", "0")
      config.set("lxc.start.auto", autostart ? "1" : "0")

      # Wipe previous orchestrated network settings
      config.clear_prefix("lxc.net.")

      # Inject multi-vlan configurations
      networks.each_with_index do |net, index|
        prefix = "lxc.net.#{index}"
        config.set("#{prefix}.type", "ipvlan")
        config.set("#{prefix}.ipvlan.mode", "l3s")
        config.set("#{prefix}.link", net.link)
        config.set("#{prefix}.flags", "up")
        config.set("#{prefix}.ipv4.address", net.ip)
        config.set("#{prefix}.ipv4.gateway", "dev")

        # Write 1 or 0 based on the model's explicit parameter
        config.set("#{prefix}.l2proxy", net.l2proxy ? "1" : "0")
      end

      config.save!
    end

    private def resolve_storage_args(disk : String) : Array(String)
      if @env == "production"
        ["-B", "lvm", "--vgname", "vg0", "--thinpool", "airsailer", "--fstype", "ext4", "--fssize", disk]
      else
        ["-B", "dir"]
      end
    end

    private def normalize_size(value : String | Int32, default_unit : String, allowed_units : Array(Char)) : String
      str_val = value.to_s.strip.upcase
      return "#{str_val}#{default_unit}" if str_val.matches?(/^\d+$/)

      match = str_val.match(/^(\d+)([A-Z])$/)
      if match && allowed_units.includes?(match[2][0])
        return str_val
      end

      raise Exceptions::ConfigurationError.new("Invalid size format: '#{value}'")
    end

    private def normalize_ram(ram : String | Int32) : String
      normalize_size(ram, "M", ['K', 'M', 'G', 'T'])
    end

    private def normalize_disk(disk : String | Int32) : String
      normalize_size(disk, "G", ['M', 'G', 'T', 'P'])
    end
  end
end
