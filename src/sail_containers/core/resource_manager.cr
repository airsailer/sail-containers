require "sync"
require "../exceptions"

module SailContainers::Core
  class ResourceManager
    @mutex = Sync::Mutex.new

    # Maps container name to allocated CPU IDs: {"web-01" => "0,1", "db-01" => "2,3"}
    @cpu_allocations = {} of String => String

    getter total_cores : Int32

    def initialize(@total_cores : Int32 = System.cpu_count, initial_allocations : Hash(String, String) = {} of String => String)
      @cpu_allocations = initial_allocations.dup
    end

    def allocate_cpus!(container_name : String, requested_cores : Int32) : String
      raise Exceptions::ResourceAllocationError.new("Requested cores (#{requested_cores}) cannot be zero or negative") if requested_cores <= 0

      @mutex.synchronize do
        currently_allocated = @cpu_allocations.values.map { |v| v.split(",").size }.sum

        assigned = [] of Int32
        requested_cores.times do |i|
          assigned << (currently_allocated + i) % @total_cores
        end

        assigned_str = assigned.join(",")
        @cpu_allocations[container_name] = assigned_str
        assigned_str
      end
    end

    def release_cpus!(container_name : String) : Nil
      @mutex.synchronize do
        @cpu_allocations.delete(container_name)
      end
    end

    def active_allocations
      @mutex.synchronize { @cpu_allocations.dup }
    end
  end
end
