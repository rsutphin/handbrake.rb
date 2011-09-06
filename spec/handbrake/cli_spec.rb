require File.expand_path('../../spec_helper.rb', __FILE__)

module HandBrake
  describe CLI do
    describe "#bin_path" do
      it "looks on the path by default" do
        HandBrake::CLI.new.bin_path.should == "HandBrakeCLI"
      end

      it "is the specified value when specified" do
        HandBrake::CLI.new(:bin_path => '/Applications/HandBrakeCLI').bin_path.
          should == '/Applications/HandBrakeCLI'
      end
    end

    describe "#trace?" do
      it "is false by default" do
        HandBrake::CLI.new.trace?.should == false
      end

      it "can be set" do
        HandBrake::CLI.new(:trace => true).trace?.should == true
      end
    end

    describe '#runner' do
      let(:default_runner_class) { HandBrake::CLI::PopenRunner }

      it 'is a PopenRunner by default' do
        HandBrake::CLI.new.runner.should be_a default_runner_class
      end

      it 'can be set with a static value' do
        HandBrake::CLI.new(:runner => HandBrake::Spec::StaticRunner.new).runner.
          should be_a HandBrake::Spec::StaticRunner
      end

      describe 'set from a lambda' do
        let(:recorder_class) { Struct.new(:input) }
        let(:runner_constructor) { lambda { |cli| recorder_class.new(cli) } }
        let(:cli) { HandBrake::CLI.new(:runner => runner_constructor) }

        it 'calls the lambda' do
          cli.runner.should be_a recorder_class
        end

        it 'yields the CLI instance' do
          cli.runner.input.should be cli
        end

        it 'uses the default if the lambda returns nil' do
          HandBrake::CLI.new(:runner => lambda { |cli| nil }).runner.
            should be_a default_runner_class
        end
      end
    end

    describe "building a command" do
      let(:cli) { HandBrake::CLI.new }

      it "works for a parameter without an argument" do
        cli.markers.arguments.should == %w(--markers)
      end

      it "works for a parameter with an argument" do
        cli.quality('0.8').arguments.should == %w(--quality 0.8)
      end

      it "works with a parameter with a dashed name" do
        cli.native_language('eng').arguments.should == %w(--native-language eng)
      end

      it "can chain parameters" do
        cli.previews('15').format('avi').large_file.title('3').arguments.should ==
          %w(--previews 15 --format avi --large-file --title 3)
      end

      it "stringifies arguments" do
        cli.previews(18).arguments.should == %w(--previews 18)
      end

      it "can produce separate forks of the command" do
        base = cli.input('/foo/bar')
        base.quality('0.53').format('avi').arguments.should ==
          %w(--input /foo/bar --quality 0.53 --format avi)
        base.title('6').ipod_atom.arguments.should ==
          %w(--input /foo/bar --title 6 --ipod-atom)
      end
    end

    describe 'execution' do
      let(:cli) { HandBrake::CLI.new(:runner => runner) }
      let(:runner) { HandBrake::Spec::StaticRunner.new }

      describe 'default runner' do
        let(:cli) { HandBrake::CLI.new }

        before do
          `which HandBrakeCLI`
          unless $? == 0
            pending 'HandBrakeCLI is not on the path'
          end
        end

        it 'works' do
          lambda { cli.preset_list }.should_not raise_error
        end
      end

      describe '#output' do
        let(:filename) { File.join(tmpdir, 'foo.m4v') }

        def it_should_have_run(expected_fn=filename)
          runner.actual_arguments.should == ['--output', expected_fn]
        end

        def it_should_not_have_run
          runner.actual_arguments.should be_nil
        end

        it 'uses the --output argument' do
          cli.output(filename)
          runner.actual_arguments.should == ['--output', filename]
        end

        it 'fails for an unknown option' do
          lambda { cli.output(filename, :quux => 'zap') }.
            should raise_error('Unknown options for output: [:quux]')
        end

        it 'does not directly modify the passed-in options hash' do
          options = { :overwrite => true }
          cli.output(filename, options)
          options[:overwrite].should be_true
        end

        it 'creates the target directory when it does not exist' do
          new_dir = File.join(tmpdir, 'quux')
          cli.output(File.join(new_dir, 'baz.m4v'))
          File.directory?(new_dir).should be_true
        end

        describe ':overwrite' do
          context 'true' do
            it 'executes when the file does not exist' do
              cli.output(filename, :overwrite => true)
              it_should_have_run
            end

            it 'executes when the file exists' do
              FileUtils.touch filename
              cli.output(filename, :overwrite => true)
              it_should_have_run
            end

            it 'is the default' do
              FileUtils.touch filename
              cli.output(filename)
              it_should_have_run
            end
          end

          context 'false' do
            it 'executes when the file does not exist' do
              cli.output(filename, :overwrite => false)
              it_should_have_run
            end

            it 'throws an exception when the file does exist' do
              FileUtils.touch filename
              lambda { cli.output(filename, :overwrite => false) }.
                should raise_error(HandBrake::FileExistsError)
            end
          end

          context ':ignore' do
            it 'executes when the file does not exist' do
              cli.output(filename, :overwrite => :ignore)
              it_should_have_run
            end

            it 'does nothing when the file does exist' do
              FileUtils.touch filename
              cli.output(filename, :overwrite => :ignore)
              it_should_not_have_run
            end
          end

          context 'other value' do
            it 'throws an exception' do
              lambda { cli.output(filename, :overwrite => 'flip') }.
                should raise_error('Unsupported value for :overwrite: "flip"')
            end
          end
        end

        describe ':atomic' do
          context 'false' do
            it 'executes normally' do
              cli.output(filename, :atomic => false)
              it_should_have_run
            end

            it 'is the default' do
              cli.output(filename)
              it_should_have_run
            end
          end

          shared_examples 'atomic enabled' do
            it 'outputs to the temporary file with ".handbraking" inserted before the extension' do
              cli.output(filename, :atomic => atomic_option_value)
              it_should_have_run(expected_temporary_file)
            end

            it 'appends .handbraking if the output file does not have an extension' do
              cli.output(File.join(tmpdir('a.b.c'), 'foo'), :atomic => atomic_option_value)
              it_should_have_run(expected_no_extension_temporary_filename)
            end

            it 'copies the output to the desired filename' do
              cli.output(filename, :atomic => atomic_option_value)
              File.read(filename).should == 'This is the file created by --output'
            end

            it 'creates the directory for the desired filename if necessary' do
              new_dir = File.join(tmpdir, 'quux')
              cli.output(File.join(new_dir, 'baz.m4v'), :atomic => atomic_option_value)
              File.directory?(new_dir).should be_true
            end

            it 'removes the temporary file' do
              cli.output(filename, :atomic => atomic_option_value)
              File.exist?(expected_temporary_file).should be_false
            end

            it 'overwrites the temporary file if it exists' do
              FileUtils.mkdir_p File.dirname(expected_temporary_file)
              FileUtils.touch expected_temporary_file
              cli.output(filename, :atomic => atomic_option_value)
              it_should_have_run(expected_temporary_file)
            end

            describe 'and :overwrite' do
              describe 'false' do
                it 'throws an exception if the target filename exists initially' do
                  FileUtils.touch filename
                  lambda { cli.output(filename, :atomic => atomic_option_value, :overwrite => false) }.
                    should raise_error(HandBrake::FileExistsError)
                end

                it 'throws an exception if the target filename exists after output' do
                  runner.behavior = lambda { FileUtils.touch filename }
                  lambda { cli.output(filename, :atomic => atomic_option_value, :overwrite => false) }.
                    should raise_error(HandBrake::FileExistsError)
                end
              end

              describe ':ignore' do
                it 'does nothing if the target filename exists initially' do
                  FileUtils.touch filename
                  cli.output(filename, :atomic => atomic_option_value, :overwrite => :ignore)
                  it_should_not_have_run
                end

                it 'does not copy the output if the target filename exists after encoding' do
                  runner.behavior = lambda {
                    File.open(filename, 'w') { |f| f.write 'Other process result' }
                  }
                  cli.output(filename, :atomic => atomic_option_value, :overwrite => :ignore)
                  File.read(filename).should == 'Other process result'
                end

                it 'does not remove the temporary output if the target filename exists after encoding' do
                  runner.behavior = lambda {
                    File.open(filename, 'w') { |f| f.write 'Other process result' }
                  }
                  cli.output(filename, :atomic => atomic_option_value, :overwrite => :ignore)
                  File.exist?(expected_temporary_file).should be_true
                end
              end
            end
          end

          context 'true' do
            let(:atomic_option_value) { true }
            let(:expected_temporary_file) { File.join(tmpdir, "foo.handbraking.m4v") }
            let(:expected_no_extension_temporary_filename) {
              File.join(tmpdir('a.b.c'), 'foo.handbraking')
            }

            include_examples 'atomic enabled'
          end

          context 'an alternate path' do
            let(:atomic_option_value) { File.join(tmpdir, 'somewhere/else') } # not mkdir'd
            let(:expected_temporary_file) { File.join(atomic_option_value, "foo.handbraking.m4v") }
            let(:expected_no_extension_temporary_filename) {
              File.join(atomic_option_value, 'foo.handbraking')
            }

            include_examples 'atomic enabled'
          end
        end
      end

      describe '#scan' do
        let(:sample_scan) { File.read(File.expand_path('../sample-titles-scan.err', __FILE__)) }
        let(:single_scan) { File.read(File.expand_path('../single-title-scan.err', __FILE__)) }

        before do
          runner.output = sample_scan
        end

        it 'uses the --scan argument' do
          cli.scan
          runner.actual_arguments.last.should == '--scan'
        end

        it 'defaults to scanning all titles' do
          cli.scan
          runner.actual_arguments.should == %w(--title 0 --scan)
        end

        it 'only scans the specified title if one is specified' do
          cli.title(2).scan
          runner.actual_arguments.should == %w(--title 2 --scan)
        end

        it 'does not permanently modify the argument list when using the default title setting' do
          cli.scan
          cli.arguments.should_not include('--title')
        end

        it 'return a Disc when scanning all titles' do
          # The details for this are tested in disc_spec
          cli.scan.should be_a HandBrake::Disc
        end

        it 'returns a Title when scanning one title' do
          # The details for this are tested in disc_spec
          runner.output = single_scan
          cli.title(2).scan.should be_a HandBrake::Title
        end
      end

      describe '#update' do
        it 'uses the --update argument' do
          cli.update
          runner.actual_arguments.should == %w(--update)
        end

        it 'returns true if the thing is up to date' do
          runner.output = 'Your version of HandBrake is up to date.'
          cli.update.should be_true
        end

        it 'returns false if the executable is out of date' do
          runner.output = 'You are using an old version of HandBrake.'
          cli.update.should be_false
        end
      end

      describe '#preset_list' do
        let(:sample_presets) { File.read(File.expand_path('../sample-preset-list.out', __FILE__)) }

        before do
          runner.output = sample_presets
        end

        it 'uses the --preset-list argument' do
          cli.preset_list
          runner.actual_arguments.should == %w(--preset-list)
        end

        it 'returns a hash containing all the categories' do
          cli.preset_list.keys.sort.should == %w(Apple Legacy Regular)
        end

        it 'returns a hash containing the presets in each category' do
          cli.preset_list['Regular'].keys.sort.should == ['High Profile', 'Normal']
        end

        it 'returns a hash containing the actual args for a particular preset' do
          cli.preset_list['Regular']['Normal'].should ==
            '-e x264  -q 20.0 -a 1 -E faac -B 160 -6 dpl2 -R Auto -D 0.0 -f mp4 --strict-anamorphic -m -x ref=2:bframes=2:subme=6:mixed-refs=0:weightb=0:8x8dct=0:trellis=0'
        end
      end
    end
  end

  describe CLI::PopenRunner do
    describe '#command' do
      subject { CLI::PopenRunner.new(CLI.new(:bin_path => '/foo/hbcli')) }

      it 'starts with the bin path' do
        subject.command(%w(--bar)).should =~ %r{^'/foo/hbcli'}
      end

      it 'quotes the arguments' do
        subject.command(%w(--bar)).should =~ %r{'--bar'}
      end

      it 'redirects stderr to stdout' do
        subject.command([]).should =~ %r{2>&1$}
      end

      it 'escapes single quotes in the arguments' do
        subject.command(["--output", "/quux/boo's.m4v"]).
          should == %('/foo/hbcli' '--output' '/quux/boo'\\''s.m4v' 2>&1)
      end
    end
  end
end
