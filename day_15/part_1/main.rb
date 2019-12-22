require 'curses'
require 'io/console'
require 'set'

def read_instructions
  File.read(ARGV[0]).split(',').map(&:to_i)
end

class ComputerState
  ADDRESS_MODES = {
    0 => :position,
    1 => :immediate,
    2 => :relative
  }

  attr_accessor :clock_delay
  attr_reader :ops

  def initialize(instructions, read, write, clock_delay: 0)
    @memory = instructions.each_with_index.map { |x, i| [i, x] }.to_h
    @read = read
    @write = write
    @pc = 0
    @ops = 0
    @relative_base = 0
    @clock_delay = clock_delay
  end

  def resolve_instruction
    @ops += 1
    input = @memory.fetch(@pc).to_s

    n = [input.length, 2].min
    op, arg_io_types = resolve_op(input.slice!(-n, n).to_i)

    [op, arg_io_types, resolve_address_modes(input)]
  end

  def resolve_arguments(arg_io_types, address_modes)
    (1..arg_io_types.size).map { |arg_num|
      @memory.fetch(@pc + arg_num)
    }.each_with_index.map { |arg, i|
      writing = arg_io_types[i] == :w
      address_mode = address_modes.fetch(i, writing ? :immediate : :position)

      case address_mode
      when :immediate then arg
      when :relative then
        address = @relative_base + arg
        writing ? address : get(address)
      when :position then
        raise "Cannot use position mode with write-variable!" if writing

        get(arg)
      else raise "Unexpected address_mode: #{address_mode}"
      end
    }
  end

  def read
    @read.call
  end

  def write(value)
    @write.call(value)
  end

  def set(pos, value)
    @memory[pos] = value
  end

  def get(pos)
    raise ArgumentError, "Negative memory address: #{pos}" if pos.negative?

    @memory.fetch(pos, 0)
  end

  def incr_pc(n)
    @pc += n
  end

  def set_pc(value)
    @pc = value
  end

  def offset_relative_base(value)
    @relative_base += value
  end

  private def resolve_address_modes(mode_str)
    mode_str.chars.reverse.map(&:to_i).each_with_index.map { |c, i|
      [i, ADDRESS_MODES.fetch(c)]
    }.to_h
  end

  private def resolve_op(op_num)
    case op_num
    when 99 then [:break, 0]
    when 1 then [:+, %i[r r w]]
    when 2 then [:*, %i[r r w]]
    when 3 then [:read, %i[w]]
    when 4 then [:write, %i[r]]
    when 5 then [:jnz, %i[r r]]
    when 6 then [:jz, %i[r r]]
    when 7 then [:<, %i[r r w]]
    when 8 then [:==, %i[r r w]]
    when 9 then [:offset, %i[r]]
    else raise "Unexpected op_num: #{op_num}"
    end
  end
end

def run_program(state)
  loop do
    op, arg_io_types, address_modes = state.resolve_instruction

    break if op == :break

    *args, target = state.resolve_arguments(arg_io_types, address_modes)

    case op
    when :+, :*
      state.set(target, args[0].send(op, args[1]))
    when :read
      state.set(target, state.read)
    when :write
      state.write(target)
    when :jnz, :jz
      if args[0].zero? == (op == :jz)
        state.set_pc(target)
        next
      end
    when :<, :==
      state.set(target, args[0].send(op, args[1]) ? 1 : 0)
    when :offset
      state.offset_relative_base(target)
    else raise "Unhandled op: #{op}!"
    end

    sleep(state.clock_delay)

    state.incr_pc(arg_io_types.size + 1)
  end
end

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

class Grid
  TILES = {
    WALL = 0 => '#',
    EMPTY = 1 => ' ',
    OXYGEN = 2 => '✓',
    UNKNOWN = 3 => '▒',
    ROBOT = 4 => '✈',
    MARKED = 5 => '~'
  }.freeze

  def initialize
    @cells = { 0 => { 0 => EMPTY } }
  end

  def draw(width, height, robot_pos, path_length)
    x_range = (-width/2...width/2)
    y_range = (-height/2...height/2)

    map_lines = y_range.map do |y|
      x_range.map do |x|
        pos = Pos.new(x, y)
        cell = tile(pos)
        cell = ROBOT if robot_pos == pos && ![OXYGEN, MARKED].include?(cell)

        TILES.fetch(cell)
      end.join
    end

    ["Pos: #{robot_pos}, path_length: #{path_length}", map_lines].join("\n")
  end

  def tile(pos)
    (@cells[pos.y] || {})[pos.x] || UNKNOWN
  end

  def find_each(target_tile)
    return to_enum(__method__, target_tile) unless block_given?

    @cells.each do |y, row|
      row.each do |x, tile|
        yield Pos.new(x, y) if tile == target_tile
      end
    end
  end

  def wall?(pos)
    tile(pos) == WALL
  end

  def mark(pos, tile)
    @cells[pos.y] ||= {}
    @cells[pos.y][pos.x] = tile
  end
end

class GameState
  DIRECTIONS = {
    UP = :up => 1,
    DOWN = :down => 2,
    LEFT = :left => 3,
    RIGHT = :right => 4,
  }.freeze

  REVERSE_DIRECTIONS = {
    LEFT => RIGHT,
    RIGHT => LEFT,
    UP => DOWN,
    DOWN => UP
  }.freeze

  attr_reader :grid

  def initialize
    @grid = Grid.new
    @robot_pos = Pos.new(0, 0)
    @path_length = 0
  end

  def draw(width, height)
    @grid.draw(width, height, @robot_pos, @path_length)
  end

  def move_dirs(pos)
    DIRECTIONS
      .keys
      .map { |dir| [dir, pos.send(dir)] }
      .to_h
      .reject { |_, new_pos| @grid.wall?(new_pos) }
  end

  def dfs_explore(&block)
    return_path = []
    visited = {}

    loop do
      dir, new_pos = next_forward_dfs_move(visited, return_path)

      break if dir.nil? && return_path.empty?

      is_forward = !dir.nil?
      dir, new_pos = return_path.pop unless is_forward

      visited[@robot_pos] ||= []
      visited[@robot_pos] << dir

      tile = yield DIRECTIONS.fetch(dir)

      @grid.mark(new_pos, tile)

      next if @grid.wall?(new_pos)

      return_path << [REVERSE_DIRECTIONS.fetch(dir), @robot_pos] if is_forward
      @robot_pos = new_pos
    end
  end

  def bfs_for_oxygen
    visited = Set.new([])
    current_positions = Set.new([@robot_pos])

    oxygen_pos = @grid.find_each(Grid::OXYGEN).to_a.first

    until current_positions.include?(oxygen_pos)
      @path_length += 1

      visited += current_positions

      current_positions = current_positions.flat_map do |pos|
        move_dirs(pos).map { |md| md[1] }.reject { |new_pos| visited.include?(new_pos) }
      end.to_set

      current_positions.each { |pos| @grid.mark(pos, Grid::MARKED) }

      sleep(1 / 60.0)
    end
  end

  private def next_forward_dfs_move(visited, return_path)
    return_dir, _ = return_path.last

    move_dirs(@robot_pos).reject { |dir, _new_pos|
      (visited[@robot_pos] || []).include?(dir) || dir == return_dir
    }.first
  end
end

computer_input = Queue.new
computer_output = Queue.new

instructions = read_instructions

game_state = GameState.new

computer_state = ComputerState.new(
  instructions.dup,
  proc { computer_input.pop },
  ->(v) { computer_output << v },
  clock_delay: (1 / 75_000.0)
)
computer = Thread.new { run_program(computer_state) }

game_state_updater = Thread.new do
  game_state.dfs_explore do |input|
    computer_input << input

    computer_output.pop
  end

  game_state.bfs_for_oxygen
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
      win << game_state.draw(41, 41)
      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

computer.join
display.join
