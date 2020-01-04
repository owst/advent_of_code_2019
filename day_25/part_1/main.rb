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

Location = Struct.new(:name, :description, :doors, :items) do
  BAD_ITEMS = [
    'photons',
    'infinite loop',
    'molten lava',
    'escape pod',
    'giant electromagnet'
  ]

  def self.take_list_items(l)
    l.drop(1).take_while { |s| s.start_with?('-') }.map { |li| li.sub('- ', '') }
  end

  def self.parse(str)
    name, description, *doors_and_items = str.gsub(/ +/, ' ').split("\n").reject(&:empty?)

    unless doors_and_items.first == 'Doors here lead:' && doors_and_items.last == 'Command?'
      raise "Urk"
    end

    doors = take_list_items(doors_and_items)
    items = if doors_and_items.size <= doors.size + 2
              []
            else
              take_list_items(doors_and_items.reverse) - BAD_ITEMS
            end

    new(name.sub(/== (.+) ==/, '\1'), description, doors, items)
  end
end

class GameState
  DIRECTIONS = [
    NORTH = 'north',
    SOUTH = 'south',
    EAST = 'east',
    WEST = 'west',
  ].freeze

  REVERSE_DIRECTIONS = {
    NORTH => SOUTH,
    SOUTH => NORTH,
    EAST => WEST,
    WEST => EAST,
  }.freeze

  attr_reader :checkpoint_path

  def initialize
    @path_length = 0
    @location_explored_doors = {}
    @return_path = []
    @checkpoint_path = nil
  end

  def next_dfs_door_from_location(location)
    @location_explored_doors[location] ||= []

    if /Checkpoint/.match?(location.name)
      @checkpoint_path = @return_path.map { |dir| REVERSE_DIRECTIONS.fetch(dir) }
    end

    return if @return_path.empty? && @location_explored_doors[location] == location.doors

    chosen = location.doors.reject do |door|
      @location_explored_doors[location].include?(door) ||
        @return_path.last == door ||
        (location.name =~ /Checkpoint/ && door == 'west')
    end.first

    if chosen.nil?
      chosen = @return_path.pop
    else
      @return_path.push(REVERSE_DIRECTIONS.fetch(chosen))
    end

    @location_explored_doors[location] << chosen

    chosen
  end
end

instructions = read_instructions
computer_input = Queue.new
computer_output = Queue.new

computer_state = ComputerState.new(
  instructions,
  proc { computer_input.pop },
  ->(v) { computer_output << v.chr },
  clock_delay: 0
)

game_state = GameState.new

display_output = Queue.new

Thread.new { run_program(computer_state) }

send_computer_input = ->(str) do
  str.chars.map(&:ord).each { |c| computer_input << c }
  computer_input << "\n".ord
end

take_computer_output = -> do
  str = ""
  until str.end_with?("Command?\n") || str.end_with?('You may proceed.')
    str += computer_output.pop
  end
  str
end

loop do
  str = take_computer_output.call

  location = Location.parse(str)

  puts "Now in #{location.name}"

  direction = game_state.next_dfs_door_from_location(location)

  location.items.each do |i|
    puts "Taking #{i}"
    send_computer_input.call("take #{i}")
    take_computer_output.call
  end

  break unless direction

  puts "Moving #{direction}"
  send_computer_input.call(direction)
end

puts "Moving back to checkpoint..."
game_state.checkpoint_path.each do |dir|
  puts "Moving #{dir}"
  send_computer_input.call(dir)
  take_computer_output.call
end

puts "Dropping items to pass checkpoint..."
send_computer_input.call('inv')
items = take_computer_output.call.split("\n").grep(/- /).map { |l| l.sub('- ', '') }

last_drop = nil
needed = []

loop do
  send_computer_input.call('west')

  str = take_computer_output.call

  if /lighter/.match?(str)
    drop = (items - needed).first
    items -= [drop]
    puts "Trying dropping #{drop}"
    send_computer_input.call("drop #{drop}")
    last_drop = drop
  elsif /heavier/.match?(str)
    puts "Needed #{last_drop}, picking it back up"
    needed << last_drop
    send_computer_input.call("take #{last_drop}")
    last_drop = nil
  else
    display_output << str
    break # If we've got the correct weight, we're allowed to pass...
  end

  take_computer_output.call
end

str = ""
str << computer_output.pop.chr until /get in by typing.*"/.match?(str)
puts str
