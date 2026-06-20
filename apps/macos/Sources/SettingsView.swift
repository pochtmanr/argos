import BrowserCore
import SwiftUI

/// The Preferences window (Prompt 13), hosted by the `Settings` scene so macOS provides the ⌘,
/// "Settings…" app-menu item and the standard window automatically. A `TabView` of three `Form`s,
/// each bound directly to the live `@Observable` settings stores — so every change takes effect
/// immediately (the address/command bar re-reads the engine, new tabs/spaces open the new home page,
/// the archive sweep uses the new threshold) and persists via the stores' `UserDefaults` backing.
struct SettingsView: View {
  var body: some View {
    TabView {
      GeneralSettingsView()
        .tabItem { Label("General", systemImage: "gearshape") }

      SearchSettingsView()
        .tabItem { Label("Search", systemImage: "magnifyingglass") }

      TabsSettingsView()
        .tabItem { Label("Tabs", systemImage: "square.on.square") }
    }
    .frame(width: 460)
    .frame(minHeight: 240)
  }
}

// MARK: - General

/// Home/new-tab page, restore-on-launch, and the sidebar's default width.
private struct GeneralSettingsView: View {
  @Environment(AppSettings.self) private var appSettings

  var body: some View {
    @Bindable var appSettings = appSettings
    Form {
      Section {
        TextField("New-tab page", text: $appSettings.homeURLString, prompt: Text("https://example.com"))
          .textContentType(.URL)
        Text("Opens in every new tab and new space.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        Toggle("Restore tabs on launch", isOn: $appSettings.restoreOnLaunch)
        Text("When off, the app starts with a single fresh space each launch.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Section {
        // Discrete steps keep the value tidy; the label shows the current width. `NavigationSplitView`
        // applies this as the sidebar's default/opening width.
        Slider(value: $appSettings.sidebarIdealWidth, in: 180...360, step: 10) {
          Text("Sidebar width")
        } minimumValueLabel: {
          Text("180")
        } maximumValueLabel: {
          Text("360")
        }
        Text("Default sidebar width: \(Int(appSettings.sidebarIdealWidth)) pt")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Search

/// The default search engine: a preset picker plus a custom-template field for anything not listed.
private struct SearchSettingsView: View {
  @Environment(AppSettings.self) private var appSettings

  /// Whether the current template matches a built-in preset (controls the "Custom" picker row).
  private var isPreset: Bool {
    AppSettings.searchEngines.contains { $0.template == appSettings.searchTemplate }
  }

  var body: some View {
    @Bindable var appSettings = appSettings
    Form {
      Section {
        Picker("Search engine", selection: $appSettings.searchTemplate) {
          ForEach(AppSettings.searchEngines, id: \.template) { engine in
            Text(engine.name).tag(engine.template)
          }
          // Keep the picker valid (and labelled) when the user has a non-preset custom template.
          if !isPreset {
            Text("Custom").tag(appSettings.searchTemplate)
          }
        }
      }

      Section("Custom") {
        TextField("Search URL template", text: $appSettings.searchTemplate,
                  prompt: Text("https://example.com/search?q="))
        Text("Address-bar searches append your query to the end of this URL.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

// MARK: - Tabs

/// Auto-archive threshold (Prompt 11), moved here from the temporary Archived-sheet picker.
private struct TabsSettingsView: View {
  @Environment(ArchiveSettings.self) private var settings

  /// Threshold presets (seconds → label), shared with what the Archived sheet used to offer.
  private static let thresholdOptions: [(seconds: TimeInterval, label: String)] = [
    (1 * 60 * 60, "1 hour"),
    (12 * 60 * 60, "12 hours"),
    (24 * 60 * 60, "1 day"),
    (7 * 24 * 60 * 60, "1 week"),
  ]

  var body: some View {
    @Bindable var settings = settings
    Form {
      Section {
        Picker("Archive idle tabs after", selection: $settings.threshold) {
          ForEach(Self.thresholdOptions, id: \.seconds) { option in
            Text(option.label).tag(option.seconds)
          }
        }
        Text("Tabs left untouched this long are tucked into the Archived list. Pinned and active tabs are never archived.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }
}

#Preview {
  SettingsView()
    .environment(AppSettings())
    .environment(ArchiveSettings())
}
