require 'curses'
require 'io/console'
require 'set'

def read_instructions
  File.read(ARGV[0]).split(',').map(&:to_i)
end

class State
  ADDRESS_MODES = {
    0 => :position,
    1 => :immediate,
    2 => :relative
  }

  def initialize(instructions, read, write)
    @memory = instructions.each_with_index.map { |x, i| [i, x] }.to_h
    @read = read
    @write = write
    @pc = 0
    @relative_base = 0
  end

  def resolve_instruction
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

def run_program(instructions, read, write)
  state = State.new(instructions, read, write)

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

    state.incr_pc(arg_io_types.size + 1)
  end
end

class GameState
  JOYSTICK_POS = {
    left: -1,
    neutral: 0,
    right: 1
  }.freeze

  TILES = {
    0 => ' ',
    1 => '#',
    2 => '%',
    3 => '-',
    4 => '.',
  }.freeze

  def initialize
    @cells = {}
    @score = 0
    @joystick_position = :neutral
    @cell_sets = 0
  end

  def joystick_position
    JOYSTICK_POS.fetch(@joystick_position)
  end

  def score
    @score
  end

  def set_score(score)
    @score = score
  end

  def set_cell(x, y, tile_id)
    @cell_sets += 1
    @cells[y] ||= {}
    @cells[y][x] = tile_id
  end

  def draw
    yield "Score: #{score}. Cell sets: #{@cell_sets}"

    @cells.map do |y, row|
      yield row.values.map { |v| TILES.fetch(v) }.join
    end
  end
end

input = Queue.new
output = Queue.new
display_events = Queue.new

instructions = read_instructions.tap { |i| i[0] = 2 }

game_state = GameState.new

# computer = Thread.new {
#   run_program(instructions.dup, proc { game_state.joystick_position }, ->(v) { output << v })
# }

computer = Thread.new {
  (1..2).each do |v|
    (0..20).each do |col|
      (0..10).each do |row|
        output << col
        output << row
        output << v
      end
    end
  end
}

game = Thread.new do
  count = 0

  loop do
    x = output.pop
    y = output.pop
    block = output.pop

    if x == -1 && y.zero?
      game_state.set_score(block)
    else
      game_state.set_cell(x, y, block)
    end

    count += 1

    display_events << count
  end
end

display = Thread.new do
  Curses.init_screen
  begin
    nb_lines = Curses.lines
    nb_cols = Curses.cols

    win = Curses.stdscr

    loop do
      event = display_events.pop
      sleep 0.1
      win.clear
      game_state.draw do |line|
        win << line
        win << "\n"
      end
      win.refresh
    end
  ensure
    Curses.close_screen
  end
end

while computer.status || display.status
end
