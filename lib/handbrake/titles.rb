require 'tree'

require 'handbrake'

module HandBrake
  class Titles < Hash
    attr_reader :raw_output, :raw_tree

    def initialize(output)
      @raw_output = output
      @raw_tree = extract_tree
      raw_tree.children.collect { |title_node| Title.new(title_node) }.each do |title|
        self[title.number] = title
      end
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

    attr_reader :number, :duration, :chapters

    def initialize(title_node)
      @node = title_node
      @number = title_node.name.scan(/title (\d+)/).first.first.to_i
      @duration = title_node.children.
        detect { |c| c.name =~ /duration/ }.name.
        scan(/duration: (\d\d:\d\d:\d\d)/).first.first
      @chapters = title_node['chapters:'].children.collect { |ch_node| Chapter.new(ch_node) }
    end

    def main_feature?
      @node.children.detect { |c| c.name =~ /Main Feature/ }
    end
  end

  class Chapter
    include DurationAsSeconds

    attr_reader :duration

    def initialize(chapter_node)
      @node = chapter_node
      @duration = chapter_node.name.scan(/duration (\d\d:\d\d:\d\d)/).first.first
    end
  end
end
