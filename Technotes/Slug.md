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

In the RSS feed and the podcast feed, an item's `<link>` is the slug folder when the article has a slug. Its `<guid>` stays the UUID folder: a slug can be changed or removed later, and a feed reader that identifies an item by its `<guid>` must not take an old article for a new one. The enclosure and the image addresses in the description also stay under the UUID folder.

Planet itself identifies an article of a followed or aggregated feed by its `<link>`. A site that is followed or aggregated by the HTTP address of its feed therefore shows each article that has a slug once more after the site is published with this change. A site followed by its IPNS, ENS or DNSLink name is read from `planet.json`, whose links were already slugs.
