import SwiftUI
import BrowserCore

struct ContentView: View {
  var body: some View {
    Text("Browser")
      .frame(minWidth: 800, minHeight: 600)
      // Reference BrowserCore to prove the SPM link resolves.
      .help("BrowserCore v\(BrowserCoreInfo.version)")
  }
}

#Preview {
  ContentView()
}
