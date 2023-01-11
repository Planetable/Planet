# API

It would enable many new possibilities if we could provide a RESTful API.

Here are some initial ideas.

## My Planet

* GET /v0/planets/my - List all my Planets
* POST /v0/planets/my - Create a new Planet

* GET /v0/planets/my/:uuid - Info of a specific My Planet
* POST /v0/planets/my/:uuid - Modify my Planet
* POST /v0/planets/my/:uuid/publish - Publish My Planet
* GET /v0/planets/my/:uuid/public - Expose the content built

* GET /v0/planets/my/:uuid/articles - List articles under My Planet
* POST /v0/planets/my/:uuid/articles - Create a new Article
  
* GET /v0/planets/my/:uuid/articles/:uuid - Get an article by UUID
* POST /v0/planets/my/:uuid/articles/:uuid - Modify an article
* DELETE /v0/planets/my/:uuid/articles/:uuid - Delete an article