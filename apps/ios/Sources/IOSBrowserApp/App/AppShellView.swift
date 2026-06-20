// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/App/AppShellView.swift
import SwiftUI

@MainActor
struct AppShellView: View {
  @Environment(ProfileStore.self) private var profileStore
  @Environment(BrowserState.self) private var browserState
  @State private var router = RouterPath()

  var body: some View {
    NavigationStack(path: $router.path) {
      BrowserView()
        .navigationTitle(profileStore.activeProfile.displayName)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              router.presentedSheet = .profiles
            } label: {
              Label("Profiles", systemImage: "person.crop.circle")
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              router.presentedSheet = .assistant
            } label: {
              Label("Assistant", systemImage: "sparkles")
            }
          }
        }
        .navigationDestination(for: Route.self) { route in
          switch route {
          case .settings:
            SettingsView()
          }
        }
    }
    .environment(router)
    .sheet(item: Binding(get: { router.presentedSheet }, set: { router.presentedSheet = $0 })) { sheet in
      switch sheet {
      case .profiles:
        ProfileListView()
      case .assistant:
        AssistantSheetView(pageTitle: browserState.pageTitle, pageURL: browserState.currentURL)
      }
    }
  }
}

#Preview {
  AppShellView()
    .environment(ProfileStore())
    .environment(BrowserState())
}
