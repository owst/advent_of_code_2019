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

Portal = Struct.new(:identifier, :pos)

class Grid
  def initialize(cells)
    @cells = cells
  end

  def draw(path_length)
    (["Path Length: #{path_length}", ""] + @cells.map(&:join)).map { |s| s + "\n" }.join
  end

  def mark_visited(pos)
    @cells[pos.y][pos.x] = '@'
  end
end

class GameState
  DIRECTIONS = [
    UP = :up,
    DOWN = :down,
    LEFT = :left,
    RIGHT = :right
  ].freeze

  attr_reader :grid

  def self.vertical_portals(line_chars)
    return to_enum(__method__, line_chars) unless block_given?

    line_chars.each_with_index.each_cons(3) do |(l1, y1), (l2, _y2), (l3, y3)|
      [l1, l2, l3].reduce(:zip).map(&:flatten).each_with_index do |(c1, c2, c3), x|
      case str = [c1, c2, c3].join
      when /[A-Z]{2}\./ then yield Portal.new(str[0, 2], Pos.new(x, y3))
      when /\.[A-Z]{2}/ then yield Portal.new(str[1, 2], Pos.new(x, y1))
      end
    end
    end
  end

  def self.horizontal_portals(line_chars)
    return to_enum(__method__, line_chars) unless block_given?

    line_chars.each_with_index do |chars, y|
      chars.each_with_index.each_cons(3) do |(c1, x1), (c2, _x2), (c3, x3)|
        case str = [c1, c2, c3].join
        when /[A-Z]{2}\./ then yield Portal.new(str[0, 2], Pos.new(x3, y))
        when /\.[A-Z]{2}/ then yield Portal.new(str[1, 2], Pos.new(x1, y))
        end
      end
    end
  end

  def self.parse_map(input = nil)
    input ||= $stdin.read

    line_chars = input.split("\n").map(&:chars)

    portals =
      (vertical_portals(line_chars).to_a + horizontal_portals(line_chars).to_a)
      .group_by(&:identifier)
      .transform_values { |group| group.map(&:pos) }

    open_passage_positions = line_chars.each_with_index.flat_map do |chars, y|
      chars.each_with_index.flat_map do |char, x|
        char == '.' ? [Pos.new(x, y)] : []
      end
    end

    [portals, open_passage_positions, line_chars]
  end

  def initialize(input = nil)
    @portals_by_name, @open_passage_positions, grid_cells = self.class.parse_map(input)
    @portals_by_pos =
      @portals_by_name.flat_map { |name, positions| positions.map { |p| [p, name] } }.to_h
    @grid = Grid.new(grid_cells)
    @path_length = 0
  end

  def draw
    @grid.draw(@path_length)
  end

  def one_step_moves(pos)
    open_passage_new_positions =
      DIRECTIONS
      .map { |dir| pos.send(dir) }
      .select { |new_pos| @open_passage_positions.include?(new_pos) }

    portal_new_positions = if @portals_by_pos.key?(pos)
                             @portals_by_name.fetch(
                               @portals_by_pos.fetch(pos)
                             ).reject { |new_pos| new_pos == pos }
                           else
                             []
                           end

    open_passage_new_positions + portal_new_positions
  end

  def bfs_paths
    bfs(@portals_by_name.fetch("AA").first) do |pos|
      @grid.mark_visited(pos)

      break if pos == @portals_by_name.fetch("ZZ").first
    end
  end

  private def bfs(start_point)
    @path_length = 0

    visited = Set.new([])
    current_positions = Set.new([start_point])

    loop do
      visited += current_positions

      current_positions = current_positions.flat_map do |pos|
        one_step_moves(pos).reject { |new_pos| visited.include?(new_pos) }
      end.to_set

      break if current_positions.empty?

      @path_length += 1

      current_positions.each { |pos| yield pos }

      sleep(1 / 60.0)
    end
  end
end

game_state = GameState.new

game_state_updater = Thread.new do
  game_state.bfs_paths
end

display = Thread.new do
  Curses.init_screen
  begin
    win = Curses.stdscr
    win.timeout = 0
    win.keypad = true
    Curses.curs_set(0)

    loop do
      win.erase
      win << game_state.draw
      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

display.join
