import Foundation
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
