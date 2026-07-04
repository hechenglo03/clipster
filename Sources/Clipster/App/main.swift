import AppKit

let args = CommandLine.arguments
if args.contains("--native-messaging-host") {
    NativeMessagingHost.run()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
