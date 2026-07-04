import Foundation

final class Deduplicator {
    private let repository: ItemRepository

    init(_ repository: ItemRepository) {
        self.repository = repository
    }

    func isDuplicate(_ hash: String) -> Bool {
        repository.exists(hash: hash)
    }

    func process(_ item: ClipItem) -> ClipItem? {
        if isDuplicate(item.contentHash) {
            return nil
        }
        return item
    }
}
