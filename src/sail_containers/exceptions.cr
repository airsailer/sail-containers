module SailContainers
  # The base error class for the SailContainers module.
  # All domain-specific errors inherit from this.
  class Error < Exception; end

  module Exceptions
    class StorageError < Error; end

    class ResourceAllocationError < Error; end

    class ConfigurationError < Error; end

    class ContainerNotFoundError < Error; end

    class SystemExecutionError < Error; end
  end
end
