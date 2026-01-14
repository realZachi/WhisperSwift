//
//  WhisperModelStatus.swift
//  localwhisper
//
//  Created by Mahmoud Ali Khan on 14.01.26.
//

import Combine
import Foundation

@MainActor
final class WhisperModelStatus: ObservableObject {
    enum Phase: String {
        case idle
        case downloading
        case ready
        case failed
    }

    static let shared = WhisperModelStatus()

    @Published var phase: Phase = .idle
    @Published var progressFraction: Double?
    @Published var message: String = "Model not downloaded"
    @Published var modelName: String = "large-v3-turbo"
    var requestDownload: (() -> Void)?

    func update(phase: Phase, progress: Double?, message: String, modelName: String) {
        self.phase = phase
        self.progressFraction = progress
        self.message = message
        self.modelName = modelName
    }
}
