import Foundation
import Vision
import ImageIO
import HexPickCore

struct OCRLine: Identifiable, Sendable {
    let id: UUID
    let text: String
    let confidence: Float
    let x: Double
    let y: Double
    let matches: [NameMatch]
}
actor OCRService {
    func recognize(data: Data, augments: [String: Augment]) throws -> [OCRLine] {
        guard data.count < 40_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 3000
              ] as CFDictionary) else { throw DataError.invalid("无法读取照片，或照片过大") }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        request.usesLanguageCorrection = false
        request.customWords = augments.values.map(\.name)
        let handler = VNImageRequestHandler(cgImage: thumbnail, options: [:])
        try handler.perform([request])
        return (request.results ?? []).compactMap { observation in
            guard let text = observation.topCandidates(1).first else { return nil }
            return OCRLine(id: UUID(), text: text.string, confidence: text.confidence,
                           x: observation.boundingBox.midX, y: observation.boundingBox.midY,
                           matches: NameMatcher.match(text.string, augments: augments))
        }.sorted { abs($0.y - $1.y) < 0.04 ? $0.x < $1.x : $0.y > $1.y }
    }
}
