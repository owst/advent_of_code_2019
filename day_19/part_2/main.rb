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

size = 100
last_lines = []

grid_updater = Thread.new do
  pulling = ->(x, y) do
    computer_input << x
    computer_input << y

    computer_output.pop.to_i == 1
  end

  initial_y_guess = size * 9

  (initial_y_guess..Float::INFINITY).each do |y|
    print "\rChecking #{y}"
    _, previous_first_col, previous_last_col = last_lines.last

    start_x = previous_first_col || y - 1
    first_pulling_col = (start_x..Float::INFINITY).find { |x| pulling.call(x, y) }

    next unless first_pulling_col

    start_x = [previous_last_col, first_pulling_col].compact.max
    last_pulling_col = (start_x..Float::INFINITY).take_while { |x| pulling.call(x, y) }.last

    last_lines.push [y, first_pulling_col, last_pulling_col]

    last_start = last_lines.last[1]

    break if last_lines.size >= size && last_lines.last(size).all? { |_, prev_start, prev_end|
      prev_start <= last_start && prev_end >= (last_start + size - 1)
    }
  end

  y = last_lines[-100][0]
  x = last_lines.last[1]

  puts "\nFinished"
  puts x * 10_000 + y
end

grid_updater.join
