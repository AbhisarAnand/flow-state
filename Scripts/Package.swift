// swift-tools-version: 5.9
// Benchmark package for testing transcription optimizations

import PackageDescription

let package = Package(
    name: "TranscriptionBenchmark",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    ],
    targets: [
        .executableTarget(
            name: "benchmark",
            dependencies: ["WhisperKit"],
            path: ".",
            sources: ["benchmark_transcription.swift"]
        ),
        .executableTarget(
            name: "test_streaming",
            dependencies: ["WhisperKit"],
            path: ".",
            sources: ["test_smart_streaming.swift"]
        ),
    ]
)
