require "./network"

module SailContainers::Models
  # Represents the current state and configuration of a container on the host.
  struct Container
    getter name : String
    getter state : String # "running" or "stopped"
    getter networks : Array(Network)
    getter cpus : String?
    getter ram : String?

    def initialize(@name : String, @state : String, @networks : Array(Network) = [] of Network, @cpus : String? = nil, @ram : String? = nil)
    end
  end
end
