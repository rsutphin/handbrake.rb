require 'bundler'
Bundler.setup

require 'rspec'
require 'fileutils'

$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)

require 'handbrake'

RSpec.configure do |config|
  def tmpdir(sub=nil)
    @tmpdir ||= begin
                  dirname = File.expand_path("../tmp", __FILE__)
                  FileUtils.mkdir_p dirname
                  dirname
                end
    if sub
      full = File.join(@tmpdir, sub)
      FileUtils.mkdir_p full
      full
    else
      @tmpdir
    end
  end

  config.after { FileUtils.rm_rf @tmpdir if @tmpdir }
end

module HandBrake
  module Spec
    ##
    # A stub implementation of the runner for HandBrake::CLI.
    class StaticRunner
      attr_accessor :output, :status
      ##
      # A lambda that specifies desired side effects of execution or
      # simulates things happening outside the execution but
      # simultaneous with it.
      attr_accessor :behavior
      attr_reader :actual_arguments

      def run(args)
        @actual_arguments = args
        if i = args.index('--output')
          fn = args[i + 1]
          File.open(fn, 'w') { |f| f.write 'This is the file created by --output' }
        end
        if behavior
          behavior.call
        end
        HandBrake::CLI::RunnerResult.new(output, status)
      end

      def status
        @status ||= 0
      end
    end
  end
end
