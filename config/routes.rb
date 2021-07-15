Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root to: "game#index"

  get "/random", to: "game#random"
  get "/most_want_to_play", to: "game#most_want_to_play"
end
