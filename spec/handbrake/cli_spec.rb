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
  end
end
