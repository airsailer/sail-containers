require "spec"
require "../../src/sail_containers/infrastructure/lxc_driver"
require "../../src/sail_containers/exceptions"

class TestLxcCliDriver < SailContainers::Infrastructure::LxcCliDriver
  getter executed_commands = [] of Array(String)

  protected def execute!(command : String, args : Array(String)) : Nil
    @executed_commands << ([command] + args)
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

  it "constructs the start, stop, and destroy commands securely" do
    driver = TestLxcCliDriver.new

    driver.start("my-container")
    driver.executed_commands.last.should eq(["lxc-start", "-n", "my-container"])

    driver.stop("my-container")
    driver.executed_commands.last.should eq(["lxc-stop", "-n", "my-container"])

    driver.destroy("my-container")
    driver.executed_commands.last.should eq(["lxc-destroy", "-n", "my-container", "--force"])
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
end
