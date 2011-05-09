require 'tree'

require 'handbrake'

module HandBrake
  class Titles < Hash
    attr_accessor :raw_output, :raw_tree

    def self.from_output(output)
      self.new.tap do |titles|
        titles.raw_output = output
        titles.raw_tree.children.
          collect { |title_node| Title.from_tree(title_node) }.
          each { |title| titles[title.number] = title }
      end
    end

    def raw_output=(output)
      @raw_output = output
      @raw_tree = extract_tree
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

  module DurationAsSeconds
    def seconds
      @seconds ||= duration.split(':').collect(&:to_i).reverse.
        inject([1, 0]) { |(m, sum), i| [m * 60, sum + i * m] }.last
    end
  end

  class Title
    include DurationAsSeconds

    attr_accessor :number, :duration, :chapters
    attr_writer :main_feature

    def self.from_tree(title_node)
      self.new.tap do |title|
        title.number = title_node.name.scan(/title (\d+)/).first.first.to_i
        title.duration = title_node.children.
          detect { |c| c.name =~ /duration/ }.name.
          scan(/duration: (\d\d:\d\d:\d\d)/).first.first
        title.chapters = title_node['chapters:'].children.
          collect { |ch_node| Chapter.from_tree(ch_node) }
        title.main_feature = title_node.children.detect { |c| c.name =~ /Main Feature/ }
      end
    end

    def main_feature?
      @main_feature
    end

    def chapters
      @chapters ||= []
    end
  end

  class Chapter
    include DurationAsSeconds

    attr_accessor :duration

    def self.from_tree(chapter_node)
      self.new.tap do |ch|
        ch.duration = chapter_node.name.scan(/duration (\d\d:\d\d:\d\d)/).first.first
      end
    end
  end
end
