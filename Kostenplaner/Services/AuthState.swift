import Foundation
import Observation

@MainActor
@Observable
final class AuthState {
    var email = ""
    var isAuthenticated = false
    var isLoading = false
    var message = "Demo-Modus aktiv. Trage deine Supabase-Daten ein, um Cloud-Sync zu nutzen."

    func sendLoginCode() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            message = "Bitte gib eine E-Mail-Adresse ein."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseGateway.shared.sendLoginCode(email: email)
            message = "Login-Code wurde gesendet. Öffne den Link oder gib den Code in Supabase ein."
        } catch {
            message = error.localizedDescription
        }
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseGateway.shared.signOut()
            isAuthenticated = false
            message = "Abgemeldet."
        } catch {
            message = error.localizedDescription
        }
    }

    func handleLoginCallback(url: URL) async {
        guard url.scheme == "kostenplaner" else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            try await SupabaseGateway.shared.handleLoginCallback(url: url)
            isAuthenticated = true
            message = "Login erfolgreich."
        } catch {
            message = error.localizedDescription
        }
    }
}
