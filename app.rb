require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'pony'
require 'yaml'
require 'sqlite3'
require 'builder'

def barber_exists?(db, barber)
  db.execute('SELECT * FROM Barbers WHERE Barber=?', [barber]).length.positive?
end

def seed_db(db, barbers)
  barbers.each do |barber|
    db.execute 'INSERT INTO Barbers (Barber) VALUES (?)', [barber] unless barber_exists? db, barber
  end
end

def get_db
  db = SQLite3::Database.new 'barbershop.db'
  db.results_as_hash = true
  db
end

configure do

  db = get_db
  db.execute 'CREATE TABLE IF NOT EXISTS "Users" (
    "Id"  INTEGER PRIMARY KEY AUTOINCREMENT,
    "Name"  TEXT,
    "Phone" TEXT,
    "DateStamp" TEXT,
    "Barber"  TEXT,
    "Color" TEXT
  )'

  db.execute 'CREATE TABLE IF NOT EXISTS "Barbers" (
    "Id"  INTEGER PRIMARY KEY AUTOINCREMENT,
    "Barber"  TEXT
  )'

  seed_db db, ['Walter White', 'Jessie Pinkman', 'Gus Fring', 'Mike Ehrmantraut']

  enable :sessions

end

helpers do
  def username
    session[:identity] || 'Hello stranger'
  end
end

before '/secure/*' do
  unless session[:identity]
    session[:previous_url] = request.path
    @error = "Sorry, you need to be logged in to visit #{request.path}"
    halt erb(:login_form)
  end
end

before '/visit' do
  @barbers_data = []
  db = get_db
  db.execute 'SELECT Barber FROM Barbers' do |row|
    @barbers_data << row.values.join
  end
end

get '/' do
  erb 'Hello dear friend!'
end

get '/about' do
  erb :about
end

get '/visit' do
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

  @client_name.capitalize!

  hh = {client_name: "You didn't enter your name",
        client_phone: "You didn't enter your phone",
        date_time: 'Wrong date and time'
      }

  @error = hh.select { |key,_| params[key] == '' }.values.join(', ')

  return erb :visit unless @error == ''

  f = File.open './public/users.txt', 'a'
  f.write "headresser: #{@headresser}, client: #{@client_name}, phone: #{@client_phone}, date and time: #{@date_time}, color: #{@color}.\n"
  f.close

  db = get_db
  db.execute 'INSERT INTO Users
                        (
                        Name,
                        Phone,
                        DateStamp,
                        Barber,
                        Color
                        )
                        VALUES (?,?,?,?,?)', [@client_name, @client_phone, @date_time, @headresser, @color]

  erb '<h3>Thank you! You are signed up.</h3>'
  # where_user_came_from = session[:previous_url] || '/'
  # erb @message
end

post '/contacts' do
  @client_email = params[:client_email]
  @client_message = params[:client_message]

  cc = {client_email: "You did't enter your email",
        client_message: "You did't enter your message"}

  @error = cc.select { |key, _| params[key] == '' }.values.join(', ')

  return erb :contacts unless @error == ''

  f = File.open './public/contacts.txt', 'a'
  f.write "client email: #{@client_email}\nmessage:\n#{@client_message}\n"
  f.close

  smtp_info =
    begin
      YAML.load_file('./smtpinfo.yml')
    rescue
      @error = 'Error: Could not find SMTP info. Please contact the site administrator.'
      return erb :contacts
    end

  Pony.options = {
    subject: "art inquiry from #{@client_email}",
    body: @client_message.to_s,
    via: :smtp,
    via_options: {
      address: 'smtp.gmail.com',
      port: '587',
      enable_starttls_auto: true,
      user_name: smtp_info[:username],
      password: smtp_info[:password],
      authentication: :plain, # :plain, :login, :cram_md5, no auth by default
      domain: 'localhost.localdomain'
    }
  }

  Pony.mail(to: 'sergey.login+ruby@gmail.com')

  erb @message = 'Your feedback is send. Thanks for contacting to us!'

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

get '/show_users' do
  db = get_db
  @users_data = db.execute 'SELECT * FROM USERS'
  erb :show_users
end



