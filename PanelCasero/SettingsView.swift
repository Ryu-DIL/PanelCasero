import SwiftUI

/// Ajustes básicos. En la fase de la alarma se protegerá con el PIN.
struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(settings.t("appearance"))) {
                    Picker(settings.t("appearance"), selection: $settings.appearance) {
                        Text(settings.t("dark")).tag(AppAppearance.dark)
                        Text(settings.t("light")).tag(AppAppearance.light)
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text(settings.t("language"))) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button(action: { settings.language = lang }) {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if settings.language == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
                Section(header: Text(settings.t("test_section"))) {
                    Button(settings.t("simulate_motion")) {
                        BrightnessController.shared.motionDetected()
                    }
                }
            }
            .navigationTitle(settings.t("settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(settings.t("close")) { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
