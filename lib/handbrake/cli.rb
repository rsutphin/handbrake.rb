require 'handbrake'

module HandBrake
  ##
  # The main entry point for this API. See {file:README.md} for usage
  # examples.
  class CLI
    ##
    # The full path (including filename) to the HandBrakeCLI
    # executable to use.
    #
    # @return [String]
    attr_accessor :bin_path

    ##
    # Set whether trace is enabled.
    #
    # @return [Boolean]
    attr_writer :trace

    ##
    # @param [Hash] options
    # @option options [String] :bin_path ('HandBrakeCLI') the full
    #   path to the executable to use
    # @option options [Boolean] :trace (false) whether {#trace?} is
    #   enabled
    # @option options [#run] :runner (a PopenRunner instance) the class
    #   encapsulating the execution method for HandBrakeCLI. You
    #   shouldn't usually need to replace this.
    def initialize(options={})
      @bin_path = options[:bin_path] || 'HandBrakeCLI'
      @trace = options[:trace].nil? ? false : options[:trace]
      @runner = options[:runner] || PopenRunner.new(self)

      @args = []
    end

    ##
    # Ensures that `#dup` produces a separate copy.
    #
    # @return [void]
    def initialize_copy(original)
      @args = original.instance_eval { @args }.collect { |bit| bit.dup }
    end

    ##
    # Is trace enabled?
    #
    # If it is enabled, all output from HandBrakeCLI will be streamed
    # to standard error. If not, the output from HandBrakeCLI will
    # only be printed if there is a detectable error.
    #
    # @return [Boolean]
    def trace?
      @trace
    end

    ##
    # Performs a conversion. This method immediately begins the
    # transcoding process; set all other options first.
    #
    # @param [String] filename the desired name for the final output
    #   file
    # @param [Hash] options additional options to control the behavior
    #   of the output process
    # @option options [Boolean,:ignore] :overwrite (true) determines
    #   the behavior if the desired output file already exists. If
    #   `true`, the file is replaced. If `false`, an exception is
    #   thrown. If `:ignore`, the file is skipped; i.e., HandBrakeCLI
    #   is not invoked.
    # @option options [Boolean] :atomic (false) provides a
    #   pseudo-atomic mode for transcoded output. If true, the
    #   transcode will go into a temporary file and only be copied to
    #   the specified filename if it completes. The temporary filename
    #   is the target filename with `.handbrake` appended. Any
    #   `:overwrite` checking will be applied to the target filename
    #   both before and after the transcode happens (the temporary
    #   file will always be overwritten). This option is intended to
    #   aid in writing automatically resumable batch scripts.
    #
    # @return [void]
    def output(filename, options={})
      overwrite = options.delete :overwrite
      case overwrite
      when true, nil
        # no special behavior
      when false
        raise FileExistsError, filename if File.exist?(filename)
      when :ignore
        if File.exist?(filename)
          trace "Ignoring transcode to #{filename.inspect} because it already exists"
          return
        end
      else
        raise "Unsupported value for :overwrite: #{overwrite.inspect}"
      end

      atomic = options.delete :atomic
      interim_filename =
        if atomic
          "#{filename}.handbrake"
        else
          filename
        end

      unless options.empty?
        raise "Unknown options for output: #{options.keys.inspect}"
      end

      run('--output', interim_filename)

      if filename != interim_filename
        replace =
          if File.exist?(filename)
            trace "#{filename.inspect} showed up during transcode"
            case overwrite
            when false
              raise FileExistsError, filename
            when :ignore
              trace "- will leave #{filename.inspect} as is; copy #{interim_filename.inspect} manually if you want to replace it"
              false
            else
              trace '- will replace with new transcode'
              true
            end
          else
            true
          end
        FileUtils.mv interim_filename, filename if replace
      end
    end

    ##
    # Performs a title scan. Unlike HandBrakeCLI, if you do not
    # specify a title, this method will return information for all
    # titles. (HandBrakeCLI defaults to only returning information for
    # title 1.)
    #
    # @return [Titles]
    def scan
      if arguments.include?('--title')
        result = run('--scan')
        Titles.from_output(result.output)
      else
        title(0).scan
      end
    end

    ##
    # Checks to see if the `HandBrakeCLI` instance designated by
    # {#bin_path} is the current version.
    #
    # Note that `HandBrakeCLI` will always report that it is up to
    # date if it can't connect to the update server, so this is not
    # terribly reliable.
    #
    # @return [Boolean]
    def update
      result = run('--update')
      result.output =~ /Your version of HandBrake is up to date./i
    end

    ##
    # Returns a structure describing the presets that the current
    # HandBrake install knows about. The structure is a two-level
    # hash. The keys in the first level are the preset categories. The
    # keys in the second level are the preset names and the values are
    # string representations of the arguments for that preset.
    #
    # (This method is included for completeness only. This library does
    # not provide a mechanism to translate the argument lists returned
    # here into the configuration for a {HandBrake::CLI} instance.)
    #
    # @return [Hash]
    def preset_list
      result = run('--preset-list')
      result.output.scan(%r{\< (.*?)\n(.*?)\>}m).inject({}) { |h1, (cat, block)|
        h1[cat.strip] = block.scan(/\+(.*?):(.*?)\n/).inject({}) { |h2, (name, args)|
          h2[name.strip] = args.strip
          h2
        }
        h1
      }
    end

    ##
    # @private
    def arguments
      @args.collect { |req, *rest| ["--#{req.to_s.gsub('_', '-')}", *rest] }.flatten
    end

    private

    def run(*more_args)
      @runner.run(arguments.push(*more_args)).tap do |result|
        unless result.status == 0
          unless trace?
            $stderr.puts result.output
          end
          raise "HandBrakeCLI execution failed (#{result.status.inspect})"
        end
      end
    end

    def trace(msg)
      $stderr.puts msg if trace?
    end

    ##
    # Copies this CLI instance and appends another command line switch
    # plus optional arguments.
    #
    # This method does not do any validation of the switch name; if
    # you use an invalid one, HandBrakeCLI will fail when it is
    # ultimately invoked.
    #
    # @return [CLI]
    def method_missing(name, *args)
      copy = self.dup
      copy.instance_eval { @args << [name, *(args.collect { |a| a.to_s })] }
      copy
    end

    ##
    # @private
    # The default runner. Uses `IO.popen` to spawn
    # HandBrakeCLI. General use of this library does not require
    # monkeying with this class.
    class PopenRunner
      ##
      # @param [CLI] cli_instance the {CLI} instance whose configuration to share
      def initialize(cli_instance)
        @cli = cli_instance
      end

      # Some notes on popen options
      # - IO.popen on 1.9.2 is much more elegant than on 1.8.7
      #   (it lets you pass spawn args directly instead of using a
      #   subshell, so you can more cleanly pass args to the
      #   executable and redirect streams)
      # - Open3.popen3 does not let you get the status
      # - Open4.popen4 does not seem to stream the output and error
      #   and hangs when the child process fills some buffer
      # Hence, this implementation:

      ##
      # @param [Array<String>] arguments the arguments to pass to HandBrakeCLI
      # @return [RunnerResult]
      def run(arguments)
        output = ''

        cmd = "'" + arguments.unshift(@cli.bin_path).join("' '") + "' 2>&1"

        $stderr.puts "Spawning HandBrakeCLI using #{cmd.inspect}" if @cli.trace?
        IO.popen(cmd) do |io|
          while line = io.gets
            output << line
            $stderr.puts(line.chomp) if @cli.trace?
          end
        end
        RunnerResult.new(output, $?)
      end
    end

    ##
    # @private
    # The raw result of one execution of HandBrakeCLI.
    #
    # General use of the library will not require use of this class.
    #
    # @attr [String] output a string containing the combined output
    #   and error streams from the run
    # @attr [#to_i] status the process exit status for the run
    RunnerResult = Struct.new(:output, :status)
  end
end
