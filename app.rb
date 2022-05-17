require 'sinatra'
require 'slim'
require 'sqlite3'
require 'bcrypt'

enable :sessions

# Funktion för att koppla till databasen och spara den som en hash.
def connect_to_db(path)
  db = SQLite3::Database.new(path)
  db.results_as_hash = true
  return db
end

#Visa loginsidan och spara tidpunkten för requesten för en senare anti-spamfunktion.
get('/showlogin') do
  time = Time.now.to_i
  slim(:"public/login",locals:{currenttime:time})
end

get('/review') do
  db = connect_to_db('db/shop.db')
  productid = params[:product_id].to_i
  result = db.execute("SELECT * FROM product WHERE id = ?",productid)
  slim(:"user/review",locals:{currentitem:result,prodid:productid})
end

post('/review/:id/update') do
  db = connect_to_db('db/shop.db')
  productid = params[:product_id].to_i
  title = params[:Rubrik]
  text = params[:Text]
  rating = params[:Rating].to_i
  choosen = db.execute('SELECT user_id FROM reviews WHERE product_id = ?',productid).first
  if choosen!=nil 
    if choosen["user_id"]==session[:id]
      db.execute('UPDATE reviews SET user_id = ?, product_id = ?, title = ?, writing = ?, rating = ?',session[:id],productid,title,text,rating)
    end
  else
    db.execute('INSERT INTO reviews (user_id,product_id,title,writing,rating) VALUES (?,?,?,?,?)',session[:id],productid,title,text,rating)
  end
  redirect('/shop')
end

#Visa sidan för att lägga till produkt ifall man är admin.
get('/shop/new') do
  db = connect_to_db('db/shop.db')
  result = db.execute("SELECT role FROM users WHERE id = ?",session[:id]).first
  if result["role"] == 1
    result = db.execute("SELECT * FROM product")
    slim(:"admin/create",locals:{items:result})
  else
    redirect('/shop')
  end
end

#Visa sidan för att uppdatera produkt ifall man är admin. 
get('/shop/:id/edit') do
  db = connect_to_db('db/shop.db')
  result = db.execute("SELECT role FROM users WHERE id = ?",session[:id]).first
  if result["role"] == 1
    productid = params[:product_id].to_i 
    result = db.execute("SELECT * FROM product WHERE id = ?", productid)
    slim(:"admin/edit",locals:{currentitem:result,prodid:productid})
  else
    redirect('/shop')
  end
end

#Visa sidan för att registrera användare.
get('/') do
  slim(:"public/register")
end

#Visa affärssidan och skicka med all information för varje produkt.
get('/shop') do
  db = connect_to_db('db/shop.db')
  id = session[:id].to_i  
  result = db.execute("SELECT * FROM product")
  result2 = db.execute("SELECT * FROM seller")
  result3 = db.execute("SELECT * FROM users WHERE id = ?",session[:id])
  result4 = db.execute("SELECT * FROM reviews")
  result5 = db.execute("SELECT * FROM users")
  slim(:"public/index",locals:{webshop:result,seller:result2,roll:result3,reviewer:result4,user:result5})
end

get('/sellers') do
  db = connect_to_db('db/shop.db')
  id = session[:id].to_i  
  result = db.execute("SELECT * FROM seller")
  result3 = db.execute("SELECT * FROM users WHERE id = ?",session[:id])
  slim(:"public/sellers",locals:{seller:result,roll:result3})
end

#Visa sidan för den nuvarande användarens kundvagn.
get('/cart') do
  db = connect_to_db('db/shop.db')
  id = session[:id].to_i  
  product = db.execute("SELECT product.id, product.price, product.description, product.name, product.seller_id FROM buy_relation INNER JOIN product ON buy_relation.product_id = product.id WHERE user_id = ?", session[:id])
  seller = db.execute("SELECT * FROM seller")
  slim(:"user/cart",locals:{products:product, sellers:seller})
end

#Login-funktion som också ser ifall användaren försöker spamma sig in.
post('/login') do
  time1 = params[:current].to_i
  time2 = Time.now.to_i
  p time2-time1
  if (time2 - time1 >= 2)
    username = params[:username]
    password = params[:password]
    db = connect_to_db('db/shop.db')
    result = db.execute("SELECT * FROM users WHERE username = ?",username).first
    pwdigest = result["pwdigest"]
    id = result["id"]
    if BCrypt::Password.new(pwdigest) == password
      session[:id] = id
      redirect('/shop')
    else
      "Fel lösenord"
    end
  else
    redirect('/showlogin')
  end
end

#Funktion för att skapa en ny användare.
post('/users/new') do
  username = params[:username].to_s
  password = params[:password].to_s
  password_confirm = params[:password_confirm].to_s
  if (password == password_confirm) && username != "" && password != "" && password.to_i == 0 && username.to_i == 0
    password_digest = BCrypt::Password.create(password)
    db = SQLite3::Database.new('db/shop.db')
    db.execute('INSERT INTO users (username,pwdigest,role) VALUES (?,?,?)',username,password_digest,0)
    redirect('/showlogin')
  else
    "Lösenorden är inte samma, rutor är tomma eller användarnamn och lösenord består endast av nummer"
  end
end

#Funktion för att lägga till en produkt i product-tabellen.
post ('/shop/') do
  db = connect_to_db('db/shop.db')
  result = db.execute("SELECT role FROM users WHERE id = ?",session[:id]).first
  if result["role"] == 1
    productname = params[:productname]
    description = params[:description]
    cost = params[:cost]
    seller = params[:seller]
    db = SQLite3::Database.new('db/shop.db')
    if seller.to_i != 0 && cost.to_i != 0 && productname != "" && description != "" && cost != "" && seller != ""
      db.execute('INSERT INTO product (name,price,description,seller_id) VALUES (?,?,?,?)',productname,cost.to_i,description,seller.to_i)
    end
  end
  redirect('/shop')
end

#Create seller
post ('/sellers/new') do
  db = connect_to_db('db/shop.db')
  sellerf = params[:fname]
  sellers = params[:sname]
  db.execute('INSERT INTO seller (firstname,surname) VALUES (?,?)',sellerf,sellers)
  redirect('/sellers')
end

#Ta bort säljare
post('/seller/:id/delete') do
  db = connect_to_db('db/shop.db')
  sellerid = params[:sell_id].to_i
  items = db.execute('SELECT * FROM product WHERE seller_id = ?',sellerid)
  db.execute('DELETE FROM product WHERE seller_id = ?',sellerid)
  items.each do |current|
    db.execute('DELETE FROM buy_relation WHERE product_id = ?',current["id"])
  end
  db.execute('DELETE FROM seller WHERE id = ?',sellerid)
  redirect('/sellers')
end

#Uppdatera säljare
post('/seller/:id/update') do
  db = connect_to_db('db/shop.db')
  sellerf = params[:fname]
  sellers = params[:sname]
  seller = params[:sell_id].to_i
  db.execute('UPDATE seller SET firstname = ?, surname = ? WHERE id = ?',sellerf,sellers,seller)
  redirect('/sellers')
end

#Funktion för att lägga till föremål i kundvagnen.
post('/cart/update') do
  buyid = params[:product_id].to_i
  id = session[:id].to_i
  db = SQLite3::Database.new('db/shop.db')
  db.execute('INSERT INTO buy_relation (user_id,product_id) VALUES (?,?)',id,buyid)
  redirect('/shop')
end

#Funktion för att ta bort ett föremål från kundvagnen.
post('/cart/:id/delete') do
  usrid = session[:id].to_i
  prodid = params[:product_id].to_i
  db = SQLite3::Database.new('db/shop.db')
  db.execute('DELETE FROM buy_relation WHERE user_id = ? AND product_id = ?',usrid,prodid)
  redirect('/cart')
end

#Funktion för att ta bort ett förmål från product-tabellen.
post('/shop/:id/delete') do
  db = connect_to_db('db/shop.db')
  result = db.execute("SELECT role FROM users WHERE id = ?",session[:id]).first
  if result["role"] == 1
    itemid = params[:product_id].to_i
    db = SQLite3::Database.new('db/shop.db')
    db.execute('DELETE FROM product WHERE id = ?',itemid)
    db.execute('DELETE FROM buy_relation WHERE product_id = ?',itemid)
  end
  redirect('/shop')
end

#Funktion för att rensa/köpa kundvagnen
post('/cart/delete') do
  db = SQLite3::Database.new('db/shop.db')
  db.execute('DELETE FROM buy_relation WHERE user_id = ?',session[:id])
  redirect('/shop')
end

#Funktion för att redigera data för en rad i product-tabellen.
post('/shop/:id/update') do
  db = connect_to_db('db/shop.db')
  result = db.execute("SELECT role FROM users WHERE id = ?",session[:id]).first
  if result["role"] == 1
    name = params[:Namn]
    description = params[:Beskrivning]
    price = params[:Kostnad].to_i
    seller = params[:saljare].to_i
    prodid = params[:product_id]
    db = SQLite3::Database.new('db/shop.db')
    if seller != 0 && price != 0 && name != "" && description != ""
      db.execute('UPDATE product SET name = ?, description = ?, price = ?, seller_id = ? WHERE id = ?',name,description,price.to_i,seller.to_i,prodid)
    end
  end
  redirect('/shop')
end
