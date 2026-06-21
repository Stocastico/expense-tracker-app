import Foundation
import Observation

/// A user-facing description of a failed operation, derived from any thrown
/// error. Keeps presentation strings out of the domain and the persistence
/// adapter, which throw typed/opaque errors.
public struct ExpensePresentableError: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String

    public init(id: UUID = UUID(), title: String, message: String) {
        self.id = id
        self.title = title
        self.message = message
    }

    /// Wraps an arbitrary error, mapping the ones we recognise to friendly
    /// copy and everything else to a generic fallback.
    public init(_ error: Error, title: String) {
        self.init(id: UUID(), title: title, message: Self.message(for: error))
    }

    private static func message(for error: Error) -> String {
        if let repository = error as? ExpenseDomain.RepositoryError {
            switch repository {
            case .transactionNotFound:
                return "That transaction no longer exists."
            }
        }
        if let validation = error as? ExpenseDomain.ValidationError {
            switch validation {
            case .incomeHasCategory:
                return "Income transactions can’t have a category."
            case .subcategoryWithoutCategory:
                return "Choose a category before selecting a subcategory."
            case .subcategoryParentMismatch:
                return "That subcategory doesn’t belong to the chosen category."
            }
        }
        return "Something went wrong. Please try again."
    }
}

/// Observable surface that runs throwing operations and routes any failure into
/// `currentError` for the UI to present, instead of swallowing it. Bind a
/// SwiftUI alert to `currentError`.
@MainActor
@Observable
public final class ExpenseErrorPresenter {
    public var currentError: ExpensePresentableError?

    public init() {}

    /// Runs `operation`, returning its value on success. On failure, records a
    /// presentable error (titled `title`) and returns `nil`.
    @discardableResult
    public func perform<T>(_ title: String, _ operation: () throws -> T) -> T? {
        do {
            return try operation()
        } catch {
            currentError = ExpensePresentableError(error, title: title)
            return nil
        }
    }

    /// Clears the current error (e.g. when the user dismisses the alert).
    public func dismiss() {
        currentError = nil
    }
}
