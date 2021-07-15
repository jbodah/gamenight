module AllGames
  class << self
    def call
      Marshal.load(File.read('filter.out'))
    end
  end
end
