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

NetworkComputer = Struct.new(:thread, :io)

class IO
  def initialize
    @input = Queue.new
    @next_input = nil

    @output = Queue.new
    @next_outputs = []

    @idle = false
  end

  def mark_idle
    @idle = true
  end

  def push_input(value)
    @input << value
  end

  def pop_input
    @input.pop
  end

  def next_input
    @idle = false

    if @next_input
      @next_input.tap { @next_input = nil }
    elsif @input.empty?
      @idle = true

      sleep 0.01

      -1
    else
      current, @next_input = @input.pop

      current
    end
  end

  def output_single_value(value)
    @idle = false

    if @next_outputs.size == 2
      address, x = @next_outputs
      y = value
      @next_outputs = []

      @output << [address, x, y]
    else
      @next_outputs << value
    end
  end

  def pop_output
    @output.pop
  end

  def idle?
    @idle && @input.empty?
  end
end

instructions = read_instructions

network_computers = (0..49).map do |address|
  io = IO.new

  io.push_input(address)

  computer_state = ComputerState.new(
    instructions.dup,
    proc { io.next_input },
    ->(v) { io.output_single_value(v) },
    clock_delay: 0
  )

  [address, NetworkComputer.new(Thread.new { run_program(computer_state) }, io)]
end.to_h

network_computers[255] = IO.new.yield_self do |io|
  last_x = nil
  last_y = nil

  Thread.new do
    loop do
      last_x, last_y = io.pop_input

      io.mark_idle
    end
  end

  idle_writer = Thread.new do
    sent_last_y = nil

    loop do
      all_idle = network_computers.transform_values { |nc| nc.io.idle? }

      if all_idle.values.all?
        if last_y == sent_last_y
          puts "Sent y value of #{last_y} twice to 0!"

          break
        end

        p [0, last_x, last_y]

        sent_last_y = last_y
        io.output_single_value(0)
        io.output_single_value(last_x)
        io.output_single_value(last_y)
      else
        sleep 0.5
      end
    end
  end

  NetworkComputer.new(idle_writer, io)
end

network_computers.each_value.map do |network_computer|
  Thread.new do
    loop do
      address, x, y = network_computer.io.pop_output
      network_computers.fetch(address).io.push_input([x, y])
    end
  end
end

network_computers[255].thread.join
