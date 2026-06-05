require "./lxc_config_editor"

module SailContainers::Infrastructure
  class StateBootstrapper
    def self.load_cpu_allocations(base_path : String) : Hash(String, String)
      allocations = {} of String => String

      # Look for all config files in /var/lib/lxc/*/config
      search_pattern = File.join(base_path, "*", "config")

      Dir.glob(search_pattern).each do |config_path|
        # Extract container name from the path: e.g. /var/lib/lxc/web-01/config -> web-01
        parts = config_path.split(File::SEPARATOR)
        next if parts.size < 2

        container_name = parts[-2]

        editor = LxcConfigEditor.new(config_path)
        if cpus = editor.get("lxc.cgroup2.cpuset.cpus")
          allocations[container_name] = cpus
        end
      end

      allocations
    end
  end
end
