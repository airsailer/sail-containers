require "spec"
require "file_utils"
require "../../src/sail_containers/infrastructure/state_bootstrapper"

describe SailContainers::Infrastructure::StateBootstrapper do
  describe ".load_cpu_allocations" do
    it "scans the base path and extracts cpu allocations from configs" do
      temp_lxc_dir = File.join(Dir.tempdir, "sail_bootstrapper_test_#{Time.utc.to_unix_ms}")

      # Container 1: Has CPU limits
      c1_dir = File.join(temp_lxc_dir, "web-01")
      Dir.mkdir_p(c1_dir)
      File.write(File.join(c1_dir, "config"), "lxc.cgroup2.cpuset.cpus = 0,1\n")

      # Container 2: Has CPU limits
      c2_dir = File.join(temp_lxc_dir, "db-01")
      Dir.mkdir_p(c2_dir)
      File.write(File.join(c2_dir, "config"), "lxc.cgroup2.cpuset.cpus = 2,3,4\n")

      # Container 3: Missing config completely (edge case)
      c3_dir = File.join(temp_lxc_dir, "missing-01")
      Dir.mkdir_p(c3_dir)

      # Container 4: Has config, but no CPU limits specified
      c4_dir = File.join(temp_lxc_dir, "unlimited-01")
      Dir.mkdir_p(c4_dir)
      File.write(File.join(c4_dir, "config"), "lxc.uts.name = unlimited-01\n")

      begin
        allocations = SailContainers::Infrastructure::StateBootstrapper.load_cpu_allocations(temp_lxc_dir)

        allocations.size.should eq(2)
        allocations["web-01"].should eq("0,1")
        allocations["db-01"].should eq("2,3,4")

        allocations.has_key?("missing-01").should be_false
        allocations.has_key?("unlimited-01").should be_false
      ensure
        FileUtils.rm_rf(temp_lxc_dir)
      end
    end
  end
end
