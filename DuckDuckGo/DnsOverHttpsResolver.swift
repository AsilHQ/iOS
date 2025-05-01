//
//  DnsOverHttpsResolver.swift
//  DuckDuckGo
//
//  Copyright © 2025 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//


import Foundation

class DnsOverHttpsResolver {
    
    private var dnsServer = "high.kahfguard.com"
    
    public func resolve(hostName: String, completion: @escaping ([String]?, Error?) -> Void) {
        if AppUserDefaults().safegazeModeValue == "HIGH" {
            dnsServer = "high.kahfguard.com"
        } else if AppUserDefaults().safegazeModeValue == "LOW" {
            dnsServer = "low.kahfguard.com"
        } else if AppUserDefaults().safegazeModeValue == "MEDIUM" {
            dnsServer = "medium.kahfguard.com"
        }
        let query = createDnsQuery(domain: hostName)
        
        var request = URLRequest(url: URL(string: "https://\(dnsServer)/dns-query")!)
        request.httpMethod = "POST"
        request.addValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.addValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = query
        
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Content-Type": "application/dns-message"]
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: request) { data, _, error in
            if let error = error {
                print("DoH query error: \(error)")
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                completion(nil, NSError(domain: "DoH", code: -1, userInfo: [NSLocalizedDescriptionKey: "No response data"]))
                return
            }
            
            let ips = self.parseDnsResponse(data: data)
            completion(ips, nil)
        }
        
        task.resume()
    }
    
    private func createDnsQuery(domain: String) -> Data {
        let transactionID: UInt16 = UInt16.random(in: 0...UInt16.max)
        var dnsMessage = Data()
        
        // Transaction ID
        dnsMessage.append(UInt8(transactionID >> 8))
        dnsMessage.append(UInt8(transactionID & 0xFF))
        
        // Flags
        dnsMessage.append(0x01)
        dnsMessage.append(0x00)
        
        // QDCOUNT
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        // ANCOUNT, NSCOUNT, ARCOUNT
        dnsMessage.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // QNAME
        let labels = domain.split(separator: ".")
        for label in labels {
            dnsMessage.append(UInt8(label.count))
            dnsMessage.append(contentsOf: label.utf8)
        }
        dnsMessage.append(0x00)
        
        // QTYPE (A)
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        // QCLASS (IN)
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        return dnsMessage
    }
    
    private func parseDnsResponse(data: Data) -> [String]? {
        guard data.count >= 12 else { return nil }
        let anCount = (UInt16(data[6]) << 8) | UInt16(data[7])
        guard anCount > 0 else { return nil }
        
        var ipAddresses = [String]()
        for i in stride(from: 0, to: data.count - 4, by: 1) {
            if i + 10 < data.count,
               data[i] == 0x00, data[i+1] == 0x01,
               data[i+2] == 0x00, data[i+3] == 0x01,
               data[i+9] == 0x04 {
                let ipStart = i + 10
                let ip = "\(data[ipStart]).\(data[ipStart+1]).\(data[ipStart+2]).\(data[ipStart+3])"
                ipAddresses.append(ip)
            }
        }
        
        return ipAddresses.isEmpty ? nil : ipAddresses
    }
}
