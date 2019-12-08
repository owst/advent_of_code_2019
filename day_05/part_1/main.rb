def read_instructions
  File.read(ARGV[0]).split(',').map(&:to_i)
end

def resolve_op(op_num)
  case op_num
  when 99 then [:break, 0]
  when 1 then [:+, 2]
  when 2 then [:*, 2]
  when 3 then [:read, 0]
  when 4 then [:write, 0]
  else
    raise "Unexpected op_num: #{op_num}"
  end
end

def resolve_instruction(input)
  n = [input.length, 2].min
  op, arg_count = resolve_op(input.slice!(-n, n).to_i)
  arg_modes = input.chars.reverse.map(&:to_i).each_with_index.map { |c, i|
    [i, c.zero? ? :position : :immediate]
  }.to_h

  [arg_modes, op, arg_count]
end

def resolve_arguments(state, address_modes, args)
  args.each_with_index.map do |arg, i|
    address_modes.fetch(i, :position) == :position ? state.fetch(arg) : arg
  end
end

def run_program(instructions)
  state = instructions.each_with_index.map { |x, i| [i, x] }.to_h

  pc = 0

  loop do
    address_modes, op, arg_count = resolve_instruction(state.fetch(pc).to_s)

    break if op == :break

    unresolved_args = (1..arg_count).map { |arg_num| state.fetch(pc + arg_num) }
    target_address = state.fetch(pc + arg_count + 1)
    args = resolve_arguments(state, address_modes, unresolved_args)

    case op
    when :+, :*
      state[target_address] = args[0].send(op, args[1])
    when :read
      puts "Enter number:"
      state[target_address] = $stdin.readline.to_i
    when :write
      puts state[target_address]
    end

    pc += arg_count + 1 + 1 # 1 for instruction, 1 for target address
  end

  state
end

run_program(read_instructions)
