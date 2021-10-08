class GameController < ApplicationController
  SIMPLE_PARAMS = %w(
    avg_player_rating
    bgg_rank
    id
    maxplayers
    maxplaytime
    max_player_rating
    median_player_rating
    min_player_rating
    minplayers
    minplaytime
    name
    num_dislikers
    num_haters
    num_likers
    num_lovers
    num_raters
    playingtime
    user_rating
    weight
  )

  COLLECTION_PARAMS = %w(
    best_with
    dislikers
    haters
    likers
    lovers
    mechanics
    owners
    plays_with
    raters
    recommended_with
    want_to_learners
    want_to_players
  )

  FLAG_PARAMS = %w(
    incl_solo
    incl_2p
  )

  before_action do
    @simple_params = SIMPLE_PARAMS
    @collection_params = COLLECTION_PARAMS
    @flag_params = FLAG_PARAMS
    @games = $proxy.owned
    @total = @games.count
    @games = @games.not(:solo_only) unless params["incl_solo"] == "1"
    @games = @games.not(:two_player_only) unless params["incl_2p"] == "1"
    @mechanics = mechanics
    @mechanics_ranking = @mechanics.map { |k, m| [k, m["ranking"]] }.to_h
    @mechanics_played = @mechanics.map { |k, m| [k, m["plays"]] }.to_h
    @mechanics_num_games = @mechanics.map { |k, m| [k, m["count"]] }.to_h
  end

  def index
    @games = apply_params(@games, params)
    @games = sort(@games, params)
    @games = limit(@games, params)
  end

  def random
    if params["permalink"]
      ids = Base64.decode64(params["permalink"]).split(',')
      games_by_id = @games.select { |g| g.id.in? ids }.index_by(&:id)
      @games = ids.map { |id| games_by_id[id] }
      render :index
    else
      samples = []
      users = YAML.load_file('config/bgg.yaml').fetch("users")
      users = (users * 2).shuffle
      [4, 5].shuffle.each do |n|
        user = users.shift
        samples += @games.recommended_with(n).filler.owned_by(user).to_a.sample(1)

        user = users.shift
        samples += @games.recommended_with(n).owned_by(user).select { |g| g.weight > 2 && g.weight < 3 }.sample(1)

        user = users.shift
        samples += @games.recommended_with(n).owned_by(user).select { |g| g.weight > 3 }.sample(1)
      end
      @games = samples.sort_by { |g| -g.weight }
      ids = @games.map(&:id).join(',')
      redirect_to random_path(permalink: Base64.encode64(ids))
    end
  end

  def hidden_gems
    @games = @games.select { |g| g.median_player_rating >= 7 }.sort_by { |g| -g.bgg_rank }
    render :index
  end

  def mechanics
    mechanics = {}
    @games.each do |game|
      game.mechanics.each do |mechanic|
        mechanics[mechanic] ||= {}

        mechanics[mechanic]["ranking"] ||= []
        mechanics[mechanic]["ranking"] += game.player_ratings

        mechanics[mechanic]["count"] ||= []
        mechanics[mechanic]["count"] << game.id

        mechanics[mechanic]["plays"] ||= 0
        mechanics[mechanic]["plays"] += game.num_raters
      end
    end

    mechanics.each do |k, m|
      ratings = m["ranking"]
      size = [ratings.size, 1].max
      m["ranking"] = ratings.sum.to_f / size

      m["count"] = m["count"].uniq.size
    end
    mechanics
  end

  def limit(games, params)
    limit = params["limit"] || 500
    games.first(limit)
  end

  def sort(games, params)
    return games.stable_sort_by { |x| -x.raters.size }.stable_sort_by { |x| -x.want_to_players.size }.stable_sort_by { |x| -x.median_player_rating } unless params["sort"]
    return games.to_a.shuffle if params["sort"] == "random"

    acc = games
    sorts = params["sort"].split(",")
    sorts.each do |sort|
      dir = 1
      value = sort

      if value[0] == "-"
        dir = -1
        value = value[1..-1]
      end

      if acc.first.respond_to?(value)
        acc = acc.stable_sort_by do |x|
          n = x.send(value)
          n = n.size if n.respond_to?(:each)
          dir * n
        end
      end
    end
    acc
  end

  def apply_params(games, params)
    acc = games
    params.each do |k, v|
      acc =
        case k
        when *SIMPLE_PARAMS
          v = maybe_upcast_data_type(v)
          if v.respond_to?(:call)
            acc.where { |g| v.call g.send(k) }
          else
            acc.where { |g| g.send(k) == v }
          end
        when *COLLECTION_PARAMS
          v = maybe_upcast_data_type(v)
          acc.send(k, v)
        else
          acc
        end
    end
    acc
  end

  def maybe_upcast_data_type(v)
    case v
    when /^[\s\d]+$/
      v.to_i
    when /^[\s\d\.]+$/
      v.to_f
    when /^\[[\s\w\d\.,]+\]$/
      v[1..-2].split(',').map { |val| maybe_upcast_data_type(val) }
    when /^lt[\d\.]+$/
      val = maybe_upcast_data_type(v[2..-1])
      -> (n) { n < val }
    when /^lte[\d\.]+$/
      val = maybe_upcast_data_type(v[3..-1])
      -> (n) { n <= val }
    when /^gt[\d\.]+$/
      val = maybe_upcast_data_type(v[2..-1])
      -> (n) { n > val }
    when /^gte[\d\.]+$/
      val = maybe_upcast_data_type(v[3..-1])
      -> (n) { n >= val }
    else
      v
    end
  end
end
