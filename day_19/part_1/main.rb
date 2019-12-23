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
    NOTHING = 0 => '.',
    PULLING = 1 => '#',
    DEFAULT = 2 => ' ',
  }.freeze

  attr_reader :width, :height

  def initialize(width, height)
    @width = width
    @height = height
    @cells = {}
  end

  def each_drawn_line
    total_pull_count = 0
    (0...@height).map do |y|
      pull_count = 0

      line = (0...@width).map do |x|
        cell = cell(Pos.new(x, y))
        pull_count += 1 if cell == PULLING
        TILES.fetch(cell)
      end.join + " #{y}: #{pull_count}"

      yield line

      total_pull_count += pull_count
    end

    yield "\n#{' ' * (@width - 3)} Total: #{total_pull_count}"
  end

  def cell(pos)
    (@cells[pos.y] || {})[pos.x] || DEFAULT
  end

  def mark(pos, tile)
    raise "Bad tile #{tile}" unless TILES.key?(tile)

    @cells[pos.y] ||= {}
    @cells[pos.y][pos.x] = tile
  end
end

computer_input = Queue.new
computer_output = Queue.new

instructions = read_instructions

read = proc { computer_input.pop }
write = ->(v) { computer_output << v }

computer = Thread.new do
  loop do
    run_program(ComputerState.new(instructions, read, write))
  end
end

grid = Grid.new(50, 50)

grid_updater = Thread.new do
  grid.height.times do |y|
    grid.width.times do |x|
      computer_input << x
      computer_input << y

      grid.mark(Pos.new(x, y), computer_output.pop.to_i)
    end
  end
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
      grid.each_drawn_line do |line|
        win << line + "\n"
      end
      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

computer.join
display.join
