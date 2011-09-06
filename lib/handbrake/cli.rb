require 'handbrake'
require 'fileutils'

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
    # Set whether dry_run mode is selected.
    #
    # @return [Boolean]
    attr_writer :dry_run

    ##
    # The runner to use to actually invoke HandBrakeCLI. This should
    # be an object following the protocol laid out in the
    # documentation for {PopenRunner}.
    #
    # @return [#run]
    attr_accessor :runner

    ##
    # @param [Hash] options
    # @option options [String] :bin_path ('HandBrakeCLI') the full
    #   path to the executable to use
    # @option options [Boolean] :trace (false) whether {#trace?} is
    #   enabled
    # @option options [Boolean] :dry_run (false) if true, nothing will
    #   actually be executed. The commands that would have been
    #   executed will be printed to standard out.
    # @option options [#run, #call] :runner (a PopenRunner instance)
    #   the object encapsulating the execution method for HandBrakeCLI
    #   or a lambda which may be invoked to create the runner. A lambda will
    #   receive the {CLI} instance that's being constructed as its
    #   sole argument.  You shouldn't usually need to replace this. If
    #   you do, look at {#runner} for more details.
    def initialize(options={})
      @bin_path = options[:bin_path] || 'HandBrakeCLI'
      @trace = options[:trace].nil? ? false : options[:trace]
      @dry_run = options[:dry_run] || false
      @runner = build_runner(options[:runner])

      @args = []
    end

    def build_runner(selected)
      default_runner_creator = lambda { |cli| PopenRunner.new(cli) }

      case
      when selected.nil?
        default_runner_creator.call(self)
      when selected.respond_to?(:call)
        selected.call(self) || default_runner_creator.call(self)
      else
        selected
      end
    end
    private :build_runner

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
    # Is this instance in `dry_run` mode?
    #
    # If it is, then no commands will actually be executed. The
    # constructed `HandBrakeCLI` invocations will be printed to
    # standard out, instead.
    def dry_run?
      @dry_run
    end

    def fileutils_options
      {
        :noop => dry_run?,
        :verbose => trace? || dry_run?
      }
    end
    private :fileutils_options

    ##
    # Performs a conversion. This method immediately begins the
    # transcoding process; set all other options first.
    #
    # @param [String] filename the desired name for the final output
    #   file.
    # @param [Hash] options additional options to control the behavior
    #   of the output process. The provided hash will not be modified.
    # @option options [Boolean,:ignore] :overwrite (true) determines
    #   the behavior if the desired output file already exists. If
    #   `true`, the file is replaced. If `false`, an exception is
    #   thrown. If `:ignore`, the file is skipped; i.e., HandBrakeCLI
    #   is not invoked.
    # @option options [Boolean, String] :atomic (false) provides a
    #   pseudo-atomic mode for transcoded output. If true, the
    #   transcode will go into a temporary file and only be copied to
    #   the specified filename if it completes. If the value is
    #   literally `true`, the temporary filename is the target
    #   filename with `.handbraking` inserted before the extension. If
    #   the value is a string, it is interpreted as a path; the
    #   temporary file is written to this path instead of in the
    #   ultimate target directory. Any `:overwrite` checking will be
    #   applied to the target filename both before and after the
    #   transcode happens (the temporary file will always be
    #   overwritten). This option is intended to aid in writing
    #   automatically resumable batch scripts.
    #
    # @return [void]
    def output(filename, options={})
      options = options.dup
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
        case atomic
        when true
          partial_filename(filename)
        when String
          partial_filename(File.join(atomic, File.basename(filename)))
        when false, nil
          filename
        else
          fail "Unsupported value for :atomic: #{atomic.inspect}"
        end

      unless options.empty?
        raise "Unknown options for output: #{options.keys.inspect}"
      end

      FileUtils.mkdir_p(File.dirname(interim_filename), fileutils_options)
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
        FileUtils.mkdir_p(File.dirname(filename), fileutils_options)
        FileUtils.mv(interim_filename, filename, fileutils_options) if replace
      end
    end

    def partial_filename(name)
      if File.basename(name).index '.'
        dot_at = name.rindex '.'
        name.dup.insert dot_at, '.handbraking'
      else
        name + '.handbraking'
      end
    end
    private :partial_filename

    ##
    # Performs a title scan. Unlike HandBrakeCLI, if you do not
    # specify a title, this method will return information for all
    # titles. (HandBrakeCLI defaults to only returning information for
    # title 1.)
    #
    # @return [Disc,Title] a {Disc} when scanning for all titles, or a
    #   {Title} when scanning for one title.
    def scan
      one_title = arguments.include?('--title')

      args = %w(--scan)
      unless one_title
        args.unshift('--title', '0')
      end

      disc = Disc.from_output(run(*args).output)

      if one_title
        disc.titles.values.first
      else
        disc
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
        unless result.status.to_i == 0
          unless trace?
            $stderr.write result.output
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
    # The default runner. Uses `IO.popen` to spawn
    # HandBrakeCLI. General use of this library does not require
    # monkeying with this class.
    #
    # If you have non-general use case, a replacement runner must have
    # a method matching the signature of {#run}.
    #
    # @see CLI#initialize the HandBrake::CLI constructor
    # @see CLI#runner HandBrake::CLI#runner
    class PopenRunner
      ##
      # @param [CLI] cli_instance the {CLI} instance for which this
      #   runner will execute.
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

        cmd = command(arguments)

        $stderr.puts "Spawning HandBrakeCLI using #{cmd.inspect}" if @cli.trace?
        if @cli.dry_run?
          puts cmd
          RunnerResult.new('', 0)
        else
          IO.popen(cmd) do |io|
            while line = io.read(60)
              output << line
              $stderr.write(line) if @cli.trace?
            end
          end
          RunnerResult.new(output, $?)
        end
      end

      ##
      # @return [String] the concatentated command string to pass to IO.popen.
      def command(arguments)
        "'#{arguments.unshift(@cli.bin_path).collect { |a| a.gsub(%r(')) { %('\\\'') } }.join("' '")}' 2>&1"
      end
    end

    ##
    # The raw result of one execution of HandBrakeCLI.
    #
    # General use of the library will not require use of this
    # class. If you create your own {CLI#runner runner} its `run`
    # method should return an instance of this class.
    #
    # @attr [String] output a string containing the combined output
    #   and error streams from the run
    # @attr [#to_i] status the process exit status for the run
    RunnerResult = Struct.new(:output, :status)
  end
end
