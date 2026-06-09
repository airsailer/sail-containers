require "spec"
require "file_utils"
require "../src/sail_containers"
require "./client_spec" # To access MockLxcDriver if needed

# This entire suite is gated by an ENV variable.
# Run locally with: E2E=true sudo -E crystal spec spec/e2e_lifecycle_spec.cr
if ENV["E2E"]? == "true"
  describe "E2E: Real LXC & LVM Lifecycle" do
    it "executes a full real-world container lifecycle" do
      # In E2E, we use the REAL driver
      client = SailContainers::Client.new(env: "production")
      node_name = "e2e-test-node-#{Time.utc.to_unix_ms}"

      networks = [SailContainers::Models::Network.new("sail0", "192.168.200.10/24")]

      begin
        # 1. CREATE
        client.create(
          name: node_name,
          template: "ubuntu",
          release: "noble",
          disk: "2G",
          networks: networks,
          autostart: true
        )

        # 2. VERIFY REALITY
        info = client.info(node_name)
        info.state.should eq("running")
        # Update the assertion here too
        info.networks.first.ip.should eq("192.168.200.10/24")

        # 3. LIFECYCLE
        client.stop(node_name)
        client.info(node_name).state.should eq("stopped")

        client.start(node_name)
        client.info(node_name).state.should eq("running")
      ensure
        # 4. CLEANUP (Crucial for real environments)
        # Even if the test fails, we must attempt to destroy the real container
        begin
          client.stop(node_name)
        rescue
        end
        client.destroy(node_name)
      end
    end
  end
end
