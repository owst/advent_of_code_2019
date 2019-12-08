def read_orbits(input)
  input.split("\n").map { |orbit| orbit.split(")") }
end

def generate_orbiting(orbits)
  orbits.each_with_object({}) do |(orbitee, orbiter), orbiting|
    orbiting[orbiter] = orbitee
  end
end

def count(orbiting, counts, start)
  return 0 if counts.key?(start)

  count = 0
  current = start

  while (current = orbiting[current])
    count += 1 + count(orbiting, counts, current)
  end

  counts[start] = count
end

orbiting = generate_orbiting(read_orbits($stdin.read))
puts orbiting.keys.each_with_object({}).map { |start, counts| count(orbiting, counts, start) }.sum
