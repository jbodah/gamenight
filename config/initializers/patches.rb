class Object
  def in?(enum)
    enum.include? self
  end

  def not_in?(enum)
    !in?(enum)
  end
end

module Enumerable
  def stable_sort
    sort_by.with_index { |x, idx| [x, idx] }
  end

  def stable_sort_by
    sort_by.with_index { |x, idx| [yield(x), idx] }
  end
end

