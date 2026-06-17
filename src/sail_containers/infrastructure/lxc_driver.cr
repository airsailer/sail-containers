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
    getter lxc_base_path : String

    # Allow injecting the base path so tests can isolate it
    def initialize(@lxc_base_path : String = "/var/lib/lxc")
    end

    def create(name : String, template : String, release : String?, local_template : Bool, storage_args : Array(String)) : Nil
      if local_template
        args = ["-n", template, "-N", name] + storage_args
        execute!("lxc-copy", args)
      else
        safe_release = release || raise Exceptions::ConfigurationError.new("Release is strictly required for remote templates")
        args = ["-n", name] + storage_args + ["--template", "download", "--", "--dist", template, "--release", safe_release, "--arch", "amd64"]
        execute!("lxc-create", args)
      end
    end

    def start(name : String) : Nil
      log_path = File.join(@lxc_base_path, name, "trace.log")
      args = ["-n", name, "--logfile", log_path, "--logpriority", "TRACE"]

      begin
        execute!("lxc-start", args)
      rescue ex : Exceptions::SystemExecutionError
        if File.exists?(log_path)
          trace_tail = File.read(log_path).lines.last(100).join("\n")
          enhanced_msg = "#{ex.message}\n\n--- LXC INTERNAL TRACE ---\n#{trace_tail}\n--------------------------"
          raise Exceptions::SystemExecutionError.new(enhanced_msg)
        else
          raise ex
        end
      end
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
        error_msg = result.error.strip.empty? ? result.output.strip : result.error.strip
        raise Exceptions::SystemExecutionError.new("Command '#{command} #{args.join(" ")}' failed: #{error_msg}")
      end
    rescue File::NotFoundError
      raise Exceptions::SystemExecutionError.new("LXC CLI tool '#{command}' is not installed or not found in PATH.")
    end
  end
end
