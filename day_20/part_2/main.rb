require 'curses'
require 'set'

Pos = Struct.new(:x, :y) do
  def to_s
    "<#{x}, #{y}>"
  end

  alias inspect to_s

  def up
    self.class.new(x, y - 1)
  end

  def down
    self.class.new(x, y + 1)
  end

  def left
    self.class.new(x - 1, y)
  end

  def right
    self.class.new(x + 1, y)
  end
end

PosLevel = Struct.new(:pos, :level) do
  def to_s
    pos.to_s + " @ " + level.to_s
  end

  alias inspect to_s
end

Portal = Struct.new(:name, :pos, :inner)

class GameState
  DIRECTIONS = [
    UP = :up,
    DOWN = :down,
    LEFT = :left,
    RIGHT = :right
  ].freeze

  def self.vertical_portals(line_chars)
    return to_enum(__method__, line_chars) unless block_given?

    height = line_chars.size

    line_chars.each_with_index.each_cons(3) do |(l1, y1), (l2, _y2), (l3, y3)|
      [l1, l2, l3].reduce(:zip).map(&:flatten).each_with_index do |(c1, c2, c3), x|
        case str = [c1, c2, c3].join
        when /[A-Z]{2}\./ then yield Portal.new(str[0, 2], Pos.new(x, y3), !y1.zero?)
        when /\.[A-Z]{2}/ then yield Portal.new(str[1, 2], Pos.new(x, y1), y3 != height - 1)
        end
      end
    end
  end

  def self.horizontal_portals(line_chars)
    return to_enum(__method__, line_chars) unless block_given?

    width = line_chars.map(&:size).max

    line_chars.each_with_index do |chars, y|
      chars.each_with_index.each_cons(3) do |(c1, x1), (c2, _x2), (c3, x3)|
        case str = [c1, c2, c3].join
        when /[A-Z]{2}\./ then yield Portal.new(str[0, 2], Pos.new(x3, y), !x1.zero?)
        when /\.[A-Z]{2}/ then yield Portal.new(str[1, 2], Pos.new(x1, y), x3 != width - 1)
        end
      end
    end
  end

  def self.parse_map(input = nil)
    input ||= ARGF.read

    line_chars = input.split("\n").map(&:chars)

    portals = vertical_portals(line_chars).to_a + horizontal_portals(line_chars).to_a

    open_passage_positions = line_chars.each_with_index.flat_map do |chars, y|
      chars.each_with_index.flat_map do |char, x|
        char == '.' ? [Pos.new(x, y)] : []
      end
    end

    [portals, open_passage_positions.to_set, line_chars]
  end

  def initialize(input = nil)
    portals, @open_passage_positions, grid_cells = self.class.parse_map(input)
    @portals_by_name = portals.group_by(&:name)
    @portals_by_pos = portals.group_by(&:pos).transform_values(&:first)
  end

  def one_step_moves(visited, pos_level, &block)
    DIRECTIONS.map { |dir| pos_level.pos.send(dir) }.select { |new_pos|
      @open_passage_positions.include?(new_pos)
    }.each { |new_pos|
      new_pos_level = PosLevel.new(new_pos, pos_level.level)

      yield new_pos_level unless visited.include?(new_pos_level)
    }

    follow_portal(visited, pos_level, &block)
  end

  def bfs_paths
    find_pos = ->(name) {
      @portals_by_name.fetch(name).tap { |r| raise "urk" if r.length != 1 }.first.pos
    }

    init = PosLevel.new(find_pos.call("AA"), 0)
    final = PosLevel.new(find_pos.call("ZZ"), 0)

    current_positions = [[init, 0]]
    visited = Set.new([init])

    until current_positions.empty?
      pos_level, path_length = current_positions.shift

      return path_length if pos_level == final

      one_step_moves(visited, pos_level) do |new_pos_level|
        visited << new_pos_level

        current_positions.push([new_pos_level, path_length + 1])
      end
    end
  end

  private def follow_portal(visited, pos_level)
    return unless @portals_by_pos.key?(pos_level.pos)

    name = @portals_by_pos.fetch(pos_level.pos).name

    return if %w[AA ZZ].include?(name)

    portal_in, portal_out =
      @portals_by_name.fetch(name).partition { |portal| portal.pos == pos_level.pos }.map(&:first)
    new_level = pos_level.level + (portal_in.inner ? 1 : -1)

    return if new_level.negative? || new_level > 30

    new_pos_level = PosLevel.new(portal_out.pos, new_level)

    yield new_pos_level unless visited.include?(new_pos_level)
  end
end

game_state = GameState.new
p game_state.bfs_paths
