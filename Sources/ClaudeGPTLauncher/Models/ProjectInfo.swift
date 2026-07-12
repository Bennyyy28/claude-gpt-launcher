import Foundation

struct ProjectInfo: Equatable {
    let rootURL: URL
    let branch: String
    let changedFileCount: Int

    var name: String { rootURL.lastPathComponent }
    var hasChanges: Bool { changedFileCount > 0 }
}
