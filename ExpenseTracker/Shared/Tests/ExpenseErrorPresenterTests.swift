import Testing
import Foundation

/// Drives the error-surfacing seam: a presentable error mapped from any thrown
/// error, plus an observable presenter that runs a throwing operation and routes
/// failures into user-visible state instead of swallowing them.
@MainActor
struct ExpenseErrorPresenterTests {

    @Test("A successful operation returns its value and records no error")
    func successReturnsValue() {
        let presenter = ExpenseErrorPresenter()
        let result = presenter.perform("Saving") { 42 }
        #expect(result == 42)
        #expect(presenter.currentError == nil)
    }

    @Test("A throwing operation returns nil and records a presentable error")
    func failureRecordsError() {
        let presenter = ExpenseErrorPresenter()
        let result: Int? = presenter.perform("Saving") {
            throw ExpenseDomain.RepositoryError.transactionNotFound
        }
        #expect(result == nil)
        #expect(presenter.currentError?.title == "Saving")
        #expect(presenter.currentError?.message == "That transaction no longer exists.")
    }

    @Test("Dismiss clears the current error")
    func dismissClears() {
        let presenter = ExpenseErrorPresenter()
        _ = presenter.perform("X") { throw ExpenseDomain.RepositoryError.transactionNotFound }
        presenter.dismiss()
        #expect(presenter.currentError == nil)
    }

    @Test("Validation errors map to friendly messages")
    func validationMessages() {
        #expect(
            ExpensePresentableError(ExpenseDomain.ValidationError.incomeHasCategory, title: "T").message
                == "Income transactions can’t have a category."
        )
        #expect(
            ExpensePresentableError(ExpenseDomain.ValidationError.subcategoryWithoutCategory, title: "T").message
                == "Choose a category before selecting a subcategory."
        )
        #expect(
            ExpensePresentableError(ExpenseDomain.ValidationError.subcategoryParentMismatch, title: "T").message
                == "That subcategory doesn’t belong to the chosen category."
        )
    }

    @Test("Unknown errors fall back to a generic, non-empty message")
    func genericMessage() {
        struct Boom: Error {}
        let error = ExpensePresentableError(Boom(), title: "Loading")
        #expect(error.title == "Loading")
        #expect(!error.message.isEmpty)
    }
}
