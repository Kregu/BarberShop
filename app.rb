require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'pony'
require 'yaml'

configure do
  enable :sessions
end

helpers do
  def username
    session[:identity] ? session[:identity] : 'Hello stranger'
  end
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = 'Sorry, you need to be logged in to visit ' + request.path
    halt erb(:login_form)
  end
end

get '/' do
  erb 'Hello dear friend!'
end

get '/about' do
  erb :about
end

get '/visit' do
  @headresser = "Any headresser"
  erb :visit
end

get '/contacts' do
  erb :contacts
end


get '/login/form' do
  erb :login_form
end

get '/sign_up' do
  erb :sign_up
end

post '/visit' do
  @headresser = params[:headresser]
  @client_name = params[:client_name]
  @client_phone = params[:client_phone]
  @date_time = params[:date_time]
  @color = params[:color]

  hh = {:client_name => "You did't enter your name",
        :client_phone => "You did't enter your phone",
        :date_time => "Wrong date and time"
      }

  @error = hh.select {|key,_| params[key] == ""}.values.join(", ")

  unless @error == ""
    return erb :visit
  end
  
  @message = "Dear #{@client_name}, we wait you at #{@date_time}, your color #{@color}, your headresser #{@headresser}."


  f = File.open './public/users.txt', 'a'
  f.write "headresser: #{@headresser}, client: #{@client_name}, phone: #{@client_phone}, date and time: #{@date_time}, color: #{@color}.\n"
  f.close

  # where_user_came_from = session[:previous_url] || '/'
  erb @message
end

post '/contacts' do
  @client_email = params[:client_email]
  @client_message = params[:client_message]

  cc = {:client_email => "You did't enter your email",
        :client_message => "You did't enter your message"}

  @error = cc.select{|key,_| params[key] == ""}.values.join(", ")

  unless @error == ""
    return erb :contacts
  end


  f = File.open './public/contacts.txt', 'a'
  f.write "client email: #{@client_email}\nmessage:\n#{@client_message}\n"
  f.close

  smtp_info =
    begin
      YAML.load_file("./smtpinfo.yml")
    rescue
      @error = "Error: Could not find SMTP info. Please contact the site administrator."
      return erb :contacts
    end


  Pony.options = {
  :subject => "art inquiry from #{@client_email}",
  :body => "#{@client_message}",
  :via => :smtp,
  :via_options => {
    :address              => 'smtp.gmail.com',
    :port                 => '587',
    :enable_starttls_auto => true,
    :user_name            => smtp_info[:username],
    :password             => smtp_info[:password],
    :authentication       => :plain, # :plain, :login, :cram_md5, no auth by default
    :domain               => "localhost.localdomain"
    }
  }

  Pony.mail(:to => "sergey.login+ruby@gmail.com")

  erb @message = "Your feedback is send. Thanks for contacting to us!"
  
end


post '/login/attempt' do
  session[:identity] = params['username']
  where_user_came_from = session[:previous_url] || '/'
  redirect to where_user_came_from
end

get '/logout' do
  session.delete(:identity)
  erb "<div class='alert alert-message'>Logged out</div>"
end

get '/secure/place' do
  erb 'This is a secret place that only <%=session[:identity]%> has access to!'
end
