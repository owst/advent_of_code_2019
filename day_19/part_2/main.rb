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

# computer = Thread.new do
#   loop do
#     run_program(ComputerState.new(instructions, read, write))
#   end
# end
#
computer = Thread.new do
  str = <<~STR
    #.......................................
    .#......................................
    ..##....................................
    ...###..................................
    ....###.................................
    .....####...............................
    ......#####.............................
    ......######............................
    .......#######..........................
    ........########........................
    .........#########......................
    ..........#########.....................
    ...........##########...................
    ...........############.................
    ............############................
    .............#############..............
    ..............##############............
    ...............###############..........
    ................###############.........
    ................#################.......
    .................########OOOOOOOOOO.....
    ..................#######OOOOOOOOOO#....
    ...................######OOOOOOOOOO###..
    ....................#####OOOOOOOOOO#####
    .....................####OOOOOOOOOO#####
    .....................####OOOOOOOOOO#####
    ......................###OOOOOOOOOO#####
    .......................##OOOOOOOOOO#####
    ........................#OOOOOOOOOO#####
    .........................OOOOOOOOOO#####
    ..........................##############
    ..........................##############
    ...........................#############
    ............................############
    .............................###########
  STR

  cells = str.split("\n").map(&:chars)

  loop do
    x = computer_input.pop.to_i
    y = computer_input.pop.to_i

    computer_output << (cells[y][x] == '.' ? 0 : 1)
  end
end

# Thread.new do
#   (0...35).each do |y|
#     (0...40).each do |x|
#       computer_input << x
#       computer_input << y

#       print(computer_output.pop.to_i == 0 ? '.' : '#')
#     end
#     print "\n"
#   end
# end

size = 10
last_lines = []

grid_updater = Thread.new do
  y = -1

  until y == 30
    y += 1

    first_pulling_col = nil
    pulling_count = 0

    x = -1

    loop do
      x += 1

      break if x > 40

      computer_input << x
      computer_input << y

      if computer_output.pop.to_i == 1
        first_pulling_col ||= x
        pulling_count += 1
      elsif pulling_count > 0 # We're out of the right hand side, may as well stop
        break
      end
    end

    last_lines.push [y, first_pulling_col, pulling_count]

    # if last_lines.size > size
    #   # last_lines.shift

    #   _, last_col, last_width = last_lines.last

    #   # break if last_lines.last(size).all? do |y, first_col, width|
    #   #   first_col && last_col > first_col && width > (last_col - first_col) + size
    #   # end
    # end
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

      last_lines.each do |y, x, len|
        win << [y, x, len].map(&:to_s).join(',') + "\n"
      end

      win << "Last line: " + last_lines[-1].to_s + "\n"

      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

computer.join
display.join
