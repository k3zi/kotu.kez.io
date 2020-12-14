import App
import Vapor

@discardableResult
func shell(currentDirectoryURL: URL, args: String...) -> Int32 {
    let task = Process()
    task.currentDirectoryURL = currentDirectoryURL
    task.executableURL = URL(fileURLWithPath: "/usr/bin/env")

    var env = task.environment ?? [:]
    let homeDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
    let npmURL = homeDirectoryURL.appendingPathComponent(".nvm/versions/node/v15.4.0/bin")
    env["PATH"] = "/usr/local/bin:\(npmURL.path)"
    task.environment = env

    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)

let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
shell(currentDirectoryURL: directoryURL, args: "npm", "install")
shell(currentDirectoryURL: directoryURL, args: "npm", "run", "build")

defer { app.shutdown() }
try configure(app)
try app.run()
