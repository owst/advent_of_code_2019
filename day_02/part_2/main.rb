def read_instructions
  $stdin.read.split(',').map(&:to_i)
end

def modify_instructions(instructions, noun, verb)
  copy = instructions.dup
  copy[1] = noun
  copy[2] = verb
  copy
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

def find_noun_verb(instructions)
  (0..99).each do |noun|
    (0..99).each do |verb|
      result = run_program(modify_instructions(instructions, noun, verb))
      return [noun, verb] if result[0] == 19690720
    end
  end

  raise "Didn't find noun/verb"
end

instructions = read_instructions

noun, verb = find_noun_verb(instructions)

p 100 * noun + verb
