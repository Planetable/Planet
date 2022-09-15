//
//  ArticleWebViewModel.swift
//  Planet
//
//  Created by Kai on 9/1/22.
//

import Foundation


class ArticleWebViewModel: NSObject {
    static let shared: ArticleWebViewModel = ArticleWebViewModel()

    private var myPlanets: [MyPlanetModel] = []
    private var followingPlanets: [FollowingPlanetModel] = []

    private override init() {}

    @MainActor
    func updateMyPlanets(_ planets: [MyPlanetModel]) {
        myPlanets = planets
    }

    @MainActor
    func updateFollowingPlanets(_ planets: [FollowingPlanetModel]) {
        followingPlanets = planets
    }

    func checkPlanetLink(_ url: URL) -> (mine: MyPlanetModel?, following: FollowingPlanetModel?) {
        var link = url.absoluteString.trim()
        if link.starts(with: "planet://") {
            link = String(link.dropFirst("planet://".count))
        }
        var myPlanet: MyPlanetModel?
        var followingPlanet: FollowingPlanetModel?
        if let existingPlanet = myPlanets.first(where: { $0.ipns == link }) {
            myPlanet = existingPlanet
        }
        if let existingFollowingPlanet = followingPlanets.first(where: { $0.link == link }
        ) {
            followingPlanet = existingFollowingPlanet
        }
        return (myPlanet, followingPlanet)
    }

    func checkArticleLink(_ url: URL) -> (mine: MyPlanetModel?, following: FollowingPlanetModel?, myArticle: MyArticleModel?, followingArticle: FollowingArticleModel?) {
        let idString = url.deletingLastPathComponent().lastPathComponent
        let uuidString = url.lastPathComponent
        let tagString = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent

        var myPlanet: MyPlanetModel?
        var followingPlanet: FollowingPlanetModel?
        var myArticle: MyArticleModel?
        var followingArticle: FollowingArticleModel?

        if tagString == "ipns" {
            if let existingPlanet = myPlanets.first(where: { $0.ipns == idString }) {
                myPlanet = existingPlanet
            }
            if myPlanet != nil {
                for planet in myPlanets {
                    if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                        myArticle = targetArticle
                        break
                    }
                }
            }
            if myPlanet == nil {
                if let existingFollowingPlanet = followingPlanets.first(where: { $0.link == idString }
                ) {
                    followingPlanet = existingFollowingPlanet
                }
                if followingPlanet != nil {
                    for planet in followingPlanets {
                        if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                            followingArticle = targetArticle
                            break
                        }
                    }
                }
            }
        }
        else if uuidString != "", tagString == "ipfs", let _ = url.host {
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        else if let _ = url.host, uuidString != "" {
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        else if uuidString == "", let host = url.host, let relativeUUID = UUID(uuidString: host) {
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(relativeUUID.uuidString)/" }) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: { $0.link == "/\(relativeUUID.uuidString)/" }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        return (myPlanet, followingPlanet, myArticle, followingArticle)
    }

    deinit {
        myPlanets.removeAll()
        followingPlanets.removeAll()
    }
}
