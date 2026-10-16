import Foundation

/// The order History is shown in: Pinned clips first, then the rest, and inside each group the most recently used
/// first. So the clip you used last is always at the top of its group, whether or not it is pinned, and pinning an
/// older clip puts it below the more recently used pinned ones instead of above them.
///
/// The store sorts this way in SQL. This does the same in memory, so the menu can reorder at once when a star is
/// clicked, without waiting for the database (a menu that is open doesn't run queued work).
public enum PinOrder {
    public static func sorted<T>(
        _ items: [T],
        isPinned: (T) -> Bool,
        lastUsedAt: (T) -> Date
    ) -> [T] {
        items.enumerated().sorted { lhs, rhs in
            let (a, b) = (lhs.element, rhs.element)
            switch (isPinned(a), isPinned(b)) {
            case (true, false): return true
            case (false, true): return false
            default:
                let (ua, ub) = (lastUsedAt(a), lastUsedAt(b))
                if ua != ub { return ua > ub }
                return lhs.offset < rhs.offset
            }
        }.map(\.element)
    }
}
