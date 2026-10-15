import Foundation

/// The one-line summary under a Clip in the History window: when, how big, and from which app.
public enum ClipSubtitle {
    public static func make(createdAt: Date, byteCount: Int, sourceAppName: String?, now: Date = Date()) -> String {
        var parts = [age(of: createdAt, now: now), size(byteCount)]
        if let sourceAppName { parts.append(sourceAppName) }
        return parts.joined(separator: " · ")
    }

    public static func age(of date: Date, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        switch seconds {
        case ..<60: return "just now"
        case ..<3600: return "\(Int(seconds / 60)) min ago"
        case ..<86_400: return "\(Int(seconds / 3600)) h ago"
        case ..<(7 * 86_400): return "\(Int(seconds / 86_400)) d ago"
        default: return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    public static func size(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

extension Clip {
    public func subtitle(now: Date = Date()) -> String {
        ClipSubtitle.make(createdAt: createdAt, byteCount: byteCount, sourceAppName: sourceAppName, now: now)
    }
}
