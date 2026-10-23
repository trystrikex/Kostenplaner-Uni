import Foundation

enum SupabaseConfig {
    // Replace these values with the Project URL and publishable key from your Supabase project.
    static let projectURL = URL(string: "https://vafmkfvamjilbcrxchai.supabase.co")!
    static let publishableKey = "sb_publishable_6OkWLmxXvj3tePXzHdneZg_i3KVkgPy"
    static let loginRedirectURL = URL(string: "kostenplaner://login-callback")!

    static var isConfigured: Bool {
        !projectURL.absoluteString.contains("YOUR-PROJECT")
            && !publishableKey.contains("YOUR-SUPABASE")
    }
}
