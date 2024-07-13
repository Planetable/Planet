//
//  ArticleListViewModel.swift
//  Planet
//
//  Created by Xin Liu on 7/13/24.
//

import Foundation


enum ListViewFilter: String, CaseIterable {
    case all = "All"
    case pages = "Pages"
    case nav = "Navigation Items"
    case unread = "Unread"
    case starred = "Starred"

    case star = "Star"

    case plan = "Plan"
    case todo = "To Do"
    case done = "Done"

    case sparkles = "Sparkles"
    case heart = "Heart"
    case question = "Question"
    case paperplane = "Paperplane"

    static let buttonLabels: [String: String] = [
        "All": "Show All",
        "Pages": "Show Pages",
        "Navigation Items": "Show Navigation Items",
        "Unread": "Show Unread",
        "Starred": "Show All Starred",
    ]

    static let emptyLabels: [String: String] = [
        "All": "No Articles",
        "Pages": "No Pages",
        "Navigation Items": "No Navigation Items",
        "Unread": "No Unread Articles",
        "Starred": "No Starred Articles",
        "Star": "No Starred Articles",
        "Plan": "No Items with Plan Type",
        "To Do": "No Items with To Do Type",
        "Done": "No Items with Done Type",
        "Sparkles": "No Items with Sparkles Type",
        "Heart": "No Items with Heart Type",
        "Question": "No Items with Question Type",
        "Paperplane": "No Items with Paperplane Type",
    ]

    static let imageNames: [String: String] = [
        "All": "line.3.horizontal.circle",
        "Pages": "doc.text",
        "Navigation Items": "link.circle",
        "Unread": "line.3.horizontal.circle.fill",
        "Starred": "star.fill",
        "Star": "star.fill",
        "Plan": "circle.dotted",
        "To Do": "circle",
        "Done": "checkmark.circle.fill",
        "Sparkles": "sparkles",
        "Heart": "heart.fill",
        "Question": "questionmark.circle.fill",
        "Paperplane": "paperplane.circle.fill",
    ]
}


class ArticleListViewModel: ObservableObject {
    static let shared = ArticleListViewModel()

    @Published var articles: [ArticleModel] = []
    @Published var filter: ListViewFilter = .all
}
