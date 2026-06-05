require "spec"
require "file_utils"
require "../src/sail_containers"

class MockLxcDriver < SailContainers::Infrastructure::LxcDriver
  getter created = [] of String
  getter started = [] of String
  getter destroyed = [] of String
  property should_fail_on_create = false
  property lxc_base_path = "/var/lib/lxc"

  def create(name : String, template : String, storage_args : Array(String)) : Nil
    raise SailContainers::Exceptions::SystemExecutionError.new("Mocked failure") if @should_fail_on_create
    @created << name

    dir = File.join(@lxc_base_path, name)
    Dir.mkdir_p(dir)
    File.write(File.join(dir, "config"), "# Initial lxc config\n")
  end

  def start(name : String) : Nil
    @started << name unless @started.includes?(name)
  end

  def stop(name : String) : Nil
    @started.delete(name)
  end

  def running?(name : String) : Bool
    @started.includes?(name)
  end

  def destroy(name : String) : Nil
    @destroyed << name
    FileUtils.rm_rf(File.join(@lxc_base_path, name))
  end
end

def with_test_client(&block : SailContainers::Client, MockLxcDriver, SailContainers::Core::ResourceManager, String ->)
  temp_lxc_dir = File.join(Dir.tempdir, "sail_tests_#{Time.utc.to_unix_ms}")
  Dir.mkdir_p(temp_lxc_dir)

  mock_driver = MockLxcDriver.new
  mock_driver.lxc_base_path = temp_lxc_dir

  resources = SailContainers::Core::ResourceManager.new(total_cores: 4)

  client = SailContainers::Client.new(
    env: "local",
    driver: mock_driver,
    resources: resources,
    lxc_base_path: temp_lxc_dir
  )

  begin
    yield client, mock_driver, resources, temp_lxc_dir
  ensure
    FileUtils.rm_rf(temp_lxc_dir)
  end
end

describe SailContainers::Client do
  describe "#create" do
    it "executes the full creation workflow and writes configurations" do
      with_test_client do |client, driver, _, temp_dir|
        client.create("test-node", "ubuntu", 2, 1024, 10, "10.0.0.5", true)

        driver.created.should contain("test-node")
        driver.started.should contain("test-node")

        config_content = File.read(File.join(temp_dir, "test-node", "config"))
        config_content.should contain("lxc.net.0.ipv4.address = 10.0.0.5")
      end
    end

    it "rolls back CPU allocations if LXC creation fails" do
      with_test_client do |client, driver, resources, _|
        driver.should_fail_on_create = true

        expect_raises(SailContainers::Exceptions::SystemExecutionError) do
          client.create("test-node", "ubuntu", 2, 1024, 10, "10.0.0.5")
        end

        resources.active_allocations.has_key?("test-node").should be_false
      end
    end
  end

  describe "Lifecycle Methods" do
    it "can stop, start, and restart an existing container" do
      with_test_client do |client, driver, _, _|
        client.create("lifecycle-node", "ubuntu", 1, 512, 10, "10.0.0.2", autostart: true)
        driver.running?("lifecycle-node").should be_true

        client.stop("lifecycle-node")
        driver.running?("lifecycle-node").should be_false

        client.start("lifecycle-node")
        driver.running?("lifecycle-node").should be_true

        # Restart stops then starts
        client.restart("lifecycle-node")
        driver.running?("lifecycle-node").should be_true
      end
    end

    it "raises ContainerNotFoundError if interacting with non-existent container" do
      with_test_client do |client, _, _, _|
        expect_raises(SailContainers::Exceptions::ContainerNotFoundError) do
          client.start("ghost-node")
        end
      end
    end
  end

  describe "Inspection Methods" do
    it "returns info for a specific container" do
      with_test_client do |client, _, _, _|
        client.create("info-node", "ubuntu", 2, 2048, 10, "10.0.0.10", autostart: false)

        info = client.info("info-node")
        info.name.should eq("info-node")
        info.state.should eq("stopped")
        info.ip_address.should eq("10.0.0.10")
        info.cpus.should eq("0,1")
        info.ram.should eq("2048M")
      end
    end

    it "returns a list of all containers" do
      with_test_client do |client, _, _, _|
        client.create("node-a", "ubuntu", 1, 512, 5, "10.0.0.11", autostart: true)
        client.create("node-b", "ubuntu", 1, 512, 5, "10.0.0.12", autostart: false)

        # Sort by name to guarantee deterministic ordering without needing .find or .not_nil!
        list = client.list.sort_by(&.name)
        list.size.should eq(2)

        # Accessing by index guarantees a non-nil return type in Crystal.
        # If the index is missing, it cleanly raises an IndexError causing the test to fail.
        node_a = list[0]
        node_a.name.should eq("node-a")
        node_a.state.should eq("running")

        node_b = list[1]
        node_b.name.should eq("node-b")
        node_b.state.should eq("stopped")
      end
    end
  end

  describe "#destroy" do
    it "destroys the container and releases resources" do
      with_test_client do |client, driver, resources, _|
        client.create("test-node", "ubuntu", 2, 1024, 10, "10.0.0.5")
        client.destroy("test-node")

        driver.destroyed.should contain("test-node")
        resources.active_allocations.has_key?("test-node").should be_false
      end
    end
  end
end
