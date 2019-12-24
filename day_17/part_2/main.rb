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
instructions[0] = 2

computer_state = ComputerState.new(
  instructions.dup,
  proc { computer_input.pop },
  ->(v) { computer_output << v },
  clock_delay: (1 / 75_000.0)
)
computer = Thread.new { run_program(computer_state) }

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

  def valid?(cols, rows)
    x.between?(0, cols - 1) && y.between?(0, rows - 1)
  end
end

class ASCIIState
  LINES = 35
  COLS = 55

  DIRECTIONS = {
    UP = :up => '^',
    DOWN = :down => 'v',
    LEFT = :left => '<',
    RIGHT = :right => '>',
  }.freeze

  CONTENTS = {
    EMPTY = :empty => '.',
    PATH = :path => '#',
    CROSS = :cross => '+'
  }.freeze

  attr_reader :direction

  def initialize
    clear
    @alignment_parameter_sum = 0
    @path = []
  end

  def clear
    @lines = [[]]
  end

  def <<(char)
    if char == "\n"
      @lines << []
    else
      @lines.last << char
    end
  end

  def complete_map?
    @lines.size == LINES + 1
  end

  def walk_path
    forwards = 0

    loop do
      if path_forwards?
        forwards += 1
        new_value = cell == CONTENTS.fetch(CROSS) ? PATH : EMPTY
        cell_set(CONTENTS.fetch(new_value), @robot_pos)
        @robot_pos = forward_pos
      else
        @path << forwards unless forwards.zero?
        forwards = 0

        previous_direction = @robot_direction

        [UP, RIGHT, DOWN, LEFT].each do |dir|
          turn_to(dir)
          break if path_forwards?
        end

        break unless path_forwards?

        @path << turn_dir(previous_direction, @robot_direction).to_s[0].upcase if path_forwards?
      end

      sleep(1 / 60.0)
    end
  end

  def turn_dir(old_dir, new_dir)
    case
    when old_dir == :up && new_dir == :right
      :right
    when old_dir == :up && new_dir == :left
      :left
    when old_dir == :right && new_dir == :down
      :right
    when old_dir == :right && new_dir == :up
      :left
    when old_dir == :down && new_dir == :left
      :right
    when old_dir == :down && new_dir == :right
      :left
    when old_dir == :left && new_dir == :up
      :right
    when old_dir == :left && new_dir == :down
      :left
    else
      raise "urk: #{old_dir} #{new_dir}"
    end
  end

  def turn_to(direction)
    @robot_direction = direction

    cell_set(DIRECTIONS.fetch(direction), @robot_pos)
  end

  def path_forwards?
    [CONTENTS.fetch(PATH), CONTENTS.fetch(CROSS)].include?(cell(forward_pos))
  end

  def forward_pos
    @robot_pos.send(@robot_direction)
  end

  def cell(pos = @robot_pos)
    return unless pos.valid?(COLS, LINES)

    @lines[pos.y][pos.x]
  end

  def cell_set(value, pos = @robot_pos)
    raise "Bad pos: #{pos}" unless pos.valid?(COLS, LINES)

    @lines[pos.y][pos.x] = value
  end

  def mark_crosses
    @lines = @lines.each_with_index.map do |line, y|
      line.each_with_index.map do |char, x|
        if cross?(y, x)
          @alignment_parameter_sum += x * y

          CONTENTS.fetch(CROSS)
        elsif DIRECTIONS.values.include?(char)
          @robot_pos = Pos.new(x, y)
          @robot_direction = DIRECTIONS.to_a.map(&:reverse).to_h.fetch(char)

          char
        else
          char
        end
      end
    end
  end

  def set_total_cleaned(total)
    @total_cleaned = total
  end

  def draw
    status = "Alignment Param: #{@alignment_parameter_sum}, total_cleaned: #{@total_cleaned}"

    ([[status]] + @lines).map(&:join).each_with_index.map { |s, i| "#{format("%02d", i + 1)}: #{s}" }.join("\n")
  end

  def program_lines
    str = @path.each_slice(2).to_a
    repeats = repeated_strings(str)

    res = find_valid_repeats(repeats, 0).select do |path|
      path.flatten(1) == str && path.sort.uniq.size <= 3 && path.length <= 10
    end.first

    sub_routine_names = res.uniq.zip(%w[A B C]).to_h

    main_routine = res.map { |r| sub_routine_names.fetch(r) }.join(",")
    sub_routines = sub_routine_names.map(&:reverse).sort.to_h.values.map { |p| p.flatten.join(",") }

    [
      main_routine,
      sub_routines,
      "n" # No video feed
    ].flatten
  end

  private def cross?(y, x)
    return false unless y.between?(1, LINES - 2) && x.between?(1, COLS - 2)

    [
      @lines[y - 1][x],
      @lines[y][x - 1],
      @lines[y][x],
      @lines[y][x + 1],
      @lines[y + 1][x]
    ].uniq == ['#']
  end

  private def repeated_strings(str)
    len = str.length
    sub_strs = {}

    (len / 2).downto(2) do |sub_str_len|
      (0..(len - sub_str_len)).each do |i|
        sub_str = str[i, sub_str_len]

        sub_strs[sub_str] ||= []
        sub_strs[sub_str] << i
      end
    end

    sub_strs.select { |path, positions| positions.size > 2 && path.size > 2 }
  end

  private def find_valid_repeats(repeats, start_idx)
    firsts = repeats.select { |_path, positions| positions.include?(start_idx) }.to_a

    return [[]] if firsts.empty?

    firsts.flat_map do |prefix, _|
      find_valid_repeats(repeats, start_idx + prefix.length).map { |tail| [prefix] + tail }
    end
  end
end

ascii_state = ASCIIState.new

state_updater = Thread.new do
  read_map = proc { ascii_state << computer_output.pop.chr until ascii_state.complete_map? }
  read_line = proc { true until computer_output.pop.chr == "\n" }

  read_map.call

  ascii_state.mark_crosses

  ascii_state.walk_path

  ascii_state.program_lines.each do |line|
    read_line.call

    line.chars.each { |c| computer_input << c.ord }

    computer_input << "\n".ord
  end

  2.times { read_line.call }

  ascii_state.clear

  read_map.call

  read_line.call

  ascii_state.set_total_cleaned(computer_output.pop)
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
      win << ascii_state.draw
      win.refresh

      sleep(1 / 60.0)
    end
  ensure
    Curses.close_screen
  end
end

computer.join
display.join
