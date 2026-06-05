require "spec"
require "file_utils"
require "../../src/sail_containers/infrastructure/lxc_config_editor"

# Helper to manage temporary files safely in standard Crystal specs
def with_temp_file(content : String? = nil, &block : String ->)
  path = File.tempname("lxc_config", ".conf")
  File.write(path, content) if content
  begin
    yield path
  ensure
    File.delete?(path) if File.exists?(path)
  end
end

describe SailContainers::Infrastructure::LxcConfigEditor do
  describe "#initialize" do
    it "handles non-existent files gracefully" do
      editor = SailContainers::Infrastructure::LxcConfigEditor.new("/path/does/not/exist")
      editor.managed_config.empty?.should be_true
      editor.custom_lines.empty?.should be_true
    end

    it "parses an existing file, separating managed and custom configs" do
      content = <<-CONFIG
        # Some user comment
        lxc.uts.name = my-container
        lxc.cgroup2.memory.max = 512M
        lxc.apparmor.profile = unconfined
        some.weird.custom.key = value
      CONFIG

      with_temp_file(content) do |path|
        editor = SailContainers::Infrastructure::LxcConfigEditor.new(path)

        editor.get("lxc.uts.name").should eq("my-container")
        editor.get("lxc.cgroup2.memory.max").should eq("512M")
        editor.custom_lines.should eq(["lxc.apparmor.profile = unconfined", "some.weird.custom.key = value"])
      end
    end
  end

  describe "#set" do
    it "updates or adds a managed configuration" do
      with_temp_file do |path|
        editor = SailContainers::Infrastructure::LxcConfigEditor.new(path)
        editor.set("lxc.net.0.type", "ipvlan")
        editor.get("lxc.net.0.type").should eq("ipvlan")
      end
    end
  end

  describe "#save!" do
    it "persists managed configurations and preserves custom lines" do
      content = <<-CONFIG
        lxc.uts.name = old-name
        custom.hook = /bin/true
      CONFIG

      with_temp_file(content) do |path|
        editor = SailContainers::Infrastructure::LxcConfigEditor.new(path)

        editor.set("lxc.uts.name", "new-name")
        editor.set("lxc.cgroup2.memory.max", "1024M")
        editor.save!

        saved_content = File.read(path)
        saved_content.should contain("# Managed by Sail Containers Engine")
        saved_content.should contain("lxc.uts.name = new-name")
        saved_content.should contain("lxc.cgroup2.memory.max = 1024M")
        saved_content.should contain("# Custom Directives (Preserved)")
        saved_content.should contain("custom.hook = /bin/true")
      end
    end
  end
end
