#
# This is a copy of https://gist.github.com/hadley/144c406871768d0cbe66b0b810160528
# adapted to be an example of how to authenticate with Synapse
# 

library(shiny)
library(httr)
library(rjson)

# OAuth setup --------------------------------------------------------

if (interactive()) {
  # testing url
  options(shiny.port = 8100)
  APP_URL <- "http://127.0.0.1:8100"
} else {
  # deployed URL
  APP_URL <- "https://servername/path-to-app"
}

trimWhitespace<-function(x) {
  sub("^[[:space:]]*(.*?)[[:space:]]*$", "\\1", x, perl=TRUE)
}
config<-readLines("config")
client_id<-NULL
client_secret<-NULL
for (row in config) {
	if (startsWith(row, 'client_id:')) {
		client_id<-trimWhitespace(substring(row, nchar('client_id:')+1))
	}
	if (startsWith(row, 'client_secret:')) {
		client_secret<-trimWhitespace(substring(row, nchar('client_secret:')+1))
	}
}
if (is.null(client_id)) stop("config file is missing client_id")
if (is.null(client_secret)) stop("config file is missing client_secret")

app <- oauth_app("shinysynapse",
  key = client_id,
  secret = client_secret, 
  redirect_uri = APP_URL
)

# These are the user info details ('claims') requested from Synapse:
claims=list(
	family_name=NULL, 
	given_name=NULL,
	email=NULL,
	email_verified=NULL,
	userid=NULL,
	orcid=NULL,
	is_certified=NULL,
	is_validated=NULL,
	validated_given_name=NULL,
	validated_family_name=NULL,
	validated_location=NULL,
	validated_email=NULL,
	validated_company=NULL,
	validated_at=NULL,
	validated_orcid=NULL,
	company=NULL
)

claimsParam<-toJSON(list(id_token=claims,userinfo=claims))
api <- oauth_endpoint(authorize=paste0("https://signin.synapse.org?claims=", claimsParam), access="https://repo-prod.prod.sagebase.org/auth/v1/oauth2/token")

# The 'openid' scope is required by the protocol for retrieving user information.
scope <- "openid"

# Shiny -------------------------------------------------------------------

has_auth_code <- function(params) {
  # params is a list object containing the parsed URL parameters. Return TRUE if
  # based on these parameters, it looks like auth code is present that we can
  # use to get an access token. If not, it means we need to go through the OAuth
  # flow.
  return(!is.null(params$code))
}

userInfoDisplay <- fluidPage(
  # Your regular UI goes here, for when everything is properly auth'd
  verbatimTextOutput("userInfo")
)


# https://stackoverflow.com/questions/57755830/how-to-redirect-to-a-dynamic-url-in-shiny
jscode <- "Shiny.addCustomMessageHandler('mymessage', function(message) { window.location = message;});"

uiFunc <- function(req) {
  if (!has_auth_code(parseQueryString(req$QUERY_STRING))) {
  	# login in button
  	fluidPage(
  		tags$head(tags$script(jscode)),
  		titlePanel("Synapse OAuth Demo"),
  		actionButton("action", "Log in to Synapse")
  	)
  } else {
    userInfoDisplay
  }
}

server <- function(input, output, session) {
  # clicking on the 'Log in' button will kick off the OAuth round trip
  observeEvent(input$action, {
  	session$sendCustomMessage("mymessage", oauth2.0_authorize_url(api, app, scope = scope))
  	return()
  })
  
  params <- parseQueryString(isolate(session$clientData$url_search))
  if (!has_auth_code(params)) {
    return()
  }
  
  url<-paste0(api$access, '?', 'redirect_uri=', APP_URL, '&grant_type=', 'authorization_code' ,'&code=',params$code)
  
  # get the access_token and userinfo token
  req <- POST(url,
      encode = "form",
      body = '',
      authenticate(app$key, app$secret, type = "basic"),
      config = list()
  )
 
  stop_for_status(req, task = "get an access token")
  token_response <-content(req, type = NULL)
  
  
  access_token<-token_response$access_token
  id_token<-token_response$id_token
 
  # now get some actual data
  resp <- GET("https://repo-prod.prod.sagebase.org/auth/v1/oauth2/userinfo", add_headers(Authorization=paste0("Bearer ", access_token)))

  x<-fromJSON(content(resp, "text"))
  formatted<-paste(lapply(names(x), function(n) paste(n, x[n])), collapse="\n")
  output$userInfo <- renderText(formatted)
}

# Note that we're using uiFunc, not ui!
shinyApp(uiFunc, server)

