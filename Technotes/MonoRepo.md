# Mono Repo

## Templates

Currently, we use one Swift package repo:

https://github.com/Planetable/PlanetSiteTemplates

To include all built-in templates:

- https://github.com/Planetable/SiteTemplatePlain
- https://github.com/Planetable/SiteTemplate8bit

It would save time when packaging if we could figure out a way to use a mono repo for all the templates. But how would that work with the current Template Browser directory design? It expects a Templates folder under Planet under Document inside the data container.

```
~/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Templates
```