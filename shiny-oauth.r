#
# This is a copy of https://gist.github.com/hadley/144c406871768d0cbe66b0b810160528
# adapted to be an example of how to authenticate with Synapse
# 

library(shiny)
library(httr)
library(rjson)

# OAuth setup --------------------------------------------------------

# Most OAuth applications require that you redirect to a fixed and known
# set of URLs. Many only allow you to redirect to a single URL: if this
# is the case for, you'll need to create an app for testing with a localhost
# url, and an app for your deployed app.

if (interactive()) {
  # testing url
  options(shiny.port = 8100)
  APP_URL <- "http://127.0.0.1:8100"
} else {
  # deployed URL
  APP_URL <- "https://servername/path-to-app"
}

app <- oauth_app("shinysynapse",
  key = "",
  secret = "", 
  redirect_uri = APP_URL
)

# Here I'm using a canned endpoint, but you can create with oauth_endpoint()
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

claimsParam=toJSON(list(id_token=claims,userinfo=claims))
api <- oauth_endpoint(authorize=paste0("https://signin.synapse.org?claims=", claimsParam), access="https://repo-prod.prod.sagebase.org/auth/v1/oauth2/token")

scope <- "openid"

# Shiny -------------------------------------------------------------------

has_auth_code <- function(params) {
  # params is a list object containing the parsed URL parameters. Return TRUE if
  # based on these parameters, it looks like auth codes are present that we can
  # use to get an access token. If not, it means we need to go through the OAuth
  # flow.
  return(!is.null(params$code))
}

ui <- fluidPage(
  # Your regular UI goes here, for when everything is properly auth'd
  verbatimTextOutput("code")
)

# A little-known feature of Shiny is that the UI can be a function, not just
# objects. You can use this to dynamically render the UI based on the request.
# We're going to pass this uiFunc, not ui, to shinyApp(). If you're using
# ui.R/server.R style files, that's fine too--just make this function the last
# expression in your ui.R file.
uiFunc <- function(req) {
  if (!has_auth_code(parseQueryString(req$QUERY_STRING))) {
    url <- oauth2.0_authorize_url(api, app, scope = scope)
    redirect <- sprintf("location.replace(\"%s\");", url)
    tags$script(HTML(redirect))
  } else {
    ui
  }
}

server <- function(input, output, session) {
  params <- parseQueryString(isolate(session$clientData$url_search))
  if (!has_auth_code(params)) {
    return()
  }
  
  url_encoded_redirect_uri <- "http%3A%2F%2F127.0.0.1%3A8100" # encoded redirect_uri
  url<-paste0(api$access, '?', 'redirect_uri=', url_encoded_redirect_uri, '&grant_type=', 'authorization_code' ,'&code=',params$code)
  

  
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
 

  resp <- GET("https://repo-prod.prod.sagebase.org/auth/v1/oauth2/userinfo", add_headers(Authorization=paste0("Bearer ", access_token)))
  # TODO: check for success/failure here

  x<-fromJSON(content(resp, "text"))
  formatted<-paste(lapply(names(x), function(n) paste(n, x[n])), collapse="\n")
  output$code <- renderText(formatted)
}

# Note that we're using uiFunc, not ui!
shinyApp(uiFunc, server)

