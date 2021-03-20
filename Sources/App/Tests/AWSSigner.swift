import Vapor

struct AWSSigner {
    let awsRegion: String
    let serviceType: String
    private let hmacShaTypeString = "AWS4-HMAC-SHA256"
    private let aws4Request = "aws4_request"

    private let iso8601Formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmssXXXXX"
        return formatter
    }()

    private func iso8601() -> (full: String, short: String) {
        let date = iso8601Formatter.string(from: Date())
        let index = date.index(date.startIndex, offsetBy: 8)
        let shortDate = String(date[..<index])
        return (full: date, short: shortDate)
    }

    func sign(request: inout ClientRequest, secretSigningKey: String, accessKeyId: String) {
        let date = iso8601()
        let url = request.url

        guard let bodyBuffer = request.body, let host = url.host else { return }
        let body = Data(buffer: bodyBuffer)

        request.headers.add(name: .host, value: host)
        request.headers.add(name: "X-Amz-Date", value: date.full)
        let method = request.method

        let signedHeaders = request.headers.map { $0.name.lowercased() }.sorted().joined(separator: ";")

        let canonicalRequestHash = [
            method.rawValue,
            url.path,
            url.query ?? "",
            request.headers.map { $0.name.lowercased() + ":" + $0.value }.sorted().joined(separator: "\n"),
            "",
            signedHeaders,
            body.sha256()
        ].joined(separator: "\n").sha256()

        let credential = [date.short, awsRegion, serviceType, aws4Request].joined(separator: "/")

        let stringToSign = [
            hmacShaTypeString,
            date.full,
            credential,
            canonicalRequestHash
        ].joined(separator: "\n")

        let signature = hmacStringToSign(stringToSign: stringToSign, secretSigningKey: secretSigningKey, shortDateString: date.short)

        let authorization = hmacShaTypeString + " Credential=" + accessKeyId + "/" + credential + ", SignedHeaders=" + signedHeaders + ", Signature=" + signature
        request.headers.add(name: .authorization, value: authorization)
    }

    private func hmacStringToSign(stringToSign: String, secretSigningKey: String, shortDateString: String) -> String {
        let k1 = "AWS4" + secretSigningKey
        let sk1 = HMAC<SHA256>.authenticationCode(for: [UInt8](shortDateString.utf8), using: .init(data: [UInt8](k1.utf8)))
        let sk2 = HMAC<SHA256>.authenticationCode(for: [UInt8](awsRegion.utf8), using: .init(data: sk1))
        let sk3 = HMAC<SHA256>.authenticationCode(for: [UInt8](serviceType.utf8), using: .init(data: sk2))
        let sk4 = HMAC<SHA256>.authenticationCode(for: [UInt8](aws4Request.utf8), using: .init(data: sk3))
        let signature = HMAC<SHA256>.authenticationCode(for: [UInt8](stringToSign.utf8), using: .init(data: sk4))
        return signature.hex
    }
}
