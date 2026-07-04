import Foundation

final class SearchService {
    private let repository: ItemRepository

    init(_ repository: ItemRepository) {
        self.repository = repository
    }

    func search(keyword: String, category: Category? = nil, groupId: Int64? = nil) -> [ClipItem] {
        guard !keyword.trimmingCharacters(in: .whitespaces).isEmpty else {
            return repository.fetchAll(category: category, groupId: groupId)
        }
        return repository.search(keyword: keyword, category: category, groupId: groupId)
    }
}
