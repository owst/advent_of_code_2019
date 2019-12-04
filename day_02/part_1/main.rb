def read_instructions
  $stdin.read.split(',').map(&:to_i)
end

def modify_instructions(instructions)
  instructions[1] = 12
  instructions[2] = 2
end

def resolve_op(op_num)
  case op_num
  when 99 then :break
  when 1 then :+
  when 2 then :*
  else
    raise "Unexpected op_num: #{op_num}"
  end
end

# run_program([1,0,0,0,99]) = [2,0,0,0,99]
# run_program([2,3,0,3,99]) = [2,3,0,6,99]
# run_program([2,4,4,5,99,0]) = [2,4,4,5,99,9801]
# run_program([1,1,1,4,99,5,6,0,99]) = [30,1,1,4,2,5,6,0,99]
def run_program(instructions)
  state = instructions.each_with_index.map { |x, i| [i, x] }.to_h

  (0...instructions.length).each_slice(4) do |is|
    op_num, a1, a2, a3 = is.map { |i| state[i] }

    op = resolve_op(op_num)

    break if op == :break

    state[a3] = state.fetch(a1).send(op, state.fetch(a2))
  end

  state
end

instructions = read_instructions
modify_instructions(instructions)
final_state = run_program(instructions)
p final_state[0]
