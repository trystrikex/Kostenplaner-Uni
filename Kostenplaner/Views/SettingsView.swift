import SwiftUI

struct SettingsView: View {
    @Environment(AuthState.self) private var auth
    @Environment(BudgetStore.self) private var store

    var body: some View {
        @Bindable var auth = auth

        Form {
            Section("Supabase") {
                #if os(iOS)
                TextField("E-Mail", text: $auth.email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                #else
                TextField("E-Mail", text: $auth.email)
                #endif

                Button {
                    Task { await auth.sendLoginCode() }
                } label: {
                    if auth.isLoading {
                        ProgressView()
                    } else {
                        Label("Login-Code senden", systemImage: "envelope.fill")
                    }
                }

                Button {
                    Task { await store.sync() }
                } label: {
                    Label("Lokale Daten hochladen", systemImage: "icloud.and.arrow.up")
                }

                Button {
                    Task { await store.refreshFromCloud() }
                } label: {
                    Label("Cloud-Daten laden", systemImage: "icloud.and.arrow.down")
                }

                Text(auth.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("App") {
                LabeledContent("Währung", value: "EUR")
                LabeledContent("Sprache", value: "Deutsch")
                LabeledContent("Mindestversion", value: "iOS 17")
            }

            Section("Backend") {
                LabeledContent("Status", value: SupabaseConfig.isConfigured ? "Konfiguriert" : "Demo-Modus")
                Text("Project URL und publishable key liegen in SupabaseConfig.swift. Das SQL-Schema findest du in Supabase/schema.sql.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
