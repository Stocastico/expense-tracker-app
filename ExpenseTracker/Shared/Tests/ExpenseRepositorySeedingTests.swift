import Testing
import Foundation

/// Tests for the first-launch seeding helper used to populate the expense
/// catalog when the store is empty. Driven through the in-memory fake.
struct ExpenseRepositorySeedingTests {

    @Test("Seeding an empty repository installs the default catalog and tags")
    func seedsDefaultsWhenEmpty() throws {
        let repo = ExpenseDomain.InMemoryRepository()

        let didSeed = try repo.seedDefaultsIfEmpty()

        #expect(didSeed)
        #expect(try repo.catalog().categories.count == 9)
        #expect(try repo.catalog().isValid)
        #expect(try repo.tags().isEmpty == false)
    }

    @Test("Seeding is idempotent and preserves existing ids")
    func seedingIsIdempotent() throws {
        let repo = ExpenseDomain.InMemoryRepository()
        #expect(try repo.seedDefaultsIfEmpty())
        let firstIds = try repo.catalog().categories.map(\.id)

        let didSeedAgain = try repo.seedDefaultsIfEmpty()

        #expect(didSeedAgain == false)
        #expect(try repo.catalog().categories.map(\.id) == firstIds)
        #expect(try repo.catalog().categories.count == 9)
    }
}
