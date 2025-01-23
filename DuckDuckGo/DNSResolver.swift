//
//  DNSResolver.swift
//  Kahf Browser
//
//  Copyright © 2025 Kahf Browser. All rights reserved.
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

import Network
import UIKit

class DNSResolver {
    // DNS server to query
    private let dnsHost = NWEndpoint.Host("high.kahfguard.com")
    private let dnsPort: NWEndpoint.Port = 53
    
    func resolveDNS(for host: String, completion: @escaping (String?) -> Void) {
        let connection = NWConnection(host: dnsHost, port: dnsPort, using: .udp)
        
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                print("DNS connection is ready.")
                print("Host to resolve:\(host)")
                
                let queryData = self.buildDNSQuery(for: host)
                connection.send(content: queryData, completion: .contentProcessed { error in
                    if let error = error {
                        completion(nil)
                        connection.cancel()
                        return
                    }
                    
                    connection.receiveMessage { data, contentContext, isComplete, error in
                        if let error = error {
                            completion(nil)
                            connection.cancel()
                            return
                        }
                        
                        guard let data = data else {
                            completion(nil)
                            connection.cancel()
                            return
                        }
                        
                        let resolvedIP = self.parseDNSResponse(data: data)
                        if let ip = resolvedIP {
                            // We got an IPv4 or IPv6 address
                            print("Resolved IP: \(ip)")
                        } else {
                            // Return nil means blocked, or no valid answer
                            print("Domain blocked or no valid IP found.")
                        }
                        completion(resolvedIP)
                        connection.cancel()
                    }
                })
            } else if case .failed(let error) = state {
                print("DNS connection failed: \(error)")
                completion(nil)
                connection.cancel()
            }
        }
        
        connection.start(queue: .global())
    }
    
    func buildDNSQuery(for host: String) -> Data {
        var query = Data()
        
        query.append(contentsOf: [0x12, 0x34]) // Transaction ID
        query.append(contentsOf: [0x01, 0x00]) // Flags
        query.append(contentsOf: [0x00, 0x01]) // Questions
        query.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00]) // Answer/Authority/Additional RRs
        
        for label in host.split(separator: ".") {
            query.append(UInt8(label.count))
            query.append(contentsOf: label.utf8)
        }
        query.append(0) // Null byte
        query.append(contentsOf: [0x00, 0x01]) // Query Type
        query.append(contentsOf: [0x00, 0x01]) // Query Class
        
        return query
    }
    
    func parseDNSResponse(data: Data) -> String? {
        // 1) Check minimum size for a DNS header: 12 bytes
        guard data.count >= 12 else {
            print("DNS response too short.")
            return nil
        }
        
        // -- DNS Header Layout (12 bytes) --
        // Bytes [0..1]: Transaction ID
        // Bytes [2..3]: Flags
        // Bytes [4..5]: QDCOUNT
        // Bytes [6..7]: ANCOUNT
        // Bytes [8..9]: NSCOUNT
        // Bytes [10..11]: ARCOUNT
        
        // 2) Read the flags to get the RCODE
        let flags = UInt16(data[2]) << 8 | UInt16(data[3])
        let rcode = flags & 0x000F  // lower 4 bits = RCODE
        if rcode != 0 {
            // Common codes: 3 = NXDOMAIN, 5 = REFUSED, etc.
            print("DNS response indicated error code (RCODE = \(rcode)).")
            return nil
        }
        
        // 3) Read QDCOUNT (Question Count) and ANCOUNT (Answer Count)
        let questionCount = Int(data[4]) << 8 | Int(data[5])
        let answerCount   = Int(data[6]) << 8 | Int(data[7])
        
        // If the server returns 0 answers, treat it as blocked/unresolved
        if answerCount == 0 {
            print("DNS response has 0 answer records.")
            return nil
        }
        
        // Start parsing right after the 12-byte header
        var offset = 12
        
        // 4) Skip all Question sections
        // For each question, we skip:
        //  - The domain name (in label format)
        //  - 4 bytes for type + class
        for _ in 0..<questionCount {
            // Skip the domain name in the question
            while offset < data.count, data[offset] != 0 {
                offset += Int(data[offset]) + 1
            }
            offset += 1 // skip the null terminator of the domain
            offset += 4 // skip type (2 bytes) + class (2 bytes)
        }
        
        // 5) Parse the Answer Section
        // We'll look for the first valid A (type=1, 4-byte RDATA) or AAAA (type=28, 16-byte RDATA).
        for _ in 0..<answerCount {
            // Each answer record has:
            //  - 2 bytes for name (often a pointer like 0xC0..)
            //  - 2 bytes for type
            //  - 2 bytes for class
            //  - 4 bytes for TTL
            //  - 2 bytes for RDLength
            //  - RDLength bytes for RDATA
            
            guard offset + 10 <= data.count else {
                print("Not enough data for answer record header.")
                return nil
            }
            
            // Skip the "NAME" field (2 bytes, often a pointer 0xC0..)
            offset += 2
            
            // Read the record TYPE
            let recordType = UInt16(data[offset]) << 8 | UInt16(data[offset + 1])
            offset += 2
            
            // Skip CLASS (2 bytes)
            offset += 2
            
            // Skip TTL (4 bytes)
            offset += 4
            
            // RDLength
            let rdLength = Int(data[offset]) << 8 | Int(data[offset + 1])
            offset += 2
            
            // Ensure we have enough bytes for RDATA
            guard offset + rdLength <= data.count else {
                print("RDATA length out of bounds.")
                return nil
            }
            
            switch recordType {
            case 1:
                // A record -> IPv4
                if rdLength == 4 {
                    let ipBytes = data[offset ..< offset+4]
                    let ipString = ipBytes.map { String($0) }.joined(separator: ".")
                    
                    // 6) Check if the server returns 0.0.0.0 or 127.x.x.x for blocked
                    if ipString == "0.0.0.0" || ipString.hasPrefix("127.") {
                        print("DNS indicates a block IP (\(ipString))")
                        return nil
                    }
                    // Return the first valid IPv4 address we find
                    return ipString
                } else {
                    // If rdLength isn't 4, skip RDATA
                    offset += rdLength
                }
                
            case 28:
                // AAAA record -> IPv6
                if rdLength == 16 {
                    let ipBytes = data[offset ..< offset+16]
                    
                    // Build an uncompressed IPv6 string, e.g. "fe800000000000000000000000000001"
                    var segments = [String]()
                    for i in stride(from: 0, to: 16, by: 2) {
                        let segment = String(format: "%02x%02x", ipBytes[i], ipBytes[i + 1])
                        segments.append(segment)
                    }
                    let ipv6String = segments.joined(separator: ":")
                    
                    // Example block check for IPv6 if your DNS returns something special for blocked
                    // (e.g., :: or ::1). If you have a known block IPv6, check it here.
                    // if ipv6String == "0000:0000:0000:0000:0000:0000:0000:0000" { ... }
                    
                    return ipv6String
                } else {
                    offset += rdLength
                }
                
            case 5:
                // CNAME record -> skip or handle
                // For advanced usage, parse the domain name from RDATA and do another DNS query.
                // We'll skip it here.
                offset += rdLength
                
            default:
                // Unknown record type -> skip
                offset += rdLength
            }
        }
        
        // If we reach here, no valid A or AAAA record was found
        return nil
    }
}
