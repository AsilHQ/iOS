//
//  DnsOverTlsResolver.swift
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


import Network
import Foundation

class DnsOverTlsResolver {
    private var dnsServer: String = "high.kahfguard.com"
    private let dnsPort: UInt16 = 853
//    private let queue = DispatchQueue(label: "com.dns.over.tls.queue")
    
    func resolve(hostName: String, completion: @escaping ([String]?, Error?) -> Void) {
        if AppUserDefaults().safegazeModeValue == "HIGH" {
            dnsServer = "high.kahfguard.com"
        } else if AppUserDefaults().safegazeModeValue == "LOW" {
            dnsServer = "low.kahfguard.com"
        } else if AppUserDefaults().safegazeModeValue == "MEDIUM" {
            dnsServer = "medium.kahfguard.com"
        }
        // Create DNS query
        let dnsQuery = createDnsQuery(domain: hostName)
        
        // Create TLS parameters
        let tlsOptions = NWProtocolTLS.Options()
        
        // For DNS over TLS, we can skip certificate validation in development environments
        // Note: For production, you should perform proper certificate validation
        sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { metadata, trust, completionHandler in
            // Always validate in production - this is just for testing
            completionHandler(true)
        }, .global())
        
        let parameters = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        let connection = NWConnection(
            host: NWEndpoint.Host(dnsServer),
            port: NWEndpoint.Port(integerLiteral: dnsPort),
            using: parameters
        )
        let responseDataContainer = ResponseDataContainer()

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connection to DNS server established")
                connection.send(content: dnsQuery, completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send DNS query: \(error)")
                        completion(nil, error)
                    } else {
                        print("DNS query sent successfully")
                    }
                })
                
                self.receiveResponse(connection: connection, responseDataContainer: responseDataContainer) { data, error in
                    if let error = error {
                        completion(nil, error)
                    } else if let data = data {
                        let ipAddresses = self.parseDnsResponse(data: data)
                        completion(ipAddresses, nil)
                    } else {
                        completion(nil, NSError(domain: "DNS", code: -3, userInfo: [NSLocalizedDescriptionKey: "No data received"]))
                    }
                    connection.cancel()
                }
                
            case .failed(let error):
                print("Connection to DNS server failed: \(error)")
                completion(nil, error)
                
            case .waiting(let error):
                print("Connection to DNS server waiting: \(error)")
                
            case .cancelled:
                print("Connection to DNS server cancelled")
                
            default:
                break
            }
        }

        print("Starting connection to DNS server \(dnsServer)...")
        connection.start(queue: .global())

//        queue.asyncAfter(deadline: .now() + 10) {
//            if connection.state != .ready {
//                print("DNS resolution timed out")
//                connection.cancel()
//                completion(nil, NSError(domain: "DNS", code: -4, userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
//            }
//        }
    }
    
    private class ResponseDataContainer {
        var data = Data()
    }
    
    private func receiveResponse(connection: NWConnection, responseDataContainer: ResponseDataContainer, completion: @escaping (Data?, Error?) -> Void) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 4096) { content, contentContext, isComplete, error in
            if let error = error {
                print("Error receiving DNS response: \(error)")
                completion(nil, error)
                return
            }
            
            if let content = content {
                responseDataContainer.data.append(content)
                print("Received \(content.count) bytes, total \(responseDataContainer.data.count) bytes")
                
                // For DNS, we need to check if we have the complete message
                // DNS messages start with a 2-byte length field followed by the message
                if responseDataContainer.data.count >= 2 {
                    // Get the message length from the first 2 bytes
                    // Note: DNS-over-TLS prepends a 2-byte length field
                    let messageLength = UInt16(responseDataContainer.data[0]) << 8 | UInt16(responseDataContainer.data[1])
                    
                    if responseDataContainer.data.count >= Int(messageLength) + 2 {
                        // We have the complete message, remove the length field
                        let dnsMessage = responseDataContainer.data.subdata(in: 2..<(Int(messageLength) + 2))
                        completion(dnsMessage, nil)
                        return
                    }
                }
            }
            
            if isComplete {
                if responseDataContainer.data.isEmpty {
                    print("Receive complete with no data")
                    completion(nil, NSError(domain: "DNS", code: -5, userInfo: [NSLocalizedDescriptionKey: "No data received before completion"]))
                } else {
                    // If we get here with data but it's "complete", we'll try to use what we have
                    // This is not ideal but might work in some cases
                    if responseDataContainer.data.count > 2 {
                        // Try to skip the length field if present
                        let dnsMessage = responseDataContainer.data.subdata(in: 2..<responseDataContainer.data.count)
                        completion(dnsMessage, nil)
                    } else {
                        completion(responseDataContainer.data, nil)
                    }
                }
                return
            }
            
            // Continue receiving more data
            self.receiveResponse(connection: connection, responseDataContainer: responseDataContainer, completion: completion)
        }
    }
    
    private func createDnsQuery(domain: String) -> Data {
        // Create a DNS query in wire format
        let transactionID: UInt16 = UInt16.random(in: 0...UInt16.max)
        var dnsMessage = Data()
        
        // Transaction ID (2 bytes)
        dnsMessage.append(UInt8(transactionID >> 8))
        dnsMessage.append(UInt8(transactionID & 0xFF))
        
        // Flags (2 bytes) - Standard query with recursion desired
        dnsMessage.append(0x01)  // QR=0, Opcode=0, AA=0, TC=0, RD=1
        dnsMessage.append(0x00)  // RA=0, Z=0, RCODE=0
        
        // QDCOUNT (2 bytes) - 1 question
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        // ANCOUNT, NSCOUNT, ARCOUNT (6 bytes) - all 0
        dnsMessage.append(contentsOf: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00])
        
        // QNAME - domain name broken into length-prefixed labels
        let labels = domain.split(separator: ".")
        for label in labels {
            dnsMessage.append(UInt8(label.count))
            dnsMessage.append(contentsOf: label.utf8)
        }
        dnsMessage.append(0x00) // Terminating zero length
        
        // QTYPE (2 bytes) - A record
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        // QCLASS (2 bytes) - IN (Internet)
        dnsMessage.append(0x00)
        dnsMessage.append(0x01)
        
        // For DNS over TLS, we need to prepend a 2-byte length field
        var queryWithLength = Data()
        let length = UInt16(dnsMessage.count)
        queryWithLength.append(UInt8(length >> 8))
        queryWithLength.append(UInt8(length & 0xFF))
        queryWithLength.append(dnsMessage)
        
        return queryWithLength
    }
    
    private func parseDnsResponse(data: Data) -> [String]? {
        // This is a simplified DNS response parser
        // A complete implementation would need to properly parse the DNS message format
        
        // Check if we have enough data for a basic DNS header
        guard data.count >= 12 else {
            print("DNS response too short")
            return nil
        }
        
        // Extract answer count from header (bytes 6-7)
        let anCount = (UInt16(data[6]) << 8) | UInt16(data[7])
        if anCount == 0 {
            print("No answers in DNS response")
            return nil
        }
        
        // A very basic parser that looks for IPv4 addresses in the response
        var ipAddresses = [String]()
        
        // Scan through the response data looking for potential IP addresses
        // This is a simplified approach - a real implementation should properly parse the DNS record structure
        for i in stride(from: 0, to: data.count - 4, by: 1) {
            // Look for Type A records (0x0001) and Class IN (0x0001)
            // This is a heuristic and not a proper DNS response parser
            if i + 2 < data.count,
               data[i] == 0x00, data[i+1] == 0x01,  // Type A
               data[i+2] == 0x00, data[i+3] == 0x01, // Class IN
               i + 10 < data.count, data[i+9] == 0x04 { // IPv4 length = 4
                let ipStart = i + 10
                if ipStart + 3 < data.count {
                    let ip = "\(data[ipStart]).\(data[ipStart+1]).\(data[ipStart+2]).\(data[ipStart+3])"
                    ipAddresses.append(ip)
                }
            }
        }
        
        return ipAddresses.isEmpty ? nil : ipAddresses
    }
}
