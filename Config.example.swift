// Config.example.swift
// Template for local secrets. Copy this file to Config.swift and fill in real values.
// Config.swift is gitignored — this file is the committed placeholder.

enum Config {
    nonisolated(unsafe) static let supabaseBaseURL = "https://YOUR_PROJECT.supabase.co/rest/v1"
    nonisolated(unsafe) static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
}
