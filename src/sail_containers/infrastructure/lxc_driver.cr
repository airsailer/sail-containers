require "../exceptions"

module SailContainers::Infrastructure
  abstract class LxcDriver
    abstract def create(name : String, template : String, release : String?, local_template : Bool, storage_args : Array(String)) : Nil
    abstract def start(name : String) : Nil
    abstract def stop(name : String) : Nil
    abstract def running?(name : String) : Bool
    abstract def destroy(name : String) : Nil
  end

  class LxcCliDriver < LxcDriver
    def create(name : String, template : String, release : String?, local_template : Bool, storage_args : Array(String)) : Nil
      if local_template
        args = ["-n", template, "-N", name] + storage_args
        execute!("lxc-copy", args)
      else
        # Safely unwrap release to strictly avoid .not_nil!
        safe_release = release || raise Exceptions::ConfigurationError.new("Release is strictly required for remote templates")

        args = ["-n", name] + storage_args + ["--template", "download", "--", "--dist", template, "--release", safe_release, "--arch", "amd64"]
        execute!("lxc-create", args)
      end
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
      result = Process.capture_result(["lxc-info", "-n", name, "--state"])
      result.output.includes?("RUNNING")
    rescue File::NotFoundError
      # If lxc-info is missing entirely from the host OS, it's definitely not running.
      false
    end

    protected def execute!(command : String, args : Array(String)) : Nil
      result = Process.capture_result([command] + args)

      unless result.status.success?
        # LCOV_EXCL_START
        error_msg = result.error.strip.empty? ? result.output.strip : result.error.strip
        # LCOV_EXCL_STOP
        raise Exceptions::SystemExecutionError.new("Command '#{command} #{args.join(" ")}' failed: #{error_msg}")
      end
    rescue File::NotFoundError
      # Map the missing binary error strictly to our Domain Exception
      raise Exceptions::SystemExecutionError.new("LXC CLI tool '#{command}' is not installed or not found in PATH.")
    end
  end
end
