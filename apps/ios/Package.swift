// /Users/roman/Developer/iosbrowser/apps/ios/Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "IOSBrowserApp",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "IOSBrowserApp", targets: ["IOSBrowserApp"])
  ],
  targets: [
    .target(name: "IOSBrowserApp", path: "Sources/IOSBrowserApp")
  ]
)
