/// ⌘1 to ⌘9 pick one of the first nine rows of the menu or the History window.
public enum QuickSelect {
    public static let maxRows = 9

    /// The digit shown for a row, or nil past the ninth row.
    public static func key(forRow index: Int) -> String? {
        (0..<maxRows).contains(index) ? String(index + 1) : nil
    }

    /// The row a digit picks, or nil if it isn't 1 to 9.
    public static func row(forKey key: String) -> Int? {
        guard let digit = Int(key), (1...maxRows).contains(digit), key.count == 1 else { return nil }
        return digit - 1
    }
}

/// What the menu lists: every Pinned clip, then the most recent of the others.
public enum MenuList {
    public static func split<T>(_ items: [T], isPinned: (T) -> Bool, recentLimit: Int) -> (pinned: [T], recent: [T]) {
        let pinned = items.filter(isPinned)
        let recent = items.filter { !isPinned($0) }.prefix(recentLimit)
        return (pinned, Array(recent))
    }
}
