# Planet RESTful API

Please refer to PlanetAPIController.swift mark *Planet Public API* for more details.

### List all my Planets: ```GET /v0/planets/my```
```
curl -X GET http://localhost:8086/v0/planets/my
```
Returns:
```
[
    {
        "id": "9191EE94-312A-466D-979A-9BEC7D0F450A",
        "name": "Hello Planet",
        "about": "Say hi to planet",
        ...
    }
]
```

### Create a new Planet: ```POST /v0/planets/my```

Inputs:
- name: String
- about: String
- template: String
- avatar: Image file in JPEG, PNG, GIF format, 5MB max.

Parameter title is required.

```
curl -X POST http://localhost:8086/v0/planets/my \
  -H 'Content-Type: multipart/form-data' \
  -F 'name=New Planet' \
  -F 'about=Say hi to planet' \
  -F 'template=Grid' \
  -F 'avatar=@/path/to/image.jpg'
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "name": "New Planet",
    "about": "Say hi to planet",
    ...
}
```

### Info of a specific planet: ```GET /v0/planets/my/:uuid```
```
curl -X GET http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "name": "New Planet",
    "about": "Say hi to planet",
    ...
}
```

### Modify my Planet: ```POST /v0/planets/my/:uuid```

Inputs:
- name: String
- about: String
- template: String
- avatar: Image file in JPEG, PNG, GIF format, 5MB max.

```
curl -X POST http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A \
  -H 'Content-Type: multipart/form-data' \
  -F 'name=Updated New Planet' \
  -F 'avatar=@/path/to/image.jpg'
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "name": "Updated New Planet",
    "about": "Say hi to planet",
    ...
}
```


### Delete my Planet: ```DELETE /v0/planets/my/:uuid```
```
curl -X DELETE http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "name": "Updated New Planet",
    "about": "Say hi to planet",
    ...
}
```


### Publish my Planet: ```POST /v0/planets/my/:uuid/publish```
```
curl -X POST http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/publish
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "name": "Updated New Planet",
    "about": "Say hi to planet",
    ...
}
```

### Expose public content built: ```GET /v0/planets/my/:uuid/public```

Note:

Public content resources available at:
- ```GET /:planet_uuid/avatar.png```
- ```GET /:planet_uuid/:article_uuid/attachment_image.png```

```
curl -X GET http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/public
```
Returns:
```
<!DOCTYPE html>
...
```


### List articles under My Planet: ```GET /v0/planets/my/:uuid/articles```
```
curl -X GET http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/articles
```
Returns:
```
[
    {
        "id": "12345678-312A-466D-979A-9BEC7D0F450A",
        "title": "Hello Article",
        "content": "Say hi to article",
        ...
    }
]
```


### Create a new Article: ```POST /v0/planets/my/:uuid/articles```

Inputs:
- title: String
- date: String
- content: String
- attachments: file at any supported type, 50MB max in total.

Parameter title or content is required; Parameter date is optional in ISO 8601 format.

```
curl -X POST http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/articles \
  -H 'Content-Type: multipart/form-data' \
  -F 'title=New Article' \
  -F 'date=2024-12-01T15:00:00Z' \
  -F 'content=Say hi to article. <img src="image.jpg" />' \
  -F 'attachments[0]=@/path/to/image.jpg'
```
Returns:
```
{
    "id": "12345678-1234-466D-979A-9BEC7D0F450A",
    "title": "New Article",
    "content": "Say hi to article. <img src="image.jpg" />",
    ...
}
```
  

### Get an article: ```GET /v0/planets/my/:planet_uuid/articles/:article_uuid```
```
curl -X GET http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/articles/12345678-1234-466D-979A-9BEC7D0F450A
```
Returns:
```
{
    "id": "12345678-312A-466D-979A-9BEC7D0F450A",
    "title": "New Article",
    "content": "Say hi to article. <img src="image.jpg" />",
    ...
}
```


### Modify an article: ```POST /v0/planets/my/:planet_uuid/articles/:article_uuid```

Inputs:
- title: String
- date: String
- content: String
- attachments: file at any supported type, 50MB max in total.

```
curl -X POST http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/articles/12345678-1234-466D-979A-9BEC7D0F450A \
  -H 'Content-Type: multipart/form-data' \
  -F 'title=Updated Article' \
  -F 'content=Say hi to article. <img src="image.jpg" />'
```
Returns:
```
{
    "id": "12345678-1234-466D-979A-9BEC7D0F450A",
    "title": "Updated Article",
    "content": "Say hi to article. <img src="image.jpg" />",
    ...
}
```


### Delete an article: ```DELETE /v0/planets/my/:planet_uuid/articles/:article_uuid```
```
curl -X DELETE http://localhost:8086/v0/planets/my/12345678-312A-466D-979A-9BEC7D0F450A/articles/12345678-1234-466D-979A-9BEC7D0F450A
```
Returns:
```
{
    "id": "12345678-1234-466D-979A-9BEC7D0F450A",
    "title": "Updated Article",
    "content": "Say hi to article. <img src="image.jpg" />",
    ...
}
```


### Search My Planets and articles: ```GET /v0/search?q=<term>```

Searches across My Planets (by name and about) and their articles (by title, slug, tags, attachments, and content). Case-insensitive and diacritics-insensitive.

```
curl -X GET http://localhost:8086/v0/search?q=hello
```
Returns:
```
{
    "planets": [
        {
            "id": "12345678-312A-466D-979A-9BEC7D0F450A",
            "name": "Hello World Blog",
            "about": "Say hi to planet",
            "created": "2024-01-15T10:30:00Z",
            "updated": "2024-06-20T14:22:00Z"
        }
    ],
    "articles": [
        {
            "articleID": "12345678-1234-466D-979A-9BEC7D0F450A",
            "articleCreated": "2024-06-19T09:15:00Z",
            "title": "Hello from Planet",
            "preview": "this is a hello world post about...",
            "planetID": "12345678-312A-466D-979A-9BEC7D0F450A",
            "planetName": "Hello World Blog"
        }
    ]
}
```