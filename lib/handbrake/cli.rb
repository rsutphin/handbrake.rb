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
    # @private
    def arguments
      @args.collect { |req, *rest| ["--#{req.to_s.gsub('_', '-')}", *rest] }.flatten
    end

    private

    def run(*more_args)
      @runner.run(arguments.push(*more_args))
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

      def run(arguments)
        output = ''
        cmd = arguments.unshift(@cli.bin_path).push(:err => [:child, :out])

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
