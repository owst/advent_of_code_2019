require 'curses'
require 'awesome_print'
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
  op_count = 0

  loop do
    op, arg_io_types, address_modes = state.resolve_instruction

    op_count += 1

    break if op == :break

    *args, target = state.resolve_arguments(arg_io_types, address_modes)

    # if op_count % 10 == 0
    #   "op_count: #{op_count}\n".chars.map(&:ord).each do |i|
    #     state.write(i)
    #   end
    # end

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

NetworkComputer = Struct.new(:thread, :input, :output)

class InputEnumerator
  def initialize(address, queue)
    @address = address
    @queue = queue
    @next = nil
  end

  def next
    if @next
      value = @next
      @next = nil
      value
    elsif @queue.empty?
      -1
    else
      current, @next = @queue.pop

      current
    end
  end
end

class OutputEnumerator
  def initialize(queue)
    @queue = queue
    @pending = []
  end

  def <<(value)
    if @pending.size == 2
      address, x = @pending
      y = value
      @pending = []

      @queue << [address, x, y]
    else
      @pending << value
    end
  end
end

instructions = read_instructions

network_computers = (0..49).map do |address|
  input = Queue.new
  input_enum = InputEnumerator.new(address, input)
  output = Queue.new
  output_enum = OutputEnumerator.new(output)

  input << address

  computer_state = ComputerState.new(
    instructions.dup,
    proc { input_enum.next },
    ->(v) { output_enum << v },
    clock_delay: 0
  )

  [address, NetworkComputer.new(Thread.new { run_program(computer_state) }, input, output)]
end.to_h

y_255 = nil

network_computers.each_value.map do |network_computer|
  Thread.new do
    while y_255.nil? do
      address, x, y = network_computer.output.pop

      if address == 255
        y_255 = y

        break
      end

      network_computers.fetch(address).yield_self do |recipient|
        recipient.input << [x, y]
      end
    end
  end
end

while y_255.nil?
  sleep 0.01
end

p y_255
