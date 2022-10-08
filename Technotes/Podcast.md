# Podcast

## Goal

Planet can produce XML files that work with Apple's Podcast app, Overcast, and Castro.

## MyPlanetModel

According to Apple's specs, some fields are required, so we need to add them to MyPlanetModel to support them.

https://help.apple.com/itc/podcasts_connect/#/itcb54353390

- podcastCategories: [String: [String]] = [:]
- podcastExplicit: Bool = false
- podcastLanguage: String?

To support cover art of the show, it needs a new field similar to Planet.avatar:

- podcastCoverArt

## Categories

These are all categories:

https://podcasters.apple.com/support/1691-apple-podcasts-categories