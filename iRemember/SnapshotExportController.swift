import AppKit
import SwiftUI

@MainActor
enum SnapshotExportController {
    static func exportIfRequested(appModel: AppModel) async {
        guard ProcessInfo.processInfo.environment["IREMEMBER_EXPORT_SNAPSHOTS"] == "1" else {
            return
        }

        let outputDirectory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["IREMEMBER_SNAPSHOT_DIR"] ?? NSTemporaryDirectory(), isDirectory: true)
        let snapshotSource = ProcessInfo.processInfo.environment["IREMEMBER_SNAPSHOT_SOURCE"] ?? "sample"

        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

            switch snapshotSource {
            case "live":
                await appModel.loadPrimaryLibrary()
            default:
                await appModel.loadSampleLibrary()
            }
            try await Task.sleep(for: .milliseconds(240))

            appModel.isSidebarVisible = true
            appModel.isInspectorVisible = true
            appModel.contentMode = .transcript
            try saveSnapshot(
                RootView(appModel: appModel)
                    .frame(width: 1320, height: 860),
                to: outputDirectory.appendingPathComponent("01-transcript.png")
            )

            appModel.contentMode = .media
            try await Task.sleep(for: .milliseconds(80))
            try saveSnapshot(
                RootView(appModel: appModel)
                    .frame(width: 1320, height: 860),
                to: outputDirectory.appendingPathComponent("02-media.png")
            )

            appModel.isInspectorVisible = false
            try saveSnapshot(
                RootView(appModel: appModel)
                    .frame(width: 1320, height: 860),
                to: outputDirectory.appendingPathComponent("03-media-no-inspector.png")
            )

            appModel.contentMode = .transcript
            try saveSnapshot(
                RootView(appModel: appModel)
                    .frame(width: 1320, height: 860),
                to: outputDirectory.appendingPathComponent("04-transcript-no-inspector.png")
            )
        } catch {
            fputs("Snapshot export failed: \(error.localizedDescription)\n", stderr)
        }

        NSApp.terminate(nil)
    }

    private static func saveSnapshot<Content: View>(_ content: Content, to url: URL) throws {
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage, let pngData = image.pngData else {
            throw SnapshotExportError.renderFailed
        }

        try pngData.write(to: url)
    }
}

private enum SnapshotExportError: Error {
    case renderFailed
}

private extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
    }
}
