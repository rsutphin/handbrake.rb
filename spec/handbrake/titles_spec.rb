require File.expand_path('../../spec_helper.rb', __FILE__)

module HandBrake
  describe Titles do
    let(:body) { File.read(File.expand_path('../sample-titles-scan.err', __FILE__)) }
    let(:titles) { Titles.from_output(body) }

    it 'contains all the titles' do
      titles.size.should == 5
    end

    it 'indexes the titles correctly' do
      titles[3].number.should == 3
    end

    it 'is enumerable' do
      titles.collect { |k, v| k }.sort.should == [1, 2, 3, 6, 11]
    end

    it 'contains a reference to the full output' do
      titles.raw_output.should == body
    end

    describe "#raw_tree" do
      let(:tree) { titles.raw_tree }

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
  end

  describe Title do
    let(:body) { File.read(File.expand_path('../sample-titles-scan.err', __FILE__)) }
    let(:titles) { Titles.from_output(body) }

    let(:title_1) { titles[1] }
    let(:title_3) { titles[3] }

    describe '#main_feature?' do
      it 'is true when it is' do
        title_1.should be_main_feature
      end

      it 'is false when it is' do
        title_3.should_not be_main_feature
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
    end
  end
end
