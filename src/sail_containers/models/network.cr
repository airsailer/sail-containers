module SailContainers::Models
  # Represents a single network interface assigned to a container.
  struct Network
    getter link : String
    getter ip : String # Should include CIDR, e.g., "10.0.1.10/20"
    getter l2proxy : Bool

    def initialize(@link : String, @ip : String, @l2proxy : Bool = true)
    end
  end
end
