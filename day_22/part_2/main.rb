def parse(str = nil)
  str ||= ARGF.read

  str.split("\n").map do |line|
    case line
    when /new stack/
      then [:new_stack]
    when /(increment|cut) (-?\d+)/ then
      name, arg = Regexp.last_match.captures
      [name.to_sym, arg.to_i]
    else
      raise "Urk: #{line}"
    end
  end
end

Linear = Struct.new(:size, :a, :b) do
  def *(other)
    raise "Urk: #{size}/#{other.size}" if size != other.size

    # Linear(a1, b1) * Linear(a2, b2):
    # a2 * (a1 * x + b1) + b2
    # a2 * a1 * x + a2 * b1 + b2
    Linear.new(size, (a * other.a) % size, (other.a * b + other.b) % size)
  end

  def power(n)
    if n == 1
      self
    elsif n.odd?
      self * (self * self).power(n / 2)
    else
      (self * self).power(n / 2)
    end
  end

  def apply(x)
    (a * x + b) % size
  end

  def solve(res)
    ((res - b) * modinv(a)) % size
  end

  # modinv(x,n) == pow(x,n-2,n)
  private def modinv(x)
    x.pow(size - 2, size)
  end
end

def coefficients(size, parsed)
  parsed.map do |op, arg|
    case op
    when :new_stack
      Linear.new(size, -1, -1)
    when :increment
      Linear.new(size, arg, 0)
    when :cut
      Linear.new(size, 1, -arg)
    end
  end.reduce(:*)
end

p coefficients(119315717514047, parse).power(101741582076661).solve(2020)
