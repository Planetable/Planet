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

    func checkPlanetLink(_ url: URL) -> (mime: MyPlanetModel?, following: FollowingPlanetModel?) {
        var link = url.absoluteString.trim()
        if link.starts(with: "planet://") {
            link = String(link.dropFirst("planet://".count))
        }
        var mime: MyPlanetModel?
        var following: FollowingPlanetModel?
        if let existingPlanet = myPlanets.first(where: { $0.ipns == link }) {
            mime = existingPlanet
        }
        if let existingFollowingPlanet = followingPlanets.first(where: { $0.link == link }
        ) {
            following = existingFollowingPlanet
        }
        return (mime, following)
    }

    func checkArticleLink(_ url: URL) -> (mime: MyPlanetModel?, following: FollowingPlanetModel?, myArticle: MyArticleModel?, followingArticle: FollowingArticleModel?) {
        let idString = url.deletingLastPathComponent().lastPathComponent
        let uuidString = url.lastPathComponent
        let tagString = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent

        var mime: MyPlanetModel?
        var following: FollowingPlanetModel?
        var myArticle: MyArticleModel?
        var followingArticle: FollowingArticleModel?

        if tagString == "ipns" {
            if let existingPlanet = myPlanets.first(where: { $0.ipns == idString }) {
                mime = existingPlanet
            }
            if mime != nil {
                for myPlanet in myPlanets {
                    if let targetArticle = myPlanet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                        myArticle = targetArticle
                        break
                    }
                }
            }
            if mime == nil {
                if let existingFollowingPlanet = followingPlanets.first(where: { $0.link == idString }
                ) {
                    following = existingFollowingPlanet
                }
                if following != nil {
                    for planet in followingPlanets {
                        if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                            followingArticle = targetArticle
                            break
                        }
                    }
                }
            }
        }
        else if tagString == "ipfs" {
            if let existingPlanet = myPlanets.first(where: { $0.ipns == idString }) {
                mime = existingPlanet
            }
            if mime != nil {
                for myPlanet in myPlanets {
                    if let targetArticle = myPlanet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                        myArticle = targetArticle
                        break
                    }
                }
            }
        }
        else if let host = url.host, host.hasSuffix(".eth.limo"), uuidString != "" {
            for myPlanet in myPlanets {
                if let targetArticle = myPlanet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                    myArticle = targetArticle
                    mime = myPlanet
                    break
                }
            }
            for planet in followingPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }) {
                    followingArticle = targetArticle
                    following = planet
                    break
                }
            }
        }

        return (mime, following, myArticle, followingArticle)
    }

    deinit {
        myPlanets.removeAll()
        followingPlanets.removeAll()
    }
}
