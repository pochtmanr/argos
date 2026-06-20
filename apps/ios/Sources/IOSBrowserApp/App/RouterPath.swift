// /Users/roman/Developer/iosbrowser/apps/ios/Sources/IOSBrowserApp/App/RouterPath.swift
import Observation

@MainActor
@Observable
final class RouterPath {
  var path: [Route] = []
  var presentedSheet: SheetDestination?

  func navigate(to route: Route) {
    path.append(route)
  }
}

enum Route: Hashable {
  case settings
}

enum SheetDestination: Identifiable {
  case profiles
  case assistant

  var id: String {
    switch self {
    case .profiles: "profiles"
    case .assistant: "assistant"
    }
  }
}
