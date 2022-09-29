import SwiftUI

struct ArticleView: View {
    static let noSelectionURL = Bundle.main.url(forResource: "NoSelection.html", withExtension: "")!
    @EnvironmentObject var planetStore: PlanetStore

    @State private var url = Self.noSelectionURL
    @State private var isShowingAnalyticsPopover: Bool = false
    @State private var selectedAttachment: String? = nil

    @State private var isSharing = false

    @State private var sharingItem: URL?

    var body: some View {
        VStack {
            ArticleAudioPlayer()
            ArticleWebView(url: $url)
        }
        .frame(minWidth: 400)
        .background(
            Color(NSColor.textBackgroundColor)
        )
        .onChange(of: planetStore.selectedArticle) { newArticle in
            if let myArticle = newArticle as? MyArticleModel {
                url = myArticle.publicIndexPath
                sharingItem = myArticle.browserURL?.absoluteURL
            }
            else if let followingArticle = newArticle as? FollowingArticleModel {
                if let webviewURL = followingArticle.webviewURL {
                    url = webviewURL
                }
                else {
                    debugPrint("Failed to switch selected article - branch A")
                    url = Self.noSelectionURL
                }
                sharingItem = followingArticle.browserURL?.absoluteURL
            }
            else {
                debugPrint("Failed to switch selected article - branch B")
                url = Self.noSelectionURL
            }
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
        .onChange(of: planetStore.selectedView) { _ in
            url = Self.noSelectionURL
            NotificationCenter.default.post(name: .loadArticle, object: nil)
        }
        .toolbar {
            ToolbarItemGroup {
                switch planetStore.selectedView {
                case .myPlanet(let planet):
                    Button {
                        do {
                            try WriterStore.shared.newArticle(for: planet)
                        }
                        catch {
                            PlanetStore.shared.alert(title: "Failed to launch writer")
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    if let plausibleEnabled = planet.plausibleEnabled, plausibleEnabled {
                        Button {
                            isShowingAnalyticsPopover = true
                            Task(priority: .userInitiated) {
                                await planet.updateTrafficAnalytics()
                            }
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                        }
                        .popover(isPresented: $isShowingAnalyticsPopover, arrowEdge: .bottom) {
                            PlausiblePopoverView(planet: planet)
                        }
                    }

                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                case .followingPlanet:
                    Button {
                        planetStore.isShowingPlanetInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                default:
                    Text("")
                }
            }

            ToolbarItemGroup(placement: .principal) {
                if let article = planetStore.selectedArticle,
                    article.hasAudio
                {
                    if let myArticle = article as? MyArticleModel,
                        let name = myArticle.audioFilename,
                        let url = myArticle.getAttachmentURL(name: name)
                    {
                        Button {
                            ArticleAudioPlayerViewModel.shared.url = url
                            ArticleAudioPlayerViewModel.shared.title = article.title
                        } label: {
                            Label("Play Audio", systemImage: "headphones")
                        }
                    }
                    if let followingArticle = article as? FollowingArticleModel,
                        let name = followingArticle.audioFilename,
                        let url = followingArticle.getAttachmentURL(name: name)
                    {
                        Button {
                            ArticleAudioPlayerViewModel.shared.url = url
                            ArticleAudioPlayerViewModel.shared.title = article.title
                        } label: {
                            Label("Play Audio", systemImage: "headphones")
                        }
                    }
                }

                // Menu for accessing the attachments if any
                if let article = planetStore.selectedArticle, let attachments = article.attachments,
                    attachments.count > 0
                {
                    Menu {
                        ForEach(attachments, id: \.self) { attachment in
                            Button {
                                let downloadsPath = FileManager.default.urls(
                                    for: .downloadsDirectory,
                                    in: .userDomainMask
                                ).first
                                if let myArticle = article as? MyArticleModel {
                                    if let attachmentURL = myArticle.getAttachmentURL(
                                        name: attachment
                                    ),
                                        let destinationURL = downloadsPath?.appendingPathComponent(
                                            attachment
                                        )
                                    {
                                        if !FileManager.default.fileExists(
                                            atPath: destinationURL.path
                                        ) {
                                            try? FileManager.default.copyItem(
                                                at: attachmentURL,
                                                to: destinationURL
                                            )
                                        }
                                        NSWorkspace.shared.activateFileViewerSelecting([
                                            destinationURL
                                        ])
                                    }
                                }
                                if let followingArticle = article as? FollowingArticleModel {
                                    if let attachmentURL = followingArticle.getAttachmentURL(
                                        name: attachment
                                    ) {
                                        // MARK: TODO: should hide download button if any
                                        if PlanetDownloadItem.downloadableFileExtensions().contains(
                                            attachmentURL.pathExtension
                                        ) {
                                            NotificationCenter.default.post(
                                                name: .downloadArticleAttachment,
                                                object: attachmentURL
                                            )
                                        }
                                    }
                                }
                            } label: {
                                Text(attachment)
                            }
                        }
                    } label: {
                        Image(systemName: "paperclip")
                        Text("\(attachments.count)")
                    }
                }
            }

            ToolbarItemGroup(placement: .automatic) {
                Spacer()
                if let article = planetStore.selectedArticle {
                    Button {
                        isSharing = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .background(
                        SharingServicePicker(isPresented: $isSharing, sharingItems: [sharingItem ?? URL(string: "https://planetable.eth.limo")!])
                    )
                }
            }
        }
    }
}
