require File.expand_path('../../spec_helper.rb', __FILE__)

module HandBrake
  describe Disc do
    let(:body) { File.read(File.expand_path('../sample-titles-scan.err', __FILE__)) }
    let(:disc) { Disc.from_output(body) }
    let(:titles) { disc.titles }

    describe '#titles' do
      it 'contains all the titles' do
        titles.size.should == 5
      end

      it 'indexes the titles correctly' do
        titles[3].number.should == 3
      end

      it 'is enumerable' do
        titles.collect { |k, v| k }.sort.should == [1, 2, 3, 6, 11]
      end
    end

    it 'extracts the name' do
      disc.name.should == 'D2'
    end

    it 'contains a reference to the full output' do
      disc.raw_output.should == body
    end

    describe "#raw_tree" do
      let(:tree) { disc.raw_tree }

      it 'has the raw values at the top level of nodes' do
        tree.children.collect { |c| c.name }.should ==
          ['title 1:', 'title 2:', 'title 3:', 'title 6:', 'title 11:']
      end

      it 'has the raw values at the second level' do
        tree['title 11:'][3].name.should == 'autocrop: 0/0/0/0'
      end

      it 'has the raw values at the third level' do
        tree['title 3:']['audio tracks:'][1].name.should ==
          '2, Francais (AC3) (Dolby Surround) (iso639-2: fra), 48000Hz, 192000bps'
      end
    end

    describe 'YAML serialization' do
      describe 'round trip' do
        let(:yaml) { disc.to_yaml }
        let(:reloaded) { YAML.load(yaml) }

        it 'does not include the raw output' do
          reloaded.raw_output.should be_nil
        end

        it 'does not include the raw tree' do
          reloaded.raw_tree.should be_nil
        end

        it 'preserves the name' do
          reloaded.name.should == 'D2'
        end

        it 'preserves the titles' do
          reloaded.titles.size.should == 5
        end

        it 'preserves the backreference from a title to the disc' do
          pending "Psych issue #19" if RUBY_VERSION =~ /1.9/
          reloaded.titles[1].disc.should eql(reloaded)
        end

        it 'preserves the chapters' do
          reloaded.titles[3].chapters.size.should == 13
        end

        it 'preserves the backreference from a chapter to its title' do
          pending "Psych issue #19" if RUBY_VERSION =~ /1.9/
          title_1 = reloaded.titles[1]
          title_1.chapters[4].title.should eql(title_1)
        end
      end
    end
  end

  describe Title do
    let(:body) { File.read(File.expand_path('../sample-titles-scan.err', __FILE__)) }
    let(:disc) { Disc.from_output(body) }
    let(:titles) { disc.titles }

    let(:title_1) { titles[1] }
    let(:title_3) { titles[3] }

    it 'has a reference to its parent disc' do
      title_1.disc.should be disc
    end

    describe '#initialize' do
      describe 'without a hash' do
        it 'works' do
          lambda { Title.new }.should_not raise_error
        end
      end

      describe 'with a hash' do
        it 'can set settable properties' do
          Title.new(:number => 5, :duration => '01:45:35').number.should == 5
        end

        it 'fails for an unknown property' do
          lambda { Title.new(:foo => 'bar') }.
            should raise_error('No property :foo in HandBrake::Title')
        end
      end
    end

    describe '#main_feature?' do
      it 'is true when it is' do
        title_1.should be_main_feature
      end

      it 'is false when it is' do
        title_3.should_not be_main_feature
      end

      it 'is not a complex value when true, so that serializations are simpler' do
        title_1.main_feature?.should == true
      end
    end

    it 'has the number' do
      title_1.number.should == 1
    end

    it 'has the duration' do
      title_3.duration.should == '01:43:54'
    end

    it 'has the duration in seconds' do
      title_3.seconds.should == 6234
    end

    it 'has the right number of chapters' do
      title_3.should have(13).chapters
    end

    it 'has chapters indexed by chapter number' do
      title_3.chapters[2].tap do |c|
        c.duration.should == '00:00:52'
        c.number.should == 2
      end
    end

    it 'has an array of the chapters in order' do
      title_3.all_chapters.collect { |ch| ch.number }.should == (1..13).to_a
    end

    describe 'a chapter' do
      let(:chapter) { title_3.chapters[5] }

      it 'has the duration' do
        chapter.duration.should == '00:03:23'
      end

      it 'has the duration in seconds' do
        chapter.seconds.should == 203
      end

      it 'has the number' do
        chapter.number.should == 5
      end

      it 'has a reference to its parent' do
        chapter.title.should eql title_3
      end
    end
  end

  describe Chapter do
    describe '#initialize' do
      describe 'without a hash' do
        it 'works' do
          lambda { Chapter.new }.should_not raise_error
        end
      end

      describe 'with a hash' do
        it 'can set settable properties' do
          Chapter.new(:number => 5, :duration => '01:45:35').duration.should == '01:45:35'
        end

        it 'fails for an unknown property' do
          lambda { Chapter.new(:foo => 'bar') }.
            should raise_error('No property :foo in HandBrake::Chapter')
        end
      end
    end
  end
end
