// Thanks to 1conan's TSSSaver

import Foundation

@_silgen_name("MGCopyAnswer")
func MGCopyAnswer(_: CFString) -> Optional<Unmanaged<CFPropertyList>>

func request(body: [String : String], _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
    var request = URLRequest(url: URL(string: "https://tsssaver.1conan.com/v2/api/save.php")!)
    request.httpMethod = "POST"

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
    } catch let error {
        fatalError(error.localizedDescription)
    }

    request.addValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.addValue("*/*", forHTTPHeaderField: "Accept")

    URLSession.shared.dataTask(with: request) { data, _, _ -> Void in
        if let data = data {
            return completion(true, data)
        }
        return completion(false, nil)
    }.resume()
}

guard let ecid = MGCopyAnswer("UniqueChipID" as CFString),
let device = MGCopyAnswer("ProductType" as CFString),
let board = MGCopyAnswer("HWModelStr" as CFString) else {
    fatalError("Can't read device values")
}

let ecidInt = ecid.takeRetainedValue() as! Int // Decimal ECID
let deviceString = device.takeRetainedValue() as! String // iPad8,11
let boardString = board.takeRetainedValue() as! String // J27AP

let pipe = Pipe()
let task = NSTask()
task.setLaunchPath("/usr/bin/dimentio")
task.setStandardOutput(pipe)
task.launch()

let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
let output = String(decoding: outputData, as: UTF8.self)
let outputSplit = output.split(whereSeparator: \.isNewline)

let outputSlice = outputSplit.suffix(2)
let neededOutput = Array(outputSlice)

var nonce_d = ""
var generator = ""

for n in 0...1 {
    if let range = neededOutput[n].range(of: "nonce_d:") {
        nonce_d = neededOutput[n][range.upperBound...].trimmingCharacters(in: .whitespaces)
    } else if let range = neededOutput[n].range(of: "Current nonce is") {
        generator = neededOutput[n][range.upperBound...].trimmingCharacters(in: .whitespaces)
    }
}

var parameters = ["ecid": "\(ecidInt)",
                  "deviceIdentifier": deviceString,
                  "boardConfig": boardString,
                  "captchaResponse": ""]

if nonce_d != "" {
    parameters["apnonce"] = nonce_d
    parameters["generator"] = generator
}

request(body: parameters) { success, data in
    guard success else {
        fatalError("Request to TSSSaver was unsuccessful")
    }
    do {
        if let json = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any] {
            guard let link = json["url"] as? String else {
                fatalError("TSSSaver didn't return as expected \(json)")
            }
            print("Link to blobs: \(link)")
            exit(0)
        }
    } catch {
        fatalError("Parser error")
    }
}

dispatchMain()
