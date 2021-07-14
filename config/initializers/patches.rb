class Object
  def in?(enum)
    enum.include? self
  end

  def not_in?(enum)
    !in?(enum)
  end
end
