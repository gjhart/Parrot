import Foundation
import AppKit
import Mocha
import MochaUI

public enum InterfaceStyle: Int {
    /// Vibrant Light theme.
    case Light
    /// Vibrant Dark theme.
    case Dark
    /// System-defined vibrant theme.
    case System
    
    /// Returns the currently indicated Parrot appearance based on user preference
    /// and if applicable, the global dark interface style preference (trampolined).
    public func appearance() -> NSAppearance {
        let style = InterfaceStyle(rawValue: Settings.interfaceStyle) ?? .Dark
        
        switch style {
        case .Light: return .light
        case .Dark: return .dark
            
        case .System: //TODO: "NSAppearanceNameMediumLight"
            let system = Settings.systemInterfaceStyle
            return system ? .dark : .light
        }
    }
}

public enum VibrancyStyle: Int {
    /// Windows will always be vibrant.
    case Always
    /// Windows will never be vibrant (opaque).
    case Never
    /// Windows will be vibrant when focused.
    case Automatic
    
    public func visualEffectState() -> NSVisualEffectView.State {
        switch self {
        case .Always: return .active
        case .Never: return .inactive
        case .Automatic: return .followsWindowActiveState
        }
    }
}

public enum WindowInteraction: Int {
    /// App windows can be tabbed.
    case Tabbed
    /// App windows can be docked.
    case Docking
}

public enum InterfaceMode: Int {
    ///
    case MasterDetail
    ///
    case InlineExpansion
    /// Sidebar for all conversations, content has a single conversation.
    case SplitView
    ///
    case PopoverDetail
    ///
    case OverlayBubble
}//document, utility, shoebox

//
//
//

public struct Preferences {
    private init() {}
    public struct Controllers {
        private init() {}
    }
}

//
//
//

public extension UserDefaults {
    
    public var systemInterfaceStyle: Bool {
        get { return self.get(default: false) }
        set { self.set(value: newValue) }
    }
    
    public var interfaceStyle: Int {
        get { return self.get(default: 0) }
        set { self.set(value: newValue) }
    }
    
    public var vibrancyStyle: Int {
        get { return self.get(default: 0) }
        set { self.set(value: newValue) }
    }
    
    public var autoEmoji: Bool {
        get { return self.get(default: false) }
        set { self.set(value: newValue) }
    }
    
    public var messageTextSize: Double {
        get { return self.get(default: 0.0) }
        set { self.set(value: newValue) }
    }
    
    public var completions: [String: String] {
        get { return self.get(default: [:]) }
        set { self.set(value: newValue) }
    }
    
    public var emoticons: [String: String] {
        get { return self.get(default: [:]) }
        set { self.set(value: newValue) }
    }
    
    public var menubarIcon: Bool {
        get { return self.get(default: false) }
        set { self.set(value: newValue) }
    }
    
    public var openConversations: [String] {
        get { return self.get(default: []) }
        set { self.set(value: newValue) }
    }
    
    public var conversationOutgoingColor: Data? {
        get { return self.get(default: nil) }
        set { self.set(value: newValue) }
    }
    
    public var conversationIncomingColor: Data? {
        get { return self.get(default: nil) }
        set { self.set(value: newValue) }
    }
    
    public var conversationBackground: Data? {
        get { return self.get(default: nil) }
        set { self.set(value: newValue) }
    }
}

public let Settings = UserDefaults.standard
public extension UserDefaults {
    
    func get<T>(forKey key: String = #function, default: @autoclosure () -> (T)) -> T {
        return self.object(forKey: key) as? T ?? `default`()
    }
    
    func set<T>(forKey key: String = #function, value: T) {
        self.set(value, forKey: key)
    }
}
