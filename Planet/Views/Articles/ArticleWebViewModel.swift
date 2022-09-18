//
//  ArticleWebViewModel.swift
//  Planet
//
//  Created by Kai on 9/1/22.
//

import Foundation


class ArticleWebViewModel: NSObject {
    static let shared: ArticleWebViewModel = ArticleWebViewModel()

    lazy var linkValidationQueue: DispatchQueue = {
        let q = DispatchQueue(label: "xyz.planetable.article.validation")
        return q
    }()

    private var internalLinks: [URL] = []

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

    private func checkPlanetLink(_ url: URL) -> (mine: MyPlanetModel?, following: FollowingPlanetModel?) {
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

    private func checkArticleLink(_ url: URL) -> (mine: MyPlanetModel?, following: FollowingPlanetModel?, myArticle: MyArticleModel?, followingArticle: FollowingArticleModel?) {
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

    @MainActor
    private func checkMyArticleInCurrentList(_ article: MyArticleModel) -> Bool {
        var articleList: [MyArticleModel] = []
        if let currentList = PlanetStore.shared.selectedArticleList {
            for a in currentList {
                if let myArticle = a as? MyArticleModel {
                    articleList.append(myArticle)
                }
            }
        }
        let finalArticleList = articleList
        return finalArticleList.contains(article)
    }

    @MainActor
    private func checkFollowingArticleInCurrentList(_ article: FollowingArticleModel) -> Bool {
        var articleList: [FollowingArticleModel] = []
        if let currentList = PlanetStore.shared.selectedArticleList {
            for a in currentList {
                if let followingArticle = a as? FollowingArticleModel {
                    articleList.append(followingArticle)
                }
            }
        }
        let finalArticleList = articleList
        return finalArticleList.contains(article)
    }

    func processInternalFileLink(_ fileLink: URL) {
        guard let possibleArticleUUID = UUID(uuidString: fileLink.lastPathComponent) else { return }
        guard let targetLink = URL(string: "planet://" + possibleArticleUUID.uuidString) else { return }
        var existings = ArticleWebViewModel.shared.checkArticleLink(targetLink)
        defer {
            existings.mine = nil
            existings.following = nil
            existings.myArticle = nil
            existings.followingArticle = nil
        }
        if let mine = existings.mine, let myArticle = existings.myArticle {
            Task.detached { @MainActor in
                PlanetStore.shared.selectedView = .myPlanet(mine)
                Task { @MainActor in
                    PlanetStore.shared.selectedArticle = myArticle
                    PlanetStore.shared.refreshSelectedArticles()
                }
            }
        }
        else if let following = existings.following, let followingArticle = existings.followingArticle {
            Task.detached { @MainActor in
                PlanetStore.shared.selectedView = .followingPlanet(following)
                Task { @MainActor in
                    PlanetStore.shared.selectedArticle = followingArticle
                    PlanetStore.shared.refreshSelectedArticles()
                }
            }
        }
    }

    func processPossibleInternalLink(_ link: URL) {
        debugPrint("processing possible internal link: \(link)")
        var isInternalLink: Bool = false
        defer {
            debugPrint("possible link: \(link) -> \(isInternalLink)")
        }

        if link.isPlanetLink {
            isInternalLink = true

            var existings = ArticleWebViewModel.shared.checkPlanetLink(link)
            defer {
                existings.mine = nil
                existings.following = nil
            }

            if let myPlanet: MyPlanetModel = existings.mine {
                Task.detached { @MainActor in
                    PlanetStore.shared.selectedView = .myPlanet(myPlanet)
                }
            } else if let followingPlanet: FollowingPlanetModel = existings.following {
                Task.detached { @MainActor in
                    PlanetStore.shared.selectedView = .followingPlanet(followingPlanet)
                }
            } else {
                var existings = checkArticleLink(link)
                defer {
                    existings.mine = nil
                    existings.following = nil
                    existings.myArticle = nil
                    existings.followingArticle = nil
                }
                if let mine = existings.mine, let myArticle = existings.myArticle {
                    Task.detached { @MainActor in
                        if let aList = PlanetStore.shared.selectedArticleList, aList.contains(myArticle) {
                        } else {
                            PlanetStore.shared.selectedView = .myPlanet(mine)
                            Task { @MainActor in
                                PlanetStore.shared.selectedArticle = myArticle
                                PlanetStore.shared.refreshSelectedArticles()
                            }
                        }
                    }
                } else if let following = existings.following, let followingArticle = existings.followingArticle {
                    Task.detached { @MainActor in
                        if let aList = PlanetStore.shared.selectedArticleList, aList.contains(followingArticle) {
                        } else {
                            PlanetStore.shared.selectedView = .followingPlanet(following)
                            Task { @MainActor in
                                PlanetStore.shared.selectedArticle = followingArticle
                                PlanetStore.shared.refreshSelectedArticles()
                            }
                        }
                    }
                } else {
                    Task.detached { @MainActor in
                        PlanetStore.shared.followingPlanetLink = link.absoluteString
                        PlanetStore.shared.isFollowingPlanet = true
                    }
                }
            }
        } else {
            var existings = checkArticleLink(link)
            defer {
                existings.mine = nil
                existings.following = nil
                existings.myArticle = nil
                existings.followingArticle = nil
            }

            if let mine = existings.mine, let myArticle = existings.myArticle {
                isInternalLink = true
                Task.detached { @MainActor in
                    if !self.checkMyArticleInCurrentList(myArticle) {
                        PlanetStore.shared.selectedView = .myPlanet(mine)
                        Task { @MainActor in
                            PlanetStore.shared.selectedArticle = myArticle
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
            } else if let following = existings.following, let followingArticle = existings.followingArticle {
                isInternalLink = true
                Task.detached { @MainActor in
                    if !self.checkFollowingArticleInCurrentList(followingArticle) {
                        PlanetStore.shared.selectedView = .followingPlanet(following)
                        Task { @MainActor in
                            PlanetStore.shared.selectedArticle = followingArticle
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
            } else {
                debugPrint("TODO: -> \(existings)")
            }
        }
        guard isInternalLink else { return }
        linkValidationQueue.async {
            self.internalLinks.append(link)
        }
    }

    func removeInternalLinks() {
        debugPrint("cleanup internal links")
        linkValidationQueue.async {
            self.internalLinks.removeAll()
        }
    }

    func checkInternalLink(_ link: URL) -> Bool {
        linkValidationQueue.sync {
            let exists: Bool = self.internalLinks.contains(link)
            return exists
        }
    }

    deinit {
        myPlanets.removeAll()
        followingPlanets.removeAll()
    }
}
