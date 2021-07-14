class GameController < ApplicationController
  def index
    @games = $proxy.owned.not(:solo_only)
    @total = @games.count
    @games = apply_params(@games, params)
    @games = sort(@games, params)
    @games = limit(@games, params)
  end

  def random
    @games = $proxy.owned.not(:solo_only)
    @total = @games.count
    samples = []
    users = %w(hiimjosh iadena yourwhiteshadow Falcifer666 adamabsurd)
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
    render :index
  end

  def limit(games, params)
    limit = params["limit"] || 100
    games.first(limit)
  end

  def sort(games, params)
    if params["sort"]
      dir = 1
      value = params["sort"]

      if value[0] == "-"
        dir = -1
        value = value[1..-1]
      end

      if games.first.respond_to?(value)
        return games.sort_by { |x| dir * x.send(value) }
      end
    end

    games.sort_by { |x| -x.mean_player_rating }
  end

  def valid_filter?(k)
    k.in? %w(
      best_with
      bgg_rank
      mean_player_rating
      owners
      player_rating_summary
      recommended_with
      want_to_players
      weight
    )
  end

  def apply_params(games, params)
    acc = games
    params.each do |k, v|
      if valid_filter?(k)
        v = maybe_upcast_data_type(v)
        puts acc.count
        acc = acc.send(k, v)
        puts acc.count
        acc
      else
        acc = acc
      end
    end
    acc
  end

  def maybe_upcast_data_type(v)
    case v
    when /^\d+$/
      v.to_i
    when /^\[[\d,]+\]$/
      v[1..-2].split(',').map(&:to_i)
    end
  end
end
