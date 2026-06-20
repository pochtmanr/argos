// swift-tools-version: 6.0
// /Users/roman/Developer/iosbrowser/packages/BrowserCore/Package.swift
import PackageDescription

let package = Package(
  name: "BrowserCore",
  platforms: [.macOS(.v14), .iOS(.v17)],
  products: [
    .library(name: "BrowserCore", targets: ["BrowserCore"])
  ],
  targets: [
    .target(name: "BrowserCore", path: "Sources/BrowserCore")
  ]
)
