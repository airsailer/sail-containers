require "spec"
require "wait_group"
require "../../src/sail_containers/core/resource_manager"

describe SailContainers::Core::ResourceManager do
  describe "#allocate_cpus!" do
    it "can be initialized with existing allocations" do
      initial = {"existing-node" => "0,1"}
      manager = SailContainers::Core::ResourceManager.new(total_cores: 4, initial_allocations: initial)

      manager.active_allocations["existing-node"].should eq("0,1")

      # Next allocation should understand cores 0 and 1 are already taken
      manager.allocate_cpus!("new-node", 1).should eq("2")
    end

    it "raises an error if requested cores is invalid" do
      manager = SailContainers::Core::ResourceManager.new(total_cores: 4)

      expect_raises(SailContainers::Exceptions::ResourceAllocationError) do
        manager.allocate_cpus!("test-1", 0)
      end
    end

    it "allocates CPUs successfully" do
      manager = SailContainers::Core::ResourceManager.new(total_cores: 4)
      result = manager.allocate_cpus!("test-1", 2)

      result.should eq("0,1")
      manager.active_allocations["test-1"].should eq("0,1")
    end

    it "releases CPUs successfully" do
      manager = SailContainers::Core::ResourceManager.new(total_cores: 4)
      manager.allocate_cpus!("test-1", 2)
      manager.release_cpus!("test-1")

      manager.active_allocations.has_key?("test-1").should be_false
    end

    it "is thread-safe during concurrent allocations" do
      manager = SailContainers::Core::ResourceManager.new(total_cores: 8)

      # We use Crystal's WaitGroup to spin up fibers and test the Mutex
      WaitGroup.wait do |wg|
        10.times do |i|
          wg.spawn do
            manager.allocate_cpus!("container-#{i}", 1)
          end
        end
      end

      # 10 allocations of 1 core each should exist
      manager.active_allocations.size.should eq(10)
    end
  end
end
