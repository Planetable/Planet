# MyArticleModel.slug

MyArticleModel.slug is a new optional attribute for supporting a human-readable URL like this:

https://planetable.eth.limo/feature-update-7/

Instead of the original UUID form:

https://planetable.eth.limo/02732491-C01B-464A-B809-24559150B508/

## Article Settings

A slug can be added to an article in the article settings modal.

Slugs should be all lowercase and only contain letters, numbers, and hyphens.

a-z0-9\-

## Save Public

When publishing (saving for public), in addition to the original UUID folder, a new customized folder will also be created.

## Index and RSS

The index page and the RSS feed should use the new slug for links if available.