require "file_utils"
require "../exceptions"

module SailContainers::Infrastructure
  class LxcConfigEditor
    # We manage anything starting with these prefixes
    MANAGED_PREFIXES = [
      "lxc.net.",
      "lxc.cgroup2.memory.",
      "lxc.cgroup2.cpuset.",
      "lxc.start.auto",
      "lxc.uts.name",
    ]

    getter managed_config = {} of String => String
    getter custom_lines = [] of String

    def initialize(@path : String)
      parse_file if File.exists?(@path)
    end

    private def parse_file
      File.read_lines(@path).each do |line|
        stripped = line.strip
        next if stripped.empty? || stripped.starts_with?("#")

        if stripped.includes?("=")
          parts = stripped.split("=", 2)
          key, value = parts[0].strip, parts[1].strip

          if is_managed?(key)
            @managed_config[key] = value
          else
            @custom_lines << stripped
          end
        else
          @custom_lines << stripped
        end
      end
    end

    private def is_managed?(key : String) : Bool
      MANAGED_PREFIXES.any? { |prefix| key.starts_with?(prefix) }
    end

    def set(key : String, value : String)
      @managed_config[key] = value
    end

    def get(key : String) : String?
      @managed_config[key]?
    end

    def save!
      # Ensure directory exists before saving
      dir = File.dirname(@path)
      Dir.mkdir_p(dir) unless Dir.exists?(dir)

      File.open(@path, "w") do |file|
        file.puts "# =========================================="
        file.puts "# Managed by Sail Containers Engine"
        file.puts "# =========================================="
        @managed_config.each do |k, v|
          file.puts "#{k} = #{v}"
        end

        unless @custom_lines.empty?
          file.puts "\n# =========================================="
          file.puts "# Custom Directives (Preserved)"
          file.puts "# =========================================="
          @custom_lines.each { |line| file.puts line }
        end
      end
    end
  end
end
