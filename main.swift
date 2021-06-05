// Thanks to 1conan's TSSSaver and 0x7ff's libdimentio

import Foundation

@_silgen_name("MGCopyAnswer")
func MGCopyAnswer(_: CFString) -> Optional<Unmanaged<CFPropertyList>>

var nonce_d = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CC_SHA384_DIGEST_LENGTH))
var ret: CInt = EXIT_FAILURE
var nonce_d_sz: size_t = 0
var generator: UInt64 = 0
var generatorStr : String = ""
var nonceStr : String = ""

func request(body: [String : String], _ completion: @escaping ((_ success: Bool, _ data: Data?) -> Void)) {
    var request = URLRequest(url: URL(string: "https://tsssaver.1conan.com/v2/api/save.php")!)
    request.httpMethod = "POST"

    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
    } catch let error {
        print(error.localizedDescription)
        exit(1)
    }

    request.addValue("text/plain;charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.addValue("*/*", forHTTPHeaderField: "Accept")
    
    let config = URLSessionConfiguration.default
    config.waitsForConnectivity = true

    URLSession(configuration: config).dataTask(with: request) { data, _, _ -> Void in
        if let data = data {
            return completion(true, data)
        }
        return completion(false, nil)
    }.resume()
}

if (dimentio_preinit(&generator, false, nonce_d, &nonce_d_sz) == KERN_SUCCESS || (dimentio_init(0, nil, nil) == KERN_SUCCESS && dimentio(&generator, false, nonce_d, &nonce_d_sz) == KERN_SUCCESS)) {
    generatorStr = "0x" + String(generator, radix:16).uppercased()
    let buffer = UnsafeBufferPointer(start: nonce_d, count: nonce_d_sz)
    nonceStr = buffer.map { String(format: "%02X", $0) }.joined()
    print("libdimentio success\nproceeding with current generator (\(generatorStr)) and nonce (\(nonceStr))")
} else {
    print("libdimentio failed, proceeding without current generator and nonce")
}
dimentio_term()
free(nonce_d)

guard let ecid = MGCopyAnswer("UniqueChipID" as CFString),
let device = MGCopyAnswer("ProductType" as CFString),
let board = MGCopyAnswer("HWModelStr" as CFString) else {
    print("Can't read device values")
    exit(1)
}

let ecidInt = ecid.takeRetainedValue() as! Int // Decimal ECID
let deviceString = device.takeRetainedValue() as! String // iPad8,11
let boardString = board.takeRetainedValue() as! String // J27AP

var parameters = ["ecid": "\(ecidInt)",
                  "deviceIdentifier": deviceString,
                  "boardConfig": boardString,
                  "captchaResponse": ""]

if !nonceStr.isEmpty && !generatorStr.isEmpty {
    parameters["apnonce"] = nonceStr
    parameters["generator"] = generatorStr
}

request(body: parameters) { success, data in
    guard success,
      let data = data else {
        print("Request to TSSSaver was unsuccessful")
        exit(1)
    }
    do {
        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            guard let link = json["url"] as? String else {
                print("TSSSaver didn't return as expected \(json)")
                exit(1)
            }
            print("Link to blobs: \(link)")
            exit(0)
        }
    } catch {
        print("Parser error")
        exit(1)
    }
}

dispatchMain()
