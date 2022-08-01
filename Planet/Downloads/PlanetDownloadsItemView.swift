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
    @State private var downloadStatus: PlanetDownloadItemStatus = .idle

    var body: some View {
        HStack {
            if downloadStatus != .downloading {
                VStack {
                    HStack {
                        Text(item.downloadItemName())
                        Spacer()
                    }
                    HStack {
                        Text(item.created.description)
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
                    } else if downloadStatus == .idle {
                        //
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
                .disabled(downloadStatus == .idle)
            } else {
                ProgressView(item.download.progress)
                    .progressViewStyle(.linear)
                Spacer()
                Button {
                    item.download.progress.pause()
                } label: {
                    Image(systemName: "pause.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 12, height: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 72)
        .onReceive(downloadsViewModel.timer) { _ in
            if item.download.progress.isFinished {
                downloadStatus = .finished
            } else if item.download.progress.isPaused {
                downloadStatus = .paused
            } else if item.download.progress.isCancelled {
                downloadStatus = .cancelled
            } else {
                downloadStatus = .downloading
            }
        }
    }

    private func revealDownloadInFinder() {
        if let targetPath = item.download.progress.fileURL {
            NSWorkspace.shared.open(targetPath)
        }
    }
}
