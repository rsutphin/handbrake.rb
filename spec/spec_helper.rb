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
      attr_reader :actual_arguments

      def run(args)
        @actual_arguments = args
        HandBrake::CLI::RunnerResult.new(output, status)
      end

      def status
        @status ||= 0
      end
    end
  end
end
