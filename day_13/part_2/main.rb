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

class GameState
  JOYSTICK_POS = {
    left: -1,
    neutral: 0,
    right: 1
  }.freeze

  TILES = {
    EMPTY = 0 => ' ',
    WALL = 1 => '#',
    BLOCK = 2 => '%',
    PADDLE = 3 => '-',
    BALL = 4 => '.',
  }.freeze

  attr_reader :ball_pos, :paddle_pos

  def initialize
    @cells = {}
    @score = 0
    @joystick_position = :neutral
    @ball_pos = [0, 0]
    @paddle_pos = [0, 0]
  end

  def joystick_position
    JOYSTICK_POS.fetch(@joystick_position)
  end

  def joystick_left
    @joystick_position = :left
  end

  def joystick_right
    @joystick_position = :right
  end

  def joystick_neutral
    @joystick_position = :neutral
  end

  def score
    @score
  end

  def set_score(score)
    @score = score
  end

  def set_cell(x, y, tile_id)
    @cells[y] ||= {}
    @cells[y][x] = tile_id

    case tile_id
    when BALL then @ball_pos = [x, y]
    when PADDLE then @paddle_pos = [x, y]
    end
  end

  def draw
    yield "Score: #{score}."

    @cells.map do |y, row|
      yield row.values.map { |v| TILES.fetch(v) }.join
    end
  end
end

computer_output = Queue.new

instructions = read_instructions.tap { |i| i[0] = 2 }

game_state = GameState.new

computer_state = ComputerState.new(
  instructions.dup,
  proc { game_state.joystick_position },
  ->(v) { computer_output << v },
  clock_delay: 1 / 75_000.0,
)
computer = Thread.new { run_program(computer_state) }

game_state_updater = Thread.new do
  loop do
    x = computer_output.pop
    y = computer_output.pop
    block = computer_output.pop

    if x == -1 && y.zero?
      game_state.set_score(block)
    else
      game_state.set_cell(x, y, block)

      case game_state.ball_pos[0] <=> game_state.paddle_pos[0]
      when 1 then game_state.joystick_right
      when -1 then game_state.joystick_left
      else game_state.joystick_neutral
      end
    end
  end
end

display = Thread.new do
  Curses.init_screen
  begin
    win = Curses.stdscr

    loop do
      win.erase
      win << game_state.to_enum(:draw).to_a.join("\n")
      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

computer.join
display.join
