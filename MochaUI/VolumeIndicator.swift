import Cocoa

/* TODO: Convert to CALayer drawing instead. */

// adapted from @mattprowse: https://github.com/mattprowse/SystemBezelWindowController
public class VolumeIndicator: NSView {
    
    private enum ColorKeys {
        case background, segment
    }
    
    //
    //
    //

    private let drawColors: [SystemBezel.ColorMode: [ColorKeys: NSColor]] = [
        .light: [.background: NSColor(deviceWhite: 0, alpha: 0.6), .segment: .controlBackgroundColor],
        .lightReducedTransparency: [.background: NSColor(deviceWhite: 0.50, alpha: 1.0), .segment: .white],
        .lightIncreasedContrast: [.background: NSColor(deviceWhite: 0.01, alpha: 1.0), .segment: .white],
        .dark: [.background: NSColor(deviceWhite: 0, alpha: 0.6), .segment: NSColor(deviceWhite: 1, alpha: 0.8)],
        .darkReducedTransparency: [.background: NSColor(deviceWhite: 0.01, alpha: 1.0), .segment: NSColor(deviceWhite: 0.49, alpha: 1.0)],
        .darkIncreasedContrast: [.background: NSColor(deviceWhite: 0.01, alpha: 1.0), .segment: NSColor(deviceWhite: 0.76, alpha: 1.0)],
    ]
    
    private let maxLevel: Int = 16
    private let segmentSize = NSSize(width: 9, height: 6)
    private let segmentSpacing: CGFloat = 1
    
    private var barColor: NSColor {
        return self.drawColors[self.colorMode]![.background]!
    }

    private var segmentColor: NSColor {
        return self.drawColors[self.colorMode]![.segment]!
    }
    
    public var level: Int = 0 {
        willSet {
            self.level = self.level.clamped(to: 0...maxLevel)
        }
        didSet {
            self.needsDisplay = true
        }
    }
    
    // Note that the color is inverted from the root appearance to stand out.
    private var colorMode: SystemBezel.ColorMode {
        let a = self.appearance?.name ?? NSAppearance.Name.vibrantLight
        if NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast {
            return a == NSAppearance.Name.vibrantDark ? .lightIncreasedContrast : .darkIncreasedContrast
        }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
            return a == NSAppearance.Name.vibrantDark ? .lightReducedTransparency : .darkReducedTransparency
        }
        return a == NSAppearance.Name.vibrantDark ? .light : .dark
    }
    
    //
    //
    //
    
    public override var allowsVibrancy: Bool {
        return false
    }
    public override var intrinsicContentSize: NSSize {
        return NSSize(width: NSView.noIntrinsicMetric, height: 8.0)
    }
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        self.barColor.set()
        dirtyRect.fill()

        var segmentIndex = 0
        var segmentXOffset: CGFloat = self.segmentSpacing

        self.segmentColor.set()
        while segmentIndex < self.level {
            let segmentRect = NSRect(x: segmentXOffset, y: 1, width: self.segmentSize.width, height: self.segmentSize.height)
            segmentRect.fill()
            segmentIndex += 1
            segmentXOffset += self.segmentSize.width + self.segmentSpacing
        }
    }
}
