# ShinyOAuthExample
Example of authenticating with Synapse from a Shiny application using the OAuth / Open ID Connect protocol

```r

library(synapser)
library(rjson)
synLogin()
# customize your client name
client_name<-'Shiny OAuth Demo'
client<-list(client_name=client_name, redirect_uris=list('http://127.0.0.1:8100'))
client<-synRestPOST('/oauth2/client', toJSON(client), 'https://repo-prod.prod.sagebase.org/auth/v1')
client_id_and_secret<-synRestPOST(paste0('/oauth2/client/secret/',client$client_id), '', 'https://repo-prod.prod.sagebase.org/auth/v1')

```

Now fill in `key` and `secret` in the call to `oauth_app()` (appx. ll. 27-28) with the values from `client_id_and_secret`, then run `shiny-oauth-r`.

