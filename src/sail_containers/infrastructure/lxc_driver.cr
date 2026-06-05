require "../exceptions"

module SailContainers::Infrastructure
  # The abstract boundary representing interactions with the underlying container engine.
  abstract class LxcDriver
    abstract def create(name : String, template : String, storage_args : Array(String)) : Nil
    abstract def start(name : String) : Nil
    abstract def stop(name : String) : Nil
    abstract def running?(name : String) : Bool
    abstract def destroy(name : String) : Nil
  end

  # The concrete implementation that talks to the LXC CLI using strict Process bindings.
  class LxcCliDriver < LxcDriver
    def create(name : String, template : String, storage_args : Array(String)) : Nil
      # Uses strictly defined arrays to prevent shell injections
      base_args = ["-n", name] + storage_args + ["--template", "download", "--", "--dist", template, "--arch", "amd64"]
      execute!("lxc-create", base_args)
    end

    def start(name : String) : Nil
      execute!("lxc-start", ["-n", name])
    end

    def stop(name : String) : Nil
      execute!("lxc-stop", ["-n", name])
    end

    def destroy(name : String) : Nil
      execute!("lxc-destroy", ["-n", name, "--force"])
    end

    def running?(name : String) : Bool
      # Process.capture_result is Crystal 1.20 standard
      result = Process.capture_result(["lxc-info", "-n", name, "--state"])
      result.output.includes?("RUNNING")
    end

    # Protected wrapper to execute and map errors to our Domain
    protected def execute!(command : String, args : Array(String)) : Nil
      result = Process.capture_result([command] + args)

      unless result.status.success?
        # Clean up the output string to surface the actual LXC error
        error_msg = result.error.strip.empty? ? result.output.strip : result.error.strip
        raise Exceptions::SystemExecutionError.new("Command '#{command} #{args.join(" ")}' failed: #{error_msg}")
      end
    end
  end
end
