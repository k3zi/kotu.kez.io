import Foundation

extension TimeInterval {
    func toString() -> String {
        let allSeconds = Int(self)
        let milliseconds = Int((self * 1000)) % 1000
        let seconds = allSeconds % 60
        let minutes = (allSeconds / 60) % 60
        let hours = (allSeconds / 3600)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    }
}
