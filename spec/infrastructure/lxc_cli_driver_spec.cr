require "spec"
require "file_utils"
require "../../src/sail_containers/infrastructure/lxc_driver"
require "../../src/sail_containers/exceptions"

class TestLxcCliDriver < SailContainers::Infrastructure::LxcCliDriver
  getter executed_commands = [] of Array(String)
  property should_crash_on_start = false

  protected def execute!(command : String, args : Array(String)) : Nil
    @executed_commands << ([command] + args)

    # Simulate LXC throwing an error during startup
    if @should_crash_on_start && command == "lxc-start"
      raise SailContainers::Exceptions::SystemExecutionError.new("Command 'lxc-start' failed")
    end
  end
end

# A wrapper just to test the underlying original execute! method
class MissingBinaryDriver < SailContainers::Infrastructure::LxcCliDriver
  def trigger_fake_command
    # Calls the original protected method with a binary that definitely doesn't exist
    execute!("some-fake-binary-name", ["--arg"])
  end
end

describe SailContainers::Infrastructure::LxcCliDriver do
  it "constructs the remote create command securely" do
    driver = TestLxcCliDriver.new
    driver.create("my-container", "ubuntu", "noble", false, ["-B", "dir"])

    executed = driver.executed_commands.first
    executed.should eq([
      "lxc-create", "-n", "my-container", "-B", "dir",
      "--template", "download", "--", "--dist", "ubuntu", "--release", "noble", "--arch", "amd64",
    ])
  end

  it "constructs the local copy command securely" do
    driver = TestLxcCliDriver.new
    driver.create("my-container", "offline-base-img", nil, true, ["-B", "lvm", "--fssize", "10G"])

    executed = driver.executed_commands.first
    executed.should eq([
      "lxc-copy", "-n", "offline-base-img", "-N", "my-container", "-B", "lvm", "--fssize", "10G",
    ])
  end

  it "constructs the start, stop, and destroy commands securely (without debug)" do
    driver = TestLxcCliDriver.new

    driver.start("my-container")
    driver.executed_commands.last.should eq(["lxc-start", "-n", "my-container"])

    driver.stop("my-container")
    driver.executed_commands.last.should eq(["lxc-stop", "-n", "my-container"])

    driver.destroy("my-container")
    driver.executed_commands.last.should eq(["lxc-destroy", "-n", "my-container", "--force"])
  end

  it "constructs the start command with trace flags when debug is enabled" do
    driver = TestLxcCliDriver.new(debug: true)

    driver.start("my-container")
    driver.executed_commands.last.should eq([
      "lxc-start", "-n", "my-container",
      "--logfile", "/var/lib/lxc/my-container/trace.log",
      "--logpriority", "TRACE",
    ])
  end

  # Test the actual execution paths on the real driver
  it "executes real processes and maps failures to SystemExecutionError" do
    real_driver = SailContainers::Infrastructure::LxcCliDriver.new

    expect_raises(SailContainers::Exceptions::SystemExecutionError) do
      # Running start on a non-existent container will definitely fail
      real_driver.start("non-existent-container-12345")
    end
  end

  it "returns false for running? when container is non-existent or stopped" do
    real_driver = SailContainers::Infrastructure::LxcCliDriver.new
    # lxc-info on a non-existent container won't output "RUNNING"
    real_driver.running?("non-existent-container-12345").should be_false
  end

  it "enhances the error message with trace logs if start fails" do
    temp_dir = File.join(Dir.tempdir, "sail_fake_logs_#{Time.utc.to_unix_ms}")
    node_dir = File.join(temp_dir, "crash-node")
    Dir.mkdir_p(node_dir)

    # Write a fake trace log to simulate LXC dumping data before crashing
    log_path = File.join(node_dir, "trace.log")
    File.write(log_path, "TRACE: initializing\nERROR: something broke")

    driver = TestLxcCliDriver.new(lxc_base_path: temp_dir, debug: true)
    driver.should_crash_on_start = true

    begin
      expect_raises(SailContainers::Exceptions::SystemExecutionError, "--- LXC INTERNAL TRACE ---") do
        driver.start("crash-node")
      end
    ensure
      FileUtils.rm_rf(temp_dir)
    end
  end

  it "raises SystemExecutionError without trace logs if the log file is missing" do
    driver = TestLxcCliDriver.new(lxc_base_path: "/tmp/does-not-exist", debug: true)
    driver.should_crash_on_start = true

    # Should raise the standard error without the trace appendix
    expect_raises(SailContainers::Exceptions::SystemExecutionError, "Command 'lxc-start' failed") do
      driver.start("ghost-node")
    end
  end

  it "maps File::NotFoundError to a domain SystemExecutionError" do
    driver = MissingBinaryDriver.new

    expect_raises(SailContainers::Exceptions::SystemExecutionError, "is not installed or not found in PATH") do
      driver.trigger_fake_command
    end
  end
end
