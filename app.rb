require 'uri'
require 'json'

class MyBase < Sinatra::Base
  configure do
    uri   = URI.parse(ENV["REDISTOGO_URL"])
    REDIS = Redis.new( :host => uri.host, :port => uri.port, :password => uri.password )
  end
end

class MyPost < MyBase
  # only self or github
  use Rack::Auth::IP, %w(127.0.0.1 204.232.175.64/27 192.30.252.0/22)

  post '/' do
    param = params["payload"]
    unless param
      halt 400
    end
    json = JSON.parse(param)
    REDIS.pipelined do
      REDIS.lpush("events", JSON.pretty_generate(json))
      REDIS.ltrim("events", 0, 99)
    end
    200
  end
end

class MyGet < MyBase

  helpers Kaminari::Helpers::SinatraHelpers

  get '/' do
    @events = get_events
    erb :index
  end

  def get_events
    page   = params["page"] || 1
    length = REDIS.llen("events") || 0
    limit  = 5
    offset = (page.to_i - 1) * limit
    elements = REDIS.lrange("events", offset, offset + limit - 1)
    Kaminari.paginate_array(elements, total_count: length).page(page).per(limit)
  end
end

# http://qiita.com/items/f2fef02e12ea2bea3f89
class MyApplication < Sinatra::Base
  use MyGet
  use MyPost
end
