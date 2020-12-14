import App
import Vapor

@discardableResult
func shell(currentDirectoryURL: URL, executableURL: URL, args: String...) -> Int32 {
    let task = Process()
    task.currentDirectoryURL = currentDirectoryURL
    task.executableURL = executableURL
    task.arguments = args
    task.launch()
    task.waitUntilExit()
    return task.terminationStatus
}

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer { app.shutdown() }
try configure(app)
try app.run()

let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
shell(currentDirectoryURL: directoryURL, executableURL: URL(fileURLWithPath: "~/.nvm/versions/node/v15.4.0/bin/npm"), args: "install")
shell(currentDirectoryURL: directoryURL, executableURL: URL(fileURLWithPath: "~/.nvm/versions/node/v15.4.0/bin/npm"), args: "run", "build")
