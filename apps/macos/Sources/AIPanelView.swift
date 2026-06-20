import SwiftUI
import BrowserCore

/// The AI assistant inspector panel — a UI scaffold only. It lays out a chat transcript, an input
/// box, and an endpoint/key settings disclosure, but is **not wired to any model**: sending appends
/// the prompt locally and shows a placeholder reply. Hooking this to a real backend/model is a
/// follow-up.
struct AIPanelView: View {
  @State private var messages: [Message] = []
  @State private var draft = ""
  @State private var showingSettings = false
  @State private var endpoint = ""
  @State private var apiKey = ""

  private struct Message: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    enum Role { case user, assistant }
  }

  var body: some View {
    VStack(spacing: 0) {
      transcript
      Divider()
      composer
    }
  }

  private var transcript: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if messages.isEmpty {
          VStack(alignment: .leading, spacing: 6) {
            Label("Not connected", systemImage: "sparkles")
              .font(.subheadline)
              .foregroundStyle(.secondary)
            Text("This panel is a scaffold. Connect a model in settings to enable replies.")
              .font(.caption)
              .foregroundStyle(.tertiary)
          }
          .padding(.top, 8)
        }
        ForEach(messages) { message in
          bubble(message)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(12)
    }
  }

  private func bubble(_ message: Message) -> some View {
    let isUser = message.role == .user
    return HStack {
      if isUser { Spacer(minLength: 24) }
      Text(message.text)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(isUser ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
        )
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
      if !isUser { Spacer(minLength: 24) }
    }
  }

  private var composer: some View {
    VStack(spacing: 8) {
      DisclosureGroup("Connection", isExpanded: $showingSettings) {
        VStack(alignment: .leading, spacing: 6) {
          TextField("Endpoint URL", text: $endpoint)
            .textFieldStyle(.roundedBorder)
            .font(.system(.caption, design: .monospaced))
          SecureField("API key", text: $apiKey)
            .textFieldStyle(.roundedBorder)
          Text("Stored in memory only for now (not persisted, not sent).")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .padding(.top, 4)
      }
      .font(.caption)

      HStack(spacing: 6) {
        TextField("Ask anything…", text: $draft, axis: .vertical)
          .textFieldStyle(.roundedBorder)
          .lineLimit(1...4)
          .onSubmit(send)
        Button {
          send()
        } label: {
          Image(systemName: "arrow.up.circle.fill")
            .imageScale(.large)
        }
        .buttonStyle(.borderless)
        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .padding(12)
  }

  private func send() {
    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    messages.append(Message(role: .user, text: trimmed))
    draft = ""
    // Scaffold only: echo a placeholder until a model is wired in.
    messages.append(Message(role: .assistant, text: "AI is not connected yet. Configure a model in Connection to enable replies."))
  }
}
