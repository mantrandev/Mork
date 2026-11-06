import MorkDomain

public enum TagTarget: Equatable, Sendable {
    case head
    case branch(Branch)
    case commit(Commit)
}
