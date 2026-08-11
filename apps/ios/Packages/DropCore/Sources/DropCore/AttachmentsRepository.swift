import Foundation
import Supabase

public protocol AttachmentsRepository: Sendable {
    /// 파일을 스토리지에 올리고 `attachments` 행을 만든다.
    func upload(
        data: Data,
        fileName: String,
        type: AttachmentType,
        toNote noteID: String
    ) async throws -> Attachment

    func delete(_ attachment: Attachment) async throws
    /// 비공개 버킷이라 화면에 띄우려면 서명 URL이 필요하다.
    func signedURL(for storagePath: String, expiresIn: Int) async throws -> URL
}

public extension AttachmentsRepository {
    func signedURL(for storagePath: String) async throws -> URL {
        try await signedURL(for: storagePath, expiresIn: 3600)
    }
}

public struct SupabaseAttachmentsRepository: AttachmentsRepository {
    private static let bucket = "attachments"

    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func upload(
        data: Data,
        fileName: String,
        type: AttachmentType,
        toNote noteID: String
    ) async throws -> Attachment {
        guard let user = client.auth.currentUser else { throw NotesRepositoryError.notAuthenticated }

        let fallbackExtension = Self.fallbackExtension(for: type)
        let storagePath = StoragePath.make(
            userID: user.id.uuidString,
            noteID: noteID,
            fileName: fileName,
            fallbackExtension: fallbackExtension
        )
        let mimeType = MIMEType.forExtension(
            StoragePath.fileExtension(of: fileName) ?? fallbackExtension
        )

        try await run {
            _ = try await client.storage.from(Self.bucket).upload(
                storagePath,
                data: data,
                options: FileOptions(contentType: mimeType)
            )
        }

        // 스토리지에는 올라갔는데 행 생성이 실패하면 고아 파일이 남는다.
        // 그 경우 올린 파일을 되돌려 두 저장소가 어긋난 채로 남지 않게 한다.
        do {
            return try await run {
                try await client.from("attachments")
                    .insert(AttachmentInsert(
                        noteId: noteID,
                        type: type.rawValue,
                        storagePath: storagePath,
                        filename: fileName,
                        mimeType: mimeType,
                        size: data.count
                    ))
                    .select()
                    .single()
                    .execute().value
            }
        } catch {
            try? await client.storage.from(Self.bucket).remove(paths: [storagePath])
            throw error
        }
    }

    public func delete(_ attachment: Attachment) async throws {
        try await run {
            _ = try await client.from("attachments").delete().eq("id", value: attachment.id).execute()
        }
        // 행이 지워졌으면 파일도 지운다. 실패해도 목록에는 이미 안 보이므로
        // 사용자 흐름을 막지 않는다.
        try? await client.storage.from(Self.bucket).remove(paths: [attachment.storagePath])
    }

    public func signedURL(for storagePath: String, expiresIn: Int) async throws -> URL {
        try await run {
            try await client.storage.from(Self.bucket).createSignedURL(path: storagePath, expiresIn: expiresIn)
        }
    }

    private static func fallbackExtension(for type: AttachmentType) -> String {
        switch type {
        case .audio: "m4a"
        case .image: "png"
        case .video: "mp4"
        default: "bin"
        }
    }

    private func run<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as PostgrestError {
            throw NotesRepositoryError.rejected(error.message)
        } catch let error as StorageError {
            throw NotesRepositoryError.rejected(error.message)
        } catch let error as DecodingError {
            throw NotesRepositoryError.decoding(String(describing: error))
        } catch {
            throw NotesRepositoryError.network(error.localizedDescription)
        }
    }
}

private struct AttachmentInsert: Encodable {
    let noteId: String
    let type: String
    let storagePath: String
    let filename: String
    let mimeType: String
    let size: Int
}
