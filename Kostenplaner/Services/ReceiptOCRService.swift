import Foundation

#if os(iOS)
import UIKit
import Vision
#endif

enum ReceiptOCRService {
    #if os(iOS)
    static func recognizedAmountCents(from image: UIImage) async -> Int? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, _ in
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: bestAmountCents(in: text))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false
            request.recognitionLanguages = ["de-DE", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
    #endif

    static func bestAmountCents(in text: String) -> Int? {
        let patterns = [
            #"(?i)(?:gesamt|summe|total|betrag|eur|€)\s*:?\s*(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})"#,
            #"(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})\s*(?:€|eur)"#,
            #"(\d{1,4}(?:[.,]\d{3})*[.,]\d{2})"#
        ]

        let candidates = patterns.flatMap { matches(pattern: $0, in: text) }
            .compactMap(parseAmountCents)
            .filter { $0 > 0 && $0 < 100_000_00 }

        return candidates.max()
    }

    private static func matches(pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { result in
            let capture = result.numberOfRanges > 1 ? result.range(at: 1) : result.range
            guard let swiftRange = Range(capture, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private static func parseAmountCents(_ rawValue: String) -> Int? {
        let cleaned = rawValue
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let decimalSeparator = cleaned.lastIndex(of: ",").map { ($0, ",") }
            ?? cleaned.lastIndex(of: ".").map { ($0, ".") }
        guard let separator = decimalSeparator else { return nil }

        let integerPart = cleaned[..<separator.0]
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
        let fractionPart = cleaned[cleaned.index(after: separator.0)...]
        guard fractionPart.count == 2 else { return nil }

        return Int("\(integerPart)\(fractionPart)")
    }
}
