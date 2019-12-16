Vector = Struct.new(:x, :y, :z) do
  def self.zero
    new(0, 0, 0)
  end

  def +(other)
    self.class.new(x + other.x, y + other.y, z + other.z)
  end

  def abs_max(other)
    self.class.new(*to_a.map(&:abs).zip(other.to_a.map(&:abs)).map(&:max))
  end

  def pretty(max)
    digit_count = ->(val) { Math.log10(val).floor + 1 }

    # +1 to account for (optional) leading "-" in overal width
    c = ->(max_val) { "% #{max_val.zero? ? 1 : digit_count.call(max_val) + 1}d" }

    format("<x=#{c.call(max.x)}, y=#{c.call(max.y)}, z=#{c.call(max.z)}>", x, y, z)
  end
end

class Moon
  attr_reader :position, :velocity

  def initialize(position, velocity)
    @position = position
    @velocity = velocity
  end

  def self.parse(line)
    values = line.gsub(/[<>\s]+/, '').split(",").map do |assign|
      var, value = assign.split("=")

      [var, value.to_i]
    end.to_h

    new(Vector.new(values.fetch("x"), values.fetch("y"), values.fetch("z")), Vector.zero)
  end

  def potential_energy
    vector_energy(position)
  end

  def kinetic_energy
    vector_energy(velocity)
  end

  def energy
    potential_energy * kinetic_energy
  end

  def pretty(max_pos, max_vel)
    "pos=#{@position.pretty(max_pos)}, vel=#{@velocity.pretty(max_vel)}"
  end

  def apply_velocity
    self.class.new(@position + @velocity, @velocity)
  end

  def apply_gravity(other)
    pos = position
    opos = other.position

    self.class.new(
      pos,
      velocity + Vector.new(opos.x <=> pos.x, opos.y <=> pos.y, opos.z <=> pos.z)
    )
  end

  private def vector_energy(vector)
    vector.to_a.map(&:abs).sum
  end
end

def read_input(input = nil)
  input ||= $stdin.read

  input.split("\n").map { |line| Moon.parse(line) }
end

def print(moons)
  maxes = moons.reduce([Vector.zero, Vector.zero]) do |(max_pos, max_vel), moon|
    [moon.position.abs_max(max_pos), moon.velocity.abs_max(max_vel)]
  end

  moons.each { |moon| puts moon.pretty(*maxes) }
end

initial = read_input
steps = 1000

final_state = (0...steps).reduce(initial) do |state, _i|
  state = state.map do |moon|
    (state - [moon]).reduce(moon, :apply_gravity).apply_velocity
  end
end

puts "After #{steps} steps:"
print(final_state)

p final_state.map(&:energy).sum
