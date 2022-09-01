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
        debugPrint("checking planet link: \(link)")
        debugPrint("my planets: \(myPlanets)")
        debugPrint("following planets: \(followingPlanets)")
        var mime: MyPlanetModel?
        var following: FollowingPlanetModel?
//        if let existingPlanet = await myPlanets.first(where: { $0.link == link }) {
//            mime = existingPlanet
//        }
        if let existingFollowingPlanet = followingPlanets.first(where: { $0.link == link }
        ) {
            following = existingFollowingPlanet
//            await MainActor.run {
//                PlanetStore.shared.selectedView = .followingPlanet(existing)
//            }
//            throw PlanetError.PlanetExistsError
        }
        return (mime, following)
    }

    func checkArticleLink(_ url: URL) -> (mime: MyPlanetModel?, following: FollowingPlanetModel?, myArticle: MyArticleModel?, publicArticle: PublicArticleModel?) {
        debugPrint("checking article link: \(link)")
        debugPrint("my planets: \(myPlanets)")
        debugPrint("following planets: \(followingPlanets)")

        var mime: MyPlanetModel?
        var following: FollowingPlanetModel?
        var myArticle: MyArticleModel?
        var publicArticle: PublicArticleModel?

        return (mime, following, myArticle, publicArticle)
    }

    deinit {
        myPlanets.removeAll()
        followingPlanets.removeAll()
    }
}
