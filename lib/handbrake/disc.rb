require 'tree'

require 'handbrake'

module HandBrake
  ##
  # An object representation of the output from HandBrakeCLI's
  # `--scan` mode.
  #
  # @see Title
  # @see Chapter
  class Disc
    ##
    # The HandBrakeCLI scan output from which this instance was
    # parsed, if available.
    #
    # @return [String,nil]
    attr_reader :raw_output

    ##
    # A tree representing the indented output at the end of the
    # HandBrakeCLI scan output, if available.
    #
    # @return [String,nil]
    attr_reader :raw_tree

    ##
    # The titles in the disc. The keys are the title numbers.
    #
    # @return [Hash<Fixnum, Title>]
    attr_reader :titles

    ##
    # The name of the disc.
    #
    # @return [String]
    attr_accessor :name

    def initialize(name=nil)
      @name = name
      @titles = {}
    end

    ##
    # Builds a new {Disc} instance from the output of `HandBrakeCLI
    # --scan`.
    #
    # @param [String] output the raw contents from the scan
    # @return [Disc] a new, completely initialized title catalog
    def self.from_output(output)
      name = File.basename(
        output.split("\n").grep(/hb_scan/).first.scan(/path=([^,]*),/).first.first)
      self.new(name).tap do |disc|
        disc.raw_output = output
        disc.raw_tree.children.
          collect { |title_node| Title.from_tree(title_node) }.
          each { |title| title.disc = disc }.
          each { |title| disc.titles[title.number] = title }
      end
    end

    ##
    # Initializes the {#raw_output} and {#raw_tree} attributes from
    # the given HandBrakeCLI output. Does not modify the contents of
    # the hash.
    #
    # @param [String] output raw contents from a HandBrakeCLI title
    #   scan
    # @return [void]
    def raw_output=(output)
      @raw_output = output
      @raw_tree = extract_tree
    end

    def to_yaml_properties
      %w(@name  @titles)
    end

    private

    def extract_tree
      split_blocks(
        raw_output.split("\n").grep(/^\s*\+/), ''
      ).inject(Tree::TreeNode.new('__root__')) do |root, block|
        root << read_node(block, '')
        root
      end
    end

    def split_blocks(lines, indent_level)
      lines.inject([]) do |blocks, line|
        blocks << [] if line =~ /^#{indent_level}\+/

        blocks.last << line
        blocks
      end
    end

    def read_node(node_lines, indent_level)
      next_indent = indent_level + '  '
      split_blocks(
        node_lines[1..-1], next_indent
      ).inject(Tree::TreeNode.new(node_lines.first[(2 + indent_level.size)..-1])) do |node, block|
        node << read_node(block, next_indent)
        node
      end
    end
  end

  ##
  # Provides a {#seconds} method for an object which has a `duration`
  # property whose value is a string of the format "hh:mm:ss"
  module DurationAsSeconds
    ##
    # The number of seconds described by the duration. E.g., if the
    # duration were `"1:02:42"`, this method would return `3762`.
    #
    # @return [Fixnum]
    def seconds
      @seconds ||= duration.split(':').collect(&:to_i).reverse.
        inject([1, 0]) { |(m, sum), i| [m * 60, sum + i * m] }.last
    end
  end

  ##
  # Mix-in that provides a class with a constructor that sets any
  # publicly writable properties from values in a hash.
  module ConstructWithProperties
    def initialize(properties={})
      properties.each do |prop, value|
        setter = :"#{prop}="
        if self.respond_to?(setter)
          self.send(setter, value)
        else
          fail("No property #{prop.inspect} in #{self.class}")
        end
      end
    end
  end

  ##
  # Metadata about a single DVD title.
  class Title
    include DurationAsSeconds
    include ConstructWithProperties

    ##
    # @return [Fixnum] The title number of this title (a positive integer).
    attr_accessor :number

    ##
    # @return [String] The duration of the title in the format
    #   "hh:mm:ss"
    attr_accessor :duration

    ##
    # @return [Array<Chapter>] The chapters into which the title is
    #   divided.
    attr_writer :chapters

    ##
    # @return [Boolean] Whether HandBrake considers this title the
    #   "main feature".
    attr_writer :main_feature

    ##
    # @return [Disc] The disc this title belongs to.
    attr_accessor :disc

    ##
    # Creates a new instance from the given scan subtree.
    #
    # @see Titles.from_output
    # @param [Tree::TreeNode] title_node
    # @return [Title] a new, fully initialized instance
    def self.from_tree(title_node)
      self.new.tap do |title|
        title.number = title_node.name.scan(/title (\d+)/).first.first.to_i
        title.duration = title_node.children.
          detect { |c| c.name =~ /duration/ }.name.
          scan(/duration: (\d\d:\d\d:\d\d)/).first.first
        title.chapters = title_node['chapters:'].children.
          collect { |ch_node| Chapter.from_tree(ch_node) }.
          tap { |chapters| chapters.each { |c| c.title = title } }.
          inject({}) { |h, ch| h[ch.number] = ch; h }
        # !! is so that there's no reference to the node in the
        # resulting object
        title.main_feature = !!title_node.children.detect { |c| c.name =~ /Main Feature/ }
      end
    end

    ##
    # @return [Boolean] Whether HandBrake considers this title the
    #   "main feature".
    def main_feature?
      @main_feature
    end

    ##
    # @return [Hash<Fixnum,Chapter>] The chapters into which the title is
    #   divided, indexed by chapter number (a positive integer).
    def chapters
      @chapters ||= {}
    end

    ##
    # @return [Array<Chapter>] The chapters of the title, sorted by
    #   chapter number.
    def all_chapters
      chapters.keys.sort.collect { |k| chapters[k] }
    end
  end

  ##
  # The metadata about a single chapter in a title of a DVD.
  class Chapter
    include DurationAsSeconds
    include ConstructWithProperties

    ##
    # @return [String] The duration of the title in the format
    #   "hh:mm:ss"
    attr_accessor :duration

    ##
    # @return [Fixnum] The chapter number for this chapter (a positive
    #   integer)
    attr_accessor :number

    ##
    # @return [Title] The title that contains this chapter
    attr_accessor :title

    ##
    # Creates a new instance from the given title subtree.
    #
    # @see Title.from_tree
    # @param [Tree::TreeNode] chapter_node
    # @return [Chapter] a new, fully initialized instance
    def self.from_tree(chapter_node)
      self.new.tap do |ch|
        ch.duration = chapter_node.name.scan(/duration (\d\d:\d\d:\d\d)/).first.first
        ch.number = chapter_node.name.scan(/(\d+): cells/).first.first.to_i
      end
    end
  end
end
