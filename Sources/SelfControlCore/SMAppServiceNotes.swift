import Foundation

public enum SMAppServiceNotes {
    public static let daemonPlistName = "com.skynet.selfcontrold.plist"
    public static let daemonPlistBundlePath = "Contents/Library/LaunchDaemons/\(daemonPlistName)"
    public static let helperInstallNote = "Bundle the launchd plist at \(daemonPlistBundlePath) for SMAppService registration."
}
