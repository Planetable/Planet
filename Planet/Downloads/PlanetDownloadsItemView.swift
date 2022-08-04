//
//  PlanetDownloadsItemView.swift
//  Planet
//
//  Created by Kai on 8/1/22.
//

import SwiftUI


struct PlanetDownloadsItemView: View {
    @EnvironmentObject private var downloadsViewModel: PlanetDownloadsViewModel

    var item: PlanetDownloadItem

    @State private var downloadStatus: PlanetDownloadItemStatus = .downloading
    @State private var failedToLocateFile: Bool = false

    var body: some View {
        HStack {
            if downloadStatus != .downloading {
                VStack (spacing: 8) {
                    HStack {
                        Text(item.downloadItemName())
                        Spacer()
                    }
                    HStack {
                        Text(item.created.dateDescription())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .font(.caption2)
                }
                Spacer()
                Button {
                    if downloadStatus == .cancelled {
                        item.download.progress.resume()
                    } else if downloadStatus == .paused {
                        item.download.progress.resume()
                    } else if downloadStatus == .finished {
                        revealDownloadInFinder()
                    }
                } label: {
                    if downloadStatus == .cancelled || downloadStatus == .paused {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                }
                .buttonStyle(.plain)
            } else {
                ProgressView(item.download.progress)
                    .progressViewStyle(.linear)
                Spacer(minLength: 10)
                if item.download.progress.isPausable {
                    Button {
                        item.download.progress.pause()
                    } label: {
                        Image(systemName: "pause.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else if item.download.progress.isCancellable {
                    Button {
                        item.download.progress.cancel()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 64)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .onReceive(downloadsViewModel.timer) { _ in
            guard item.download.progress.fractionCompleted < 1.0 else {
                downloadStatus = .finished
                return
            }
            if item.download.progress.isPaused {
                downloadStatus = .paused
            } else if item.download.progress.isCancelled {
                downloadStatus = .cancelled
            }
        }
        .alert(isPresented: $failedToLocateFile) {
            Alert(title: Text("Failed to locate downloaded file."), message: Text("Please try to redownload it from article."), dismissButton: .cancel(Text("Dismiss")))
        }
        .contextMenu {
            Button {
                openFromFinder()
            } label: {
                Text("Open")
            }
            
            Button {
                revealDownloadInFinder()
            } label: {
                Text("Show in Finder")
            }
            
            Button {
                copyItemURL()
            } label: {
                Text("Copy Address")
            }
            
            Button {
                Task { @MainActor in
                    PlanetDownloadsViewModel.shared.removeDownload(item)
                }
            } label: {
                Text("Remove from List")
            }
        }
    }
    
    private func itemURL() -> URL? {
        if let targetPath = item.download.progress.fileURL {
            if let userDownloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let downloadedURL = userDownloadsDir.appendingPathComponent(targetPath.lastPathComponent)
                if FileManager.default.fileExists(atPath: downloadedURL.path) {
                    return downloadedURL
                }
            }
        }
        return nil
    }

    private func revealDownloadInFinder() {
        if let targetURL = itemURL() {
            NSWorkspace.shared.activateFileViewerSelecting([targetURL])
            return
        }
        failedToLocateFile = true
    }
    
    private func openFromFinder() {
        if let targetURL = itemURL() {
            NSWorkspace.shared.open(targetURL)
            return
        }
        failedToLocateFile = true
    }
    
    private func copyItemURL() {
        if let targetURL = item.download.originalRequest?.url {
            let pboard = NSPasteboard.general
            pboard.clearContents()
            pboard.setString(targetURL.absoluteString, forType: .string)
        }
    }
}
