import Foundation

/// The order History is shown in: Pinned clips first, newest pin first, then the rest, most recently used first.
/// The store sorts this way in SQL. This does the same in memory, so the menu can reorder at once when a star is
/// clicked, without waiting for the database (a menu that is open doesn't run queued work).
public enum PinOrder {
    public static func sorted<T>(
        _ items: [T],
        isPinned: (T) -> Bool,
        pinnedAt: (T) -> Date?,
        lastUsedAt: (T) -> Date
    ) -> [T] {
        items.enumerated().sorted { lhs, rhs in
            let (a, b) = (lhs.element, rhs.element)
            switch (isPinned(a), isPinned(b)) {
            case (true, false): return true
            case (false, true): return false
            case (true, true):
                let (pa, pb) = (pinnedAt(a) ?? .distantPast, pinnedAt(b) ?? .distantPast)
                if pa != pb { return pa > pb }
            case (false, false):
                let (ua, ub) = (lastUsedAt(a), lastUsedAt(b))
                if ua != ub { return ua > ub }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
