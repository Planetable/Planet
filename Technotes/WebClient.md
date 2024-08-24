# Web Client

This note is a plan for the upcoming web client. When you access the API port, its homepage should be a simple web page that you can use as a web client to talk to the API server.

## Why

As a Planet user, I run the app on my primary Mac, but sometimes I want to add content to Planet from my other devices. I do not want to install anything on my other devices, so a simple yet easy-to-use web client would be great.

## Endpoints

### Homepage: / redirects to -> /v0/view

- List all my planets
- Click item title to view details of a planet
- Change details of a planet
- On the view page of a planet, list all of its articles

### Planet: /v0/planets/my/:uuid/view

- Details of a planet

### Article: /v0/planets/my/:uuid/articles/:uuid/view

- Details of an article