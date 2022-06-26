import Foundation

// Reference: https://github.com/gshahbazian/playgrounds/blob/main/AsyncAwait.playground/Sources/TaskQueue.swift
// Reference: https://forums.swift.org/t/enforce-serial-access-i-e-non-rentrant-calling-of-swift-actor-functions/54829

actor Runner {
    private var queue = [CheckedContinuation<Void, Error>]()

    deinit {
        for continuation in queue {
            continuation.resume(throwing: CancellationError())
        }
    }

    func enqueue<T>(operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try Task.checkCancellation()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.append(continuation)
            tryRunEnqueued()
        }

        defer {
            tryRunEnqueued()
        }
        try Task.checkCancellation()
        return try await operation()
    }

    private func tryRunEnqueued() {
        guard !queue.isEmpty else {
            return
        }

        let continuation = queue.removeFirst()
        continuation.resume()
    }
}
