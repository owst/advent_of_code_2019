def all_possibles
  ('000000'..'999999')
end

def exactly_two_adjacent_digits_equal?(str)
  str.to_enum(:scan, /(\d)\1+/).map { Regexp.last_match }.any? { |m| m.to_s.size == 2 }
end

def no_adjacent_digit_decrease?(str)
  str.chars.each_cons(2).all? { |c1, c2| c1 <= c2 }
end

def in_range?(str)
  ('108457'..'562041').cover?(str)
end

def match?(s)
  in_range?(s) && no_adjacent_digit_decrease?(s) && exactly_two_adjacent_digits_equal?(s)
end

p all_possibles.count { |s| match?(s) }
