import Foundation

enum BridgeEventStreamFailure: Error, Equatable {
    case unauthorized
    case bridgeUnavailable
    case invalidResponse
    case disconnected
}

struct BridgeEventEnvelope: Decodable, Hashable {
    let time: String
    let data: [String: StringOrIntValue]
}

enum StringOrIntValue: Decodable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = .null
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): return value
        case .int(let value): return String(value)
        case .double(let value): return String(value)
        case .bool(let value): return String(value)
        case .null: return nil
        }
    }
}

struct BridgeEvent: Hashable {
    let id: String?
    let name: String
    let envelope: BridgeEventEnvelope?
}

final class BridgeEventStreamClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream(
        connection: BridgeConnection,
        lastEventID: String? = nil,
        onEvent: @escaping @Sendable (BridgeEvent) async -> Void,
        onFailure: @escaping @Sendable (BridgeEventStreamFailure) async -> Void
    ) -> Task<Void, Never> {
        Task.detached(priority: .background) { [session] in
            do {
                var request = try Self.makeRequest(connection: connection, lastEventID: lastEventID)
                request.timeoutInterval = 86_400
                let (bytes, response) = try await session.bytes(for: request)

                guard let http = response as? HTTPURLResponse else {
                    await onFailure(.invalidResponse)
                    return
                }

                guard (200..<300).contains(http.statusCode) else {
                    if http.statusCode == 401 {
                        await onFailure(.unauthorized)
                    } else {
                        await onFailure(.bridgeUnavailable)
                    }
                    return
                }

                var currentID: String?
                var currentEvent = "message"
                var dataBuffer: [String] = []
                var sawAnyEvent = false

                for try await line in bytes.lines {
                    if Task.isCancelled { return }

                    if line.isEmpty {
                        if !dataBuffer.isEmpty {
                            let dataString = dataBuffer.joined(separator: "\n")
                            let envelope = try? JSONDecoder().decode(BridgeEventEnvelope.self, from: Data(dataString.utf8))
                            sawAnyEvent = true
                            await onEvent(BridgeEvent(id: currentID, name: currentEvent, envelope: envelope))
                        }
                        currentID = nil
                        currentEvent = "message"
                        dataBuffer.removeAll(keepingCapacity: true)
                        continue
                    }

                    if line.hasPrefix(":") {
                        continue
                    }

                    if line.hasPrefix("id:") {
                        currentID = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                        continue
                    }

                    if line.hasPrefix("event:") {
                        currentEvent = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                        continue
                    }

                    if line.hasPrefix("data:") {
                        dataBuffer.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
                    }
                }

                if !Task.isCancelled {
                    await onFailure(sawAnyEvent ? .disconnected : .bridgeUnavailable)
                }
            } catch {
                guard !Task.isCancelled else { return }
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed, .resourceUnavailable:
                        await onFailure(.bridgeUnavailable)
                    default:
                        await onFailure(.disconnected)
                    }
                    return
                }
                await onFailure(.disconnected)
            }
        }
    }

    private static func makeRequest(connection: BridgeConnection, lastEventID: String?) throws -> URLRequest {
        let sanitizedBaseURL = connection.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: sanitizedBaseURL),
              let url = URL(string: "/stream/events", relativeTo: base)?.absoluteURL else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        if let lastEventID, !lastEventID.isEmpty {
            request.addValue(lastEventID, forHTTPHeaderField: "Last-Event-ID")
        }
        return request
    }
}
