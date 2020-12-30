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

//let contentsDirectory = directoryURL.appendingPathComponent("Resources/Dictionaries/SMK8/contents")
//let fileContainer = try CompressedFileContainer(withDirectory: contentsDirectory)
//let exportedFolder = contentsDirectory.appendingPathComponent("exported", isDirectory: true)
//try FileManager.default.createDirectory(at: exportedFolder, withIntermediateDirectories: true)
//for (i, collection) in fileContainer.collections.enumerated() {
//    for (j, file) in collection.files.enumerated() {
//        let outputFileURL = exportedFolder.appendingPathComponent("\(String(format: "%05x", i))_\(String(format: "%05x", j)).html")
//        try file.text.data(using: .utf8)!.write(to: outputFileURL)
//    }
//}


let directoryURL = URL(fileURLWithPath: app.directory.workingDirectory)
shell(currentDirectoryURL: directoryURL, args: "npm", "install", "--force")
shell(currentDirectoryURL: directoryURL, args: "webpack")

defer { app.shutdown() }
try configure(app)
try app.run()
