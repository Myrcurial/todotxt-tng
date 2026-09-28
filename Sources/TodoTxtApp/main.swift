import AppKit
import SwiftUI

// A plain SwiftPM executable isn't a bundled app, so make sure it gets a Dock icon
// and a menu bar even when run straight from `swift run`.
NSApplication.shared.setActivationPolicy(.regular)
TodoTxtApp.main()
