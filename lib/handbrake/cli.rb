require 'handbrake'

module HandBrake
  class CLI
    attr_accessor :bin_path
    attr_writer :trace

    def initialize(options={})
      @bin_path = options[:bin_path] || 'HandBrakeCLI'
      @trace = options[:trace].nil? ? false : options[:trace]

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
    # @private
    def arguments
      @args.collect { |req, *rest| ["--#{req.to_s.gsub('_', '-')}", *rest] }.flatten
    end

    def method_missing(name, *args)
      copy = self.dup
      copy.instance_eval { @args << [name, *(args.collect { |a| a.to_s })] }
      copy
    end
  end
end
