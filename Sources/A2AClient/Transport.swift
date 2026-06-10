import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Errors raised by the client transport layer.
public enum A2ATransportError: Error, Sendable {
    /// The server returned a non-2xx HTTP status. Carries the status code and response body.
    case httpError(statusCode: Int, body: Data)
    /// The response was not an HTTP response.
    case invalidResponse
}

/// Abstracts the HTTP layer used by `A2AClient`, allowing custom transports
/// (alternate networking stacks, test mocks, tunneled connections).
public protocol A2ATransport: Sendable {
    /// Executes a request and returns the response body and HTTP status code.
    func post(_ request: URLRequest) async throws -> (Data, Int)

    /// Executes a request and streams the response body as it arrives.
    ///
    /// The stream throws `A2ATransportError.httpError` if the server responds
    /// with a non-2xx status.
    func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error>
}

/// Mutates outgoing requests to attach credentials (API keys, bearer tokens,
/// signed headers). Keeps authentication concerns out of the core client.
public protocol RequestAuthenticator: Sendable {
    func authenticate(_ request: inout URLRequest) async throws
}

/// The default `A2ATransport`, backed by `URLSession`.
///
/// Streaming uses a `URLSessionDataDelegate` feeding an `AsyncThrowingStream`
/// rather than `URLSession.bytes(for:)`, which is unavailable or unreliable on
/// swift-corelibs-foundation (Linux).
public struct URLSessionTransport: A2ATransport {
    private let configuration: URLSessionConfiguration

    public init(configuration: URLSessionConfiguration = .default) {
        self.configuration = configuration
    }

    public func post(_ request: URLRequest) async throws -> (Data, Int) {
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let http = response as? HTTPURLResponse else {
                    continuation.resume(throwing: A2ATransportError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data ?? Data(), http.statusCode))
            }
            task.resume()
        }
    }

    public func stream(_ request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        AsyncThrowingStream { continuation in
            let delegate = StreamingDelegate(continuation: continuation)
            let session = URLSession(
                configuration: configuration, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            continuation.onTermination = { _ in
                task.cancel()
                session.invalidateAndCancel()
            }
            task.resume()
        }
    }
}

/// Feeds response body chunks into an `AsyncThrowingStream` continuation.
///
/// URLSession serializes delegate callbacks onto its delegate queue, so the
/// mutable state is never accessed concurrently.
private final class StreamingDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private var statusCode: Int = 0
    private var errorBody = Data()

    init(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
        self.continuation = continuation
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if (200..<300).contains(statusCode) {
            continuation.yield(data)
        } else {
            errorBody.append(data)
        }
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?
    ) {
        if let error {
            continuation.finish(throwing: error)
        } else if !(200..<300).contains(statusCode) {
            continuation.finish(
                throwing: A2ATransportError.httpError(statusCode: statusCode, body: errorBody))
        } else {
            continuation.finish()
        }
        session.finishTasksAndInvalidate()
    }
}
