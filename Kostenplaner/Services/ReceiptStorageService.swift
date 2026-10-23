import Foundation

#if os(iOS)
import UIKit

struct ReceiptImageDraft: Identifiable, Hashable {
    var id = UUID()
    var image: UIImage
    var fileName: String
    var mimeType = "image/jpeg"
}

enum ReceiptStorageService {
    static func compressedJPEGData(from image: UIImage, maxPixelSize: CGFloat = 1600, quality: CGFloat = 0.75) -> Data? {
        let longestSide = max(image.size.width, image.size.height)
        let scale = min(maxPixelSize / max(longestSide, 1), 1)
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    static func uploadReceipt(_ draft: ReceiptImageDraft, transactionID: UUID) async throws -> ReceiptMetadata {
        guard let data = compressedJPEGData(from: draft.image) else {
            throw ReceiptStorageError.compressionFailed
        }

        let metadata = try await SupabaseGateway.shared.uploadReceipt(
            data: data,
            transactionID: transactionID,
            fileName: draft.fileName,
            mimeType: draft.mimeType
        )
        return metadata
    }
}
#else
struct ReceiptImageDraft: Identifiable, Hashable {
    var id = UUID()
    var fileName: String
    var mimeType = "image/jpeg"
}

enum ReceiptStorageService {}
#endif

enum ReceiptStorageError: LocalizedError {
    case compressionFailed

    var errorDescription: String? {
        switch self {
        case .compressionFailed:
            "Der Beleg konnte nicht komprimiert werden."
        }
    }
}
