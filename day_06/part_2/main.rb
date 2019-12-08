def read_orbits(input)
  input.split("\n").map { |orbit| orbit.split(")") }
end

def generate_orbiting(orbits)
  orbits.each_with_object({}) do |(orbitee, orbiter), orbiting|
    orbiting[orbiter] = orbitee
  end
end

def generate_path(orbiting, start)
  current = start

  path = []

  while (current = orbiting[current])
    path << current
  end

  path
end

def drop_common_suffixes(left, right)
  common = 1
  common += 1 while left[-common] == right[-common]

  [left, right].map { |list| list.reverse.drop(common - 1).reverse }
end

orbiting = generate_orbiting(read_orbits($stdin.read))

you_path = generate_path(orbiting, "YOU")
san_path = generate_path(orbiting, "SAN")

you_unique, san_unique = drop_common_suffixes(you_path, san_path)

puts you_unique.size + san_unique.size
