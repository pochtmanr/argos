// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/Features/Browser/AssistantSheetView.swift
import SwiftUI

struct AssistantSheetView: View {
  let pageTitle: String
  let pageURL: URL
  @State private var prompt = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("Current Page") {
          Text(pageTitle)
          Text(pageURL.absoluteString).font(.footnote).foregroundStyle(.secondary)
        }
        Section("Ask") {
          TextField("Question", text: $prompt, axis: .vertical)
          Button {
            submit()
          } label: {
            Label("Ask Assistant", systemImage: "paperplane")
          }
        }
      }
      .navigationTitle("Assistant")
    }
  }

  private func submit() {
    // Network-backed AI requests flow through the backend permission API.
  }
}
