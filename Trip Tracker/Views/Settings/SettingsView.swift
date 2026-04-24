import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue

    @State private var showingExportAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    appearanceCard
                    aboutCard
                    dataCard
                }
                .padding()
            }
            .background(AppTheme.ColorToken.canvas)
            .navigationTitle("Settings")
            .alert("Export trips", isPresented: $showingExportAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Coming soon for MVP.")
            }
        }
    }

    private var appearanceCard: some View {
        SectionCard(
            title: "Appearance",
            subtitle: "Choose how Trip Tracker looks across the app."
        ) {
            VStack(spacing: 10) {
                ForEach(AppearancePreference.allCases) { option in
                    Button {
                        appearance = option.rawValue
                        Haptics.selection()
                    } label: {
                        HStack {
                            Text(option.label)
                                .foregroundStyle(AppTheme.ColorToken.ink)
                            Spacer()
                            if currentAppearance == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.ColorToken.accent)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(AppTheme.ColorToken.muted)
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(currentAppearance == option
                                    ? AppTheme.ColorToken.accentSoft
                                    : AppTheme.ColorToken.canvas)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var aboutCard: some View {
        SectionCard(
            title: "About",
            subtitle: "A quiet home for your travel history."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                infoRow(label: "App", value: "Trip Tracker")
                infoRow(label: "Version", value: appVersion)
                infoRow(label: "Build", value: buildNumber)

                Text("Crafted to make your past trips feel easy to revisit and worth keeping.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)

                Text("Built by Mendia.")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            }
        }
    }

    private var dataCard: some View {
        SectionCard(
            title: "Data",
            subtitle: "Local-first for MVP."
        ) {
            Button {
                showingExportAlert = true
                Haptics.selection()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Export trips")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.ColorToken.ink)
                        Text("Coming soon")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.ColorToken.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(AppTheme.ColorToken.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.ColorToken.canvas)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(AppTheme.ColorToken.secondaryInk)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.ColorToken.ink)
        }
        .font(.subheadline)
    }

    private var currentAppearance: AppearancePreference {
        AppearancePreference(rawValue: appearance) ?? .system
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

#Preview {
    SettingsView()
}
