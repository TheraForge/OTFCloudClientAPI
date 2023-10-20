/*
Copyright (c) 2021, Hippocrates Technologies S.r.l.. All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of the copyright holder(s) nor the names of any contributor(s) may
be used to endorse or promote products derived from this software without specific
prior written permission. No license is granted to the trademarks of the copyright
holders even if such marks are included in this software.

4. Commercial redistribution in any form requires an explicit license agreement with the
copyright holder(s). Please contact support@hippocratestech.com for further information
regarding licensing.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY
OF SUCH DAMAGE.
 */

import Foundation

extension Data {
    
    public func multipartArray(withBoundary boundary: String,
                        key: String = "Content-Disposition: ",
                        keyToRemove: String = "Content-Type:") -> [(contentType: String, body: Data)]? {
        func extractBody(_ data: Data) -> Data? {
            guard let startOfLine = key.data(using: .utf8) else { return nil }
            guard let endOfLine = "\r\n".data(using: .utf8) else { return nil }
            
            var result: Data?
            var pos = data.startIndex
            
            while let r1 = data[pos...].range(of: startOfLine) {
                if let r2 = data[r1.upperBound...].range(of: endOfLine) {
                    pos = r2.upperBound
                }
            }
            
            if pos < data.endIndex {
                var dataCopy = data
                clean(data: &dataCopy)
                result = dataCopy[(pos+2)...(dataCopy.endIndex-2)].dropLast(3)
            }
            
            return result
        }
        
        func clean(data: inout Data) {
            guard let startOfLine = keyToRemove.data(using: .utf8) else { return }
            guard let endOfLine = "\r\n".data(using: .utf8) else { return }
            let r1 = data.range(of: startOfLine)
            
            if let r1 = r1,
               let r2 = data[r1.upperBound...].range(of: endOfLine) {
                let range = Range<Data.Index>.init(uncheckedBounds: (lower: r1.lowerBound, upper: r2.upperBound))
                data.removeSubrange(range)
            }
        }
        
        let multiparts = components(separatedBy: (boundary))
        let cleanedMultiparts = multiparts
            .enumerated()
            .map({ $0 == multiparts.count-1 ? $1.dropLast(2) : $1 })
        var result: [(String, Data)]?
        for part in cleanedMultiparts {
            for contentTypeData in part.slices(between: key, and: "\r") {
                if let contentType = String(data: contentTypeData, encoding: .utf8),
                   let body = extractBody(part) {
                    if result == nil {
                        result = [(String, Data)]()
                    }
                    result?.append((contentType.trimmingCharacters(in: .whitespacesAndNewlines), body))
                } else {
                    continue
                }
            }
        }
        return result
    }
    
    public func slices(between from: String, and to: String) -> [Data] {
        guard let from = from.data(using: .utf8) else { return [] }
        guard let to = to.data(using: .utf8) else { return [] }
        return slices(between: from, and: to)
    }
    
   public func slices(between from: Data, and to: Data) -> [Data] {
        var chunks: [Data] = []
        var pos = startIndex
        while let r1 = self[pos...].range(of: from),
              let r2 = self[r1.upperBound...].range(of: to) {
            chunks.append(self[r1.upperBound..<r2.lowerBound])
            pos = r1.upperBound
        }
        return chunks
    }
    
    public func components(separatedBy separator: String) -> [Data] {
        guard let separator = separator.data(using: .utf8)  else { return [] }
        return components(separatedBy: separator)
    }
    
    public func components(separatedBy separator: Data) -> [Data] {
        var chunks: [Data] = []
        var pos = startIndex
        while let r = self[pos...].range(of: separator) {
            if r.lowerBound > pos {
                chunks.append(self[pos..<r.lowerBound])
            }
            pos = r.upperBound
        }
        
        if pos < endIndex {
            chunks.append(self[pos..<endIndex])
        }
        
        return chunks
    }
}
