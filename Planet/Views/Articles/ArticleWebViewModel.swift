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

    private func checkPlanetLink(_ url: URL) -> (
        mine: MyPlanetModel?, following: FollowingPlanetModel?
    ) {
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

    private func checkArticleLink(_ url: URL) -> (
        mine: MyPlanetModel?, following: FollowingPlanetModel?, myArticle: MyArticleModel?,
        followingArticle: FollowingArticleModel?
    ) {
        debugPrint("checkArticleLink: \(url.absoluteString)")
        let idString = url.deletingLastPathComponent().lastPathComponent
        let uuidString = url.lastPathComponent
        let tagString = url.deletingLastPathComponent().deletingLastPathComponent()
            .lastPathComponent
        debugPrint(
            "checkArticleLink: idString=\(idString) uuidString=\(uuidString) tagString=\(tagString)"
        )

        var myPlanet: MyPlanetModel?
        var followingPlanet: FollowingPlanetModel?
        var myArticle: MyArticleModel?
        var followingArticle: FollowingArticleModel?

        if tagString == "ipns" {
            // TODO: Include an example here
            if let existingPlanet = myPlanets.first(where: { $0.ipns == idString }) {
                myPlanet = existingPlanet
            }
            if myPlanet != nil {
                for planet in myPlanets {
                    if let targetArticle = planet.articles.first(where: {
                        $0.link == "/\(uuidString)/"
                    }) {
                        myArticle = targetArticle
                        break
                    }
                }
            }
            if myPlanet == nil {
                if let existingFollowingPlanet = followingPlanets.first(where: {
                    $0.link == idString
                }
                ) {
                    followingPlanet = existingFollowingPlanet
                }
                if followingPlanet != nil {
                    for planet in followingPlanets {
                        if let targetArticle = planet.articles.first(where: {
                            $0.link == "/\(uuidString)/"
                        }) {
                            followingArticle = targetArticle
                            break
                        }
                    }
                }
            }
        }
        else if uuidString != "", tagString == "Planet", idString == "Public" {
            // Example:
            // file:///Users/user/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Public/D73B55BD-A86E-46AB-9345-6CCFCB3811EC/
            // homepage of my planet
            for planet in myPlanets {
                if planet.id.uuidString == uuidString {
                    myPlanet = planet
                    break
                }
            }
        }
        else if uuidString != "", tagString == "Public" {
            // Example:
            // file:///Users/user/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Public/D73B55BD-A86E-46AB-9345-6CCFCB3811EC/insider-build/
            // file:///Users/livid/Library/Containers/xyz.planetable.Planet/Data/Documents/Planet/Public/7AAD5722-B4B1-48E6-B001-078286971D2D/juicebox/
            // Internal link in my planet with slug
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: {
                    $0.link == "/\(uuidString)/" || $0.slug == uuidString
                        || $0.id.uuidString == uuidString
                }), planet.id.uuidString == idString {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
        }
        else if uuidString != "", tagString == "ipfs", let _ = url.host {
            // TODO: Include an example URL here
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }
                ) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: {
                        $0.link == "/\(uuidString)/"
                    }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        else if let _ = url.host, uuidString != "" {
            // TODO: Include an example URL here
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: { $0.link == "/\(uuidString)/" }
                ) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: {
                        $0.link == "/\(uuidString)/"
                    }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        else if uuidString == "", let host = url.host, let relativeUUID = UUID(uuidString: host) {
            // TODO: Include an example URL here
            for planet in myPlanets {
                if let targetArticle = planet.articles.first(where: {
                    $0.link == "/\(relativeUUID.uuidString)/"
                }) {
                    myArticle = targetArticle
                    myPlanet = planet
                    break
                }
            }
            if myPlanet == nil {
                for planet in followingPlanets {
                    if let targetArticle = planet.articles.first(where: {
                        $0.link == "/\(relativeUUID.uuidString)/"
                    }) {
                        followingArticle = targetArticle
                        followingPlanet = planet
                        break
                    }
                }
            }
        }
        debugPrint(
            "checkArticleLink: myPlanet=\(myPlanet?.ipns ?? "nil") followingPlanet=\(followingPlanet?.link ?? "nil") myArticle=\(myArticle?.title ?? "nil") followingArticle=\(followingArticle?.title ?? "nil")"
        )
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
        guard let targetLink = URL(string: "planet://" + possibleArticleUUID.uuidString) else {
            return
        }
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
        else if let following = existings.following,
            let followingArticle = existings.followingArticle
        {
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

        if link.isPlanetWindowGroupLink {
            debugPrint("planet window group link: \(link), abort.")
            return
        }
        else if link.isPlanetLink {
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
            }
            else if let followingPlanet: FollowingPlanetModel = existings.following {
                Task.detached { @MainActor in
                    PlanetStore.shared.selectedView = .followingPlanet(followingPlanet)
                }
            }
            else {
                var existings = checkArticleLink(link)
                defer {
                    existings.mine = nil
                    existings.following = nil
                    existings.myArticle = nil
                    existings.followingArticle = nil
                }
                if let mine = existings.mine, let myArticle = existings.myArticle {
                    Task.detached { @MainActor in
                        if let aList = PlanetStore.shared.selectedArticleList,
                            aList.contains(myArticle)
                        {
                        }
                        else {
                            PlanetStore.shared.selectedView = .myPlanet(mine)
                        }
                        Task { @MainActor in
                            PlanetStore.shared.selectedArticle = myArticle
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
                else if let mine = existings.mine, existings.myArticle == nil {
                    Task { @MainActor in
                        PlanetStore.shared.selectedArticle = nil
                        PlanetStore.shared.selectedView = .myPlanet(mine)
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                }
                else if let following = existings.following,
                    let followingArticle = existings.followingArticle
                {
                    Task.detached { @MainActor in
                        if let aList = PlanetStore.shared.selectedArticleList,
                            aList.contains(followingArticle)
                        {
                        }
                        else {
                            PlanetStore.shared.selectedView = .followingPlanet(following)
                        }
                        Task { @MainActor in
                            PlanetStore.shared.selectedArticle = followingArticle
                            PlanetStore.shared.refreshSelectedArticles()
                        }
                    }
                }
                else {
                    Task.detached { @MainActor in
                        PlanetStore.shared.followingPlanetLink = link.absoluteString
                        PlanetStore.shared.isFollowingPlanet = true
                    }
                }
            }
        }
        else {
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
                    }
                    Task { @MainActor in
                        PlanetStore.shared.selectedArticle = myArticle
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                }
            }
            else if let mine = existings.mine, existings.myArticle == nil {
                Task { @MainActor in
                    PlanetStore.shared.selectedArticle = nil
                    PlanetStore.shared.selectedView = .myPlanet(mine)
                    PlanetStore.shared.refreshSelectedArticles()
                }
            }
            else if let following = existings.following,
                let followingArticle = existings.followingArticle
            {
                isInternalLink = true
                Task.detached { @MainActor in
                    if !self.checkFollowingArticleInCurrentList(followingArticle) {
                        PlanetStore.shared.selectedView = .followingPlanet(following)
                    }
                    Task { @MainActor in
                        PlanetStore.shared.selectedArticle = followingArticle
                        PlanetStore.shared.refreshSelectedArticles()
                    }
                }
            }
        }
        guard isInternalLink else { return }
        linkValidationQueue.async {
            self.internalLinks.append(link)
        }
    }

    func removeInternalLinks() {
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
