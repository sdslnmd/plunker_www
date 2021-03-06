coffee = require("coffee-script")
less = require("less")
jade = require("jade")
express = require("express")
expstate = require("express-state")
assets = require("connect-assets")
nconf = require("nconf")
authom = require("authom")
request = require("request")
lactate = require("lactate")
path = require("path")
xmlbuilder = require("xmlbuilder")
es = require("event-stream")
JSONStream = require("JSONStream")

pkginfo = require("./package.json")


# Set defaults in nconf
require "./configure"


app = module.exports = express()

expstate.extend(app)


github = authom.createServer
  service: "github"
  id: nconf.get("oauth:github:id")
  secret: nconf.get("oauth:github:secret")
  scope: ["gist"]
  
lactateOptions = 
  "max age": "one week"
  
assetOptions =
  src: "#{__dirname}/assets"
  buildDir: "build"
  buildFilenamer: (filename) ->
    dir = path.dirname(filename)
    ext = path.extname(filename)
    base = path.basename(filename, ext)
    
    return path.join dir, "#{base}-#{pkginfo.version}#{ext}"
  helperContext: app.locals

app.set "views", "#{__dirname}/views"
app.set "view engine", "jade"
app.set "view options", layout: false

app.use require("./middleware/redirect").middleware(nconf.get("redirect"))
app.use express.logger() unless process.env.NODE_ENV is "PRODUCTION"
app.use require("./middleware/vary").middleware()
app.use lactate.static "#{__dirname}/build", lactateOptions
app.use lactate.static "#{__dirname}/assets", lactateOptions
app.use "/css/font", lactate.static("#{__dirname}/assets/vendor/Font-Awesome-More/font/", lactateOptions)

if nconf.get("NODE_ENV") is "production"
  console.log "Starting Plunker in: PRODUCTION"
  app.locals.js = (route) -> """<script src="/js/#{route}-#{pkginfo.version}.js"></script>"""
  app.locals.css = (route) -> """<link rel="stylesheet" href="/css/#{route}-#{pkginfo.version}.css" />"""
else
  console.log "Starting Plunker in: DEVELOPMENT"
  app.use assets(assetOptions)
  
app.use express.cookieParser()
app.use express.bodyParser()

app.expose nconf.get("url"), "_plunker.url"
app.expose pkginfo, "_plunker.package"
app.expose null, "_plunker.bootstrap"
    
app.use app.router

app.use express.errorHandler()

addSession = require("./middleware/session").middleware()



app.get "/partials/:partial", (req, res, next) ->
  res.render "partials/#{req.params.partial}"

app.get "/edit/*", addSession, (req, res, next) ->
  res.render "editor"
  
app.all "/edit/", addSession, (req, res, next) ->
  res.header("Access-Control-Allow-Origin", req.headers.origin or "*")
  res.header("Access-Control-Allow-Methods", "OPTIONS,GET,PUT,POST,DELETE")
  res.header("Access-Control-Allow-Headers", "Authorization, User-Agent, Referer, X-Requested-With, Proxy-Authorization, Proxy-Connection, Accept-Language, Accept-Encoding, Accept-Charset, Connection, Content-Length, Host, Origin, Pragma, Accept-Charset, Cache-Control, Accept, Content-Type")
  res.header("Access-Control-Expose-Headers", "Link")
  res.header("Access-Control-Max-Age", "60")

  if "OPTIONS" == req.method then res.send(200)
  else next()

app.post "/edit/", addSession, (req, res, next) ->    
  res.header "X-XSS-Protection", 0
  
  bootstrap =
    description: req.body.description or ""
    tags: req.body.tags or []
    files: {}
    'private': req.body.private != "false"

  if req.body.files
    for filename, file of req.body.files
      bootstrap.files[filename] =
        filename: filename
        content: if typeof file is "string" then file else file.content or ""
      
  res.expose bootstrap, "_plunker.bootstrap"
  res.render "editor"

app.all "/edit", addSession, (req, res, next) -> res.redirect("/edit/", 302)

# /////////////////////////////////

app.get "/auth/:service", addSession, (req, res, next) ->
  req.headers.host = nconf.get("host")
  
  authom.app(arguments...)


authom.on "auth", (req, res, auth) ->
  res.expose auth, "_plunker.auth"
  res.render "auth/success"


authom.on "error", (req, res, auth) ->
  console.log "Auth error", auth
  res.expose auth, "_plunker.auth"
  res.status 403
  res.render "auth/error"
  
# /////////////////////////////////

apiUrl = nconf.get("url:api")
wwwUrl = nconf.get("url:www")

app.get "/sitemap.xml", (req, res) ->
  outstanding = 0
  
  urlset = xmlbuilder.create "urlset",
    version: "1.0"
    encoding: "UTF-8"
  
  urlset.attribute "xmlns", "http://www.sitemaps.org/schemas/sitemap/0.9"
  
  finalize = ->
    res.set('Content-Type', 'application/xml')
    res.send(urlset.end())
  
  complete = -> finalize() unless --outstanding > 0
  
  outstanding++
  plunks = request("#{apiUrl}/plunks?pp=40000").pipe(JSONStream.parse([true])).pipe es.mapSync (plunk) ->
    url = urlset.ele("url")
    url.ele("loc").text("#{wwwUrl}/#{plunk.id}").up()
    url.ele("lastmod").text(plunk.updated_at).up()
    url.ele("changefreq").text("daily").up()
    url.up()
  
  plunks.on "end", complete
  

apiUrl = nconf.get("url:api")

app.get "/catalogue", addSession, (req, res) -> res.render "packages"
app.get "/catalogue/*", addSession, (req, res) -> res.render "packages"


app.get "/plunks", addSession, (req, res) -> res.render "landing"
app.get "/plunks/trending", addSession, (req, res) -> res.render "landing"
app.get "/plunks/popular", addSession, (req, res) -> res.render "landing"
app.get "/plunks/recent", addSession, (req, res) -> res.render "landing"
app.get "/plunks/views", addSession, (req, res) -> res.render "landing"

app.get "/users", addSession, (req, res) -> res.render "landing"
app.get "/users/:username", addSession, (req, res) -> res.render "landing"

app.get "/group", addSession, (req, res) -> res.render "landing"

app.get "/tags", addSession, (req, res) -> res.render "landing"
app.get "/tags/:tagname", addSession, (req, res) -> res.render "landing"

app.get "/:id", addSession, (req, res) ->
  request.get "#{apiUrl}/plunks/#{req.params.id}", (err, response, body) ->
    return res.send(500) if err
    return res.send(response.statusCode) if response.statusCode >= 400
    
    try
      plunk = JSON.parse(body)
    catch e
      return res.render "landing"
    
    res.locals.bootstrap =
      plunks: [plunk]
      page_title: plunk.description
    res.render "landing"

app.get "/*", addSession, (req, res) ->
  res.render "landing"
