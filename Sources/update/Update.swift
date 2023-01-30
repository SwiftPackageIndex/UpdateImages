// Copyright Dave Verwer, Sven A. Schmidt, and other contributors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import ArgumentParser

@main
struct Update: AsyncParsableCommand {
    static let configuration = CommandConfiguration(abstract: "Update the Swift Package Index image SCSS file.")

    @Option(name: [.customLong("input")], help: "The path to a folder containing the source SVG images.")
    var inputDirectory: String

    @Option(name: [.customLong("output")], help: "The path to the SwiftPackageIndex-Server source code.")
    var outputDirectory: String

    mutating func run() async throws {
        let allFiles = try FileManager.default.contentsOfDirectory(atPath: inputDirectory.expandingTildes())
        let lightFiles = allFiles.filter { $0.hasSuffix("~light.svg") }
        let darkFiles = allFiles.filter { $0.hasSuffix("~dark.svg") }

        if lightFiles.count != darkFiles.count {
            throw RuntimeError("Mismatching number of files (\(lightFiles.count) light \(darkFiles.count) dark).")
        }

        var output = SourceTemplate.header
        output += try imageCSS(from: lightFiles)
        output += "\n"
        output += try imageCSS(from: darkFiles, mediaQuery: "prefers-color-scheme: dark")
        try output.write(toFile: pathToOutputFile(), atomically: true, encoding: .utf8)
    }

    func imageCSS(from files: [String], mediaQuery: String? = nil) throws -> String {
        var lines: [String] = []

        // If the CSS is inside a media query it needs to be double indented.
        let indentation = mediaQuery.isEmpty ? "    " : "        "

        // Open up a root element for variables, either in or out of a media query.
        if let mediaQuery {
            lines.append("@media (\(mediaQuery)) {")
            lines.append("    :root {")
        } else {
            lines.append(":root {")
        }

        // Insert all of the image variables.
        for file in files.sorted() {
            let path = inputDirectory.appendingPathComponent(path: file).expandingTildes()
            let svgData = try Data(contentsOf: URL(fileURLWithPath: path))
            let cssUrlData = "data:image/svg+xml;base64,\(svgData.base64EncodedString())"
            let cssVariable = "--image-\(file.removingRegexMatches(pattern: #"~(light|dark)\.svg"#))"

            let line = "\(indentation)\(cssVariable): url('\(cssUrlData)');"
            lines.append(line)
        }

        // Close the root element and optionally the media query.
        if let _ = mediaQuery {
            lines.append("    }")
            lines.append("}")
        } else {
            lines.append("}")
        }

        return lines.joined(separator: "\n").appending("\n")
    }

    func pathToOutputFile() -> String {
        outputDirectory.appendingPathComponent(path: "FrontEnd/styles/images.scss").expandingTildes()
    }
}

struct RuntimeError: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}

extension String {
    public func appendingPathComponent(path: String) -> String {
        NSString(string: self).appendingPathComponent(path)
    }

    public func expandingTildes() -> String {
        NSString(string: self).expandingTildeInPath
    }
}

extension String {
    func removingRegexMatches(pattern: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: count)
            return regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "")
        } catch {
            return self
        }
    }
}

extension Optional where Wrapped == String {
    var isEmpty: Bool {
        guard let self else { return true }
        return self.isEmpty
    }
}
