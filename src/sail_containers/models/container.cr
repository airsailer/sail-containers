module SailContainers::Models
  # Represents the current state and configuration of a container on the host.
  struct Container
    getter name : String
    getter state : String # "running" or "stopped"
    getter ip_address : String?
    getter cpus : String?
    getter ram : String?

    def initialize(@name : String, @state : String, @ip_address : String? = nil, @cpus : String? = nil, @ram : String? = nil)
    end
  end
end
