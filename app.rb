require 'sinatra'
require 'uri'
require 'json'

configure do
  uri   = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new( :host => uri.host, :port => uri.port, :password => uri.password )
end

helpers Kaminari::Helpers::SinatraHelpers

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

__END__

@@index
<html>
<head>
<title>events</title>
</head>
<body>
<div>
<% @events.each do |e| %>
<pre><%= e %></pre>
<% end %>
</div>
<%= paginate @events %>
</body>
</html>
