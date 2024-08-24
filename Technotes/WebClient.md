# Web Client

This note is a plan for the upcoming web client. When you access the API port, its homepage should be a simple web page that you can use as a web client to talk to the API server.

### Homepage: / redirects to -> /v0/view

- List all my planets
- Click item title to view details of a planet
- Change details of a planet
- On the view page of a planet, list all of its articles

### Planet: /v0/planets/my/:uuid/view

- Details of a planet

### Article: /v0/planets/my/:uuid/articles/:uuid/view

- Details of an article