require 'handbrake'

module HandBrake
  class CLI
    attr_accessor :bin_path
    attr_writer :trace

    def initialize(options={})
      @bin_path = options[:bin_path] || 'HandBrakeCLI'
      @trace = options[:trace].nil? ? false : options[:trace]
      @runner = options[:runner] || PopenRunner.new(self)

      @args = []
    end

    ##
    # Ensures that {#dup} produces a separate copy.
    def initialize_copy(original)
      @args = original.instance_eval { @args }.collect { |bit| bit.dup }
    end

    ##
    # Is trace enabled?
    def trace?
      @trace
    end

    ##
    # Performs a conversion. This method immediately begins the
    # transcoding process; set all other options first.
    #
    # @return [void]
    def output(filename)
      run('--output', filename)
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

    def method_missing(name, *args)
      copy = self.dup
      copy.instance_eval { @args << [name, *(args.collect { |a| a.to_s })] }
      copy
    end

    class PopenRunner
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

    RunnerResult = Struct.new(:output, :status)
  end
end
