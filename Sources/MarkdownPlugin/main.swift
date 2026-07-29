import Foundation
import TCPluginSDK

/// The viewer plugin: says how much it wants a file, and converts the ones
/// it takes. It never draws — Lister renders what comes back, which is what
/// gives the plugin find, print, copy and the window's appearance for free.
struct Runner {
    private let input = FileHandle.standardInput
    private let output = FileHandle.standardOutput
    private var buffer = Data()

    /// Markdown by extension; otherwise a fallback for a file that opens
    /// like one, so a README with no extension still renders.
    func priority(path: String, prefix: Data) -> ViewerPriority {
        let ext = (path as NSString).pathExtension.lowercased()
        if ["md", "markdown", "mdown"].contains(ext) { return .preferred }
        let head = String(data: prefix.prefix(512), encoding: .utf8) ?? ""
        return head.hasPrefix("# ") ? .fallback : .decline
    }

    mutating func run() {
        while let frame = nextFrame() {
            guard let request = try? JSONDecoder().decode(PluginWire.Request.self, from: frame)
            else { continue }
            handle(request)
        }
    }

    private mutating func nextFrame() -> Data? {
        guard let header = read(4), let length = try? PluginWire.frameLength(header) else {
            return nil
        }
        return read(length)
    }

    private mutating func read(_ count: Int) -> Data? {
        while buffer.count < count {
            let chunk = input.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
        defer { buffer.removeFirst(count) }
        return Data(buffer.prefix(count))
    }

    private func handle(_ request: PluginWire.Request) {
        do {
            switch request.method {
            case PluginWire.Method.hello:
                try reply(request.id, PluginWire.Hello(
                    id: "com.tc4mac.sample.markdown",
                    displayName: "Markdown viewer (sample)"))

            case PluginWire.Method.viewerPriority:
                let file: PluginPayload.ViewFile = try decode(request)
                try reply(request.id, PluginPayload.ViewPriority(
                    priority: priority(path: file.path, prefix: file.prefix).rawValue))

            case PluginWire.Method.viewerRender:
                let file: PluginPayload.ViewFile = try decode(request)
                guard let text = try? String(contentsOfFile: file.path, encoding: .utf8) else {
                    throw PluginError.notFound(file.path)
                }
                // Quick View moves with the cursor, so it gets the cheaper
                // rendering; a full Lister window gets the converted page.
                let quickView = ViewerOptions(rawValue: file.options).contains(.quickView)
                try reply(request.id, quickView
                    ? PluginPayload.ViewContent(kind: "text", text: text)
                    : PluginPayload.ViewContent(
                        kind: "html", text: MarkdownRenderer.html(from: text)))

            default:
                try fail(request.id, .notSupported(request.method))
            }
        } catch let error as PluginError {
            try? fail(request.id, error)
        } catch {
            try? fail(request.id, .failed("\(error)"))
        }
    }

    private func decode<T: Decodable>(_ request: PluginWire.Request) throws -> T {
        try JSONDecoder().decode(T.self, from: request.payload)
    }

    private func reply<T: Encodable>(_ id: Int, _ value: T) throws {
        try send(PluginWire.Response(id: id, payload: try JSONEncoder().encode(value)))
    }

    private func fail(_ id: Int, _ error: PluginError) throws {
        try send(PluginWire.Response(id: id, error: PluginWire.ErrorPayload(error)))
    }

    private func send(_ response: PluginWire.Response) throws {
        try output.write(contentsOf: PluginWire.frame(try JSONEncoder().encode(response)))
    }
}

var runner = Runner()
runner.run()
