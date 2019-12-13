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

class RobotState
  DIRECTION_TURNS = {
    UP = :up => [0, -1],
    LEFT = :left => [-1, 0],
    DOWN = :down => [0, 1],
    RIGHT = :right => [1, 0]
  }

  attr_reader :painted, :white_cells

  def initialize(x, y, init_colour: :black)
    @debug = false
    @x = x
    @y = y
    @direction = UP
    @painted = Set.new([])
    @white_cells = Set.new([])
    @white_cells << current_cell if init_colour == :white
  end

  def current_cell
    [@x, @y]
  end

  def colour
    @white_cells.include?(current_cell) ? :white : :black
  end

  def paint(colour)
    puts "painting #{colour}" if @debug

    if colour == :white
      @white_cells << current_cell
    else
      @white_cells.delete(current_cell)
    end

    @painted << current_cell
  end

  def turn(lr)
    puts "moving #{lr} from #{@direction} at #{[@x, @y]}" if @debug
    offset = lr == :left ? 1 : -1

    index = DIRECTION_TURNS.keys.index(@direction)

    @direction = DIRECTION_TURNS.keys[(index + offset) % 4]

    dx, dy = DIRECTION_TURNS.fetch(@direction)

    @x += dx
    @y += dy

    puts "now at #{[@x, @y]} facing #{@direction}" if @debug
  end
end

input = Queue.new
output = Queue.new

instructions = read_instructions

computer = Thread.new {
  run_program(instructions.dup, proc { input.pop }, ->(v) { output << v })
}

robot_state = RobotState.new(2, 2, init_colour: :white)

while computer.status
  input << (robot_state.colour == :black ? 0 : 1)

  robot_state.paint(output.pop.zero? ? :black : :white)
  robot_state.turn(output.pop.zero? ? :left : :right)
end

cols, rows = robot_state.painted.reduce([0, 0]) do |(mx, my), (x, y)|
  [[mx, x].max, [my, y].max]
end

(0..rows).each do |row|
  (0..cols).each do |col|
    print robot_state.white_cells.include?([col, row]) ? '#' : '.'
  end

  print "\n"
end
