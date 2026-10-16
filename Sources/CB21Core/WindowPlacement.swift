import CoreGraphics

/// Works out where a window should open: a comfortable size for the screen, exactly in the middle of it.
public enum WindowPlacement {
    /// - Parameters:
    ///   - visible: the screen's usable area (without the menu bar and the Dock).
    ///   - widthFraction, heightFraction: how much of the usable area the window takes.
    ///   - minimum, maximum: limits on the size. The window never grows past the usable area.
    public static func centeredFrame(
        in visible: CGRect,
        widthFraction: CGFloat,
        heightFraction: CGFloat,
        minimum: CGSize,
        maximum: CGSize
    ) -> CGRect {
        let width = clamp((visible.width * widthFraction).rounded(), minimum.width, maximum.width, limit: visible.width)
        let height = clamp((visible.height * heightFraction).rounded(), minimum.height, maximum.height, limit: visible.height)
        return CGRect(x: (visible.midX - width / 2).rounded(), y: (visible.midY - height / 2).rounded(), width: width, height: height)
    }

    private static func clamp(_ value: CGFloat, _ minimum: CGFloat, _ maximum: CGFloat, limit: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum, limit)
    }

    /// Centers a window that already has a size, for example after a toolbar has changed its height.
    /// A window taller or wider than the usable area is shrunk to fit it.
    public static func centered(size: CGSize, in visible: CGRect) -> CGRect {
        let width = min(size.width, visible.width)
        let height = min(size.height, visible.height)
        return CGRect(x: (visible.midX - width / 2).rounded(), y: (visible.midY - height / 2).rounded(), width: width, height: height)
    }
}
