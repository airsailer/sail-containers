require "spec"
require "../../src/sail_containers/infrastructure/lxc_driver"

# We create a spy class specifically for testing command construction
class TestLxcCliDriver < SailContainers::Infrastructure::LxcCliDriver
  getter executed_commands = [] of Array(String)

  # Override the protected method to capture instead of execute
  protected def execute!(command : String, args : Array(String)) : Nil
    @executed_commands << ([command] + args)
  end
end

describe SailContainers::Infrastructure::LxcCliDriver do
  it "constructs the create command securely without shell evaluation" do
    driver = TestLxcCliDriver.new
    driver.create("my-container", "ubuntu", ["-B", "dir"])

    executed = driver.executed_commands.first
    # We expect exactly these string arguments passed to Process
    executed.should eq([
      "lxc-create", "-n", "my-container", "-B", "dir",
      "--template", "download", "--", "--dist", "ubuntu", "--arch", "amd64",
    ])
  end

  it "constructs the start command" do
    driver = TestLxcCliDriver.new
    driver.start("my-container")

    driver.executed_commands.first.should eq(["lxc-start", "-n", "my-container"])
  end
end
