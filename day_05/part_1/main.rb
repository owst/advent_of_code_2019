def read_instructions
  File.read(ARGV[0]).split(',').map(&:to_i)
end

def resolve_op(op_num)
  case op_num
  when 99 then [:break, 0]
  when 1 then [:+, %i[r r w]]
  when 2 then [:*, %i[r r w]]
  when 3 then [:read, %i[w]]
  when 4 then [:write, %i[r]]
  else
    raise "Unexpected op_num: #{op_num}"
  end
end

def resolve_instruction(input)
  n = [input.length, 2].min
  op, arg_modes = resolve_op(input.slice!(-n, n).to_i)
  address_modes = input.chars.reverse.map(&:to_i).each_with_index.map { |c, i|
    [i, c.zero? ? :position : :immediate]
  }.to_h

  [address_modes, op, arg_modes]
end

def resolve_arguments(state, address_modes, pc, arg_modes)
  (1..arg_modes.size).map { |arg_num|
    state.fetch(pc + arg_num)
  }.each_with_index.map { |arg, i|
    dereference = arg_modes[i] == :r && address_modes.fetch(i, :position) == :position

    dereference ? state.fetch(arg) : arg
  }
end

def run_program(instructions)
  state = instructions.each_with_index.map { |x, i| [i, x] }.to_h

  pc = 0

  loop do
    address_modes, op, arg_modes = resolve_instruction(state.fetch(pc).to_s)

    break if op == :break

    *args, target = resolve_arguments(state, address_modes, pc, arg_modes)

    case op
    when :+, :*
      state[target] = args[0].send(op, args[1])
    when :read
      puts "Enter number:"
      state[target] = $stdin.readline.to_i
    when :write
      puts target
    end

    pc += arg_modes.size + 1
  end

  state
end

run_program(read_instructions)
