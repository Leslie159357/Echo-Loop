import AVFoundation
import Flutter
import Speech
import UIKit

private enum SpeechPracticeError: String {
  case permissionDenied
  case notAvailable
  case noSpeech
  case invalidArguments
  case recordingFailed
  case finalTimeout
}

private let trimLeadingPaddingMs = 120.0
private let trimTrailingPaddingMs = 180.0

private final class IOSSpeechPracticeHandler: NSObject, FlutterStreamHandler {
  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private var audioEngine: AVAudioEngine?
  private var audioFile: AVAudioFile?
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private var currentFileURL: URL?
  private var currentPromptId: String?
  private var hasDetectedSpeech = false
  private var silenceStartAt: Date?
  private var lastReportedSilenceMs = -1
  private var recordedDurationMs = 0.0
  private var firstDetectedSpeechMs: Double?
  private var lastDetectedSpeechMs: Double?

  init(binaryMessenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(
      name: "top.valuespot.fluency/speech_practice",
      binaryMessenger: binaryMessenger
    )
    eventChannel = FlutterEventChannel(
      name: "top.valuespot.fluency/speech_practice/events",
      binaryMessenger: binaryMessenger
    )
    super.init()
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPermissionStatus":
      result(permissionMap())
    case "requestPermissions":
      requestPermissions(result: result)
    case "startSession":
      startSession(call.arguments as? [String: Any], result: result)
    case "stopSession":
      stopSession(result: result)
    case "cancelSession":
      cancelSession(result: result)
    case "deleteRecording":
      deleteRecording(call.arguments as? [String: Any], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func permissionMap() -> [String: String] {
    [
      "microphoneStatus": microphonePermissionStatus(),
      "speechStatus": speechPermissionStatus()
    ]
  }

  private func microphonePermissionStatus() -> String {
    switch AVAudioSession.sharedInstance().recordPermission {
    case .granted:
      return "granted"
    case .denied:
      return "denied"
    case .undetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  private func speechPermissionStatus() -> String {
    switch SFSpeechRecognizer.authorizationStatus() {
    case .authorized:
      return "granted"
    case .denied:
      return "denied"
    case .restricted:
      return "restricted"
    case .notDetermined:
      return "notDetermined"
    @unknown default:
      return "denied"
    }
  }

  private func requestPermissions(result: @escaping FlutterResult) {
    let group = DispatchGroup()
    group.enter()
    SFSpeechRecognizer.requestAuthorization { _ in
      group.leave()
    }

    group.enter()
    AVAudioSession.sharedInstance().requestRecordPermission { _ in
      group.leave()
    }

    group.notify(queue: .main) {
      result(self.permissionMap())
    }
  }

  private func startSession(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard microphonePermissionStatus() == "granted", speechPermissionStatus() == "granted" else {
      result(FlutterError(
        code: SpeechPracticeError.permissionDenied.rawValue,
        message: "Microphone or speech permission denied",
        details: nil
      ))
      return
    }

    guard
      let promptId = arguments?["promptId"] as? String,
      !promptId.isEmpty
    else {
      result(FlutterError(
        code: SpeechPracticeError.invalidArguments.rawValue,
        message: "Missing promptId",
        details: nil
      ))
      return
    }

    let localeIdentifier = (arguments?["locale"] as? String) ?? "en-US"
    guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)),
          recognizer.isAvailable
    else {
      result(FlutterError(
        code: SpeechPracticeError.notAvailable.rawValue,
        message: "Speech recognizer unavailable",
        details: nil
      ))
      return
    }

    cleanupLiveSession(cancelRecognition: true, restorePlayback: true)

    let fileName = sanitizedFileName(promptId)
    let fileURL = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("\(fileName)-\(Int(Date().timeIntervalSince1970 * 1000)).caf")

    do {
      try configureRecordingSession()

      let engine = AVAudioEngine()
      let inputNode = engine.inputNode
      let inputFormat = inputNode.outputFormat(forBus: 0)
      let request = SFSpeechAudioBufferRecognitionRequest()
      request.shouldReportPartialResults = true

      let audioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)

      currentPromptId = promptId
      currentFileURL = fileURL
      hasDetectedSpeech = false
      silenceStartAt = nil
      lastReportedSilenceMs = -1
      recordedDurationMs = 0
      firstDetectedSpeechMs = nil
      lastDetectedSpeechMs = nil
      self.audioFile = audioFile
      recognitionRequest = request
      audioEngine = engine

      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] recognitionResult, error in
        self?.handleRecognitionCallback(recognitionResult: recognitionResult, error: error)
      }

      inputNode.removeTap(onBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
        guard let self else { return }
        self.handleVoiceActivity(buffer: buffer)
        self.recognitionRequest?.append(buffer)
        do {
          let playbackBuffer = self.makeAmplifiedBuffer(from: buffer, gain: 2.2)
          try self.audioFile?.write(from: playbackBuffer)
        } catch {
          self.emitError(
            code: SpeechPracticeError.recordingFailed.rawValue,
            message: "Failed to write recording buffer"
          )
        }
      }

      engine.prepare()
      try engine.start()
      result(["filePath": fileURL.path])
    } catch {
      cleanupLiveSession(cancelRecognition: true, restorePlayback: true)
      result(FlutterError(
        code: SpeechPracticeError.recordingFailed.rawValue,
        message: "Failed to start live recording",
        details: error.localizedDescription
      ))
    }
  }

  private func stopSession(result: @escaping FlutterResult) {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    recognitionRequest?.endAudio()
    audioFile = nil
    if let fileURL = currentFileURL {
      trimRecordingIfNeeded(fileURL: fileURL)
    }
    result(["filePath": currentFileURL?.path as Any])
  }

  private func cancelSession(result: @escaping FlutterResult) {
    cleanupLiveSession(cancelRecognition: true, restorePlayback: true)
    result([:])
  }

  private func deleteRecording(_ arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let filePath = arguments?["filePath"] as? String, !filePath.isEmpty else {
      result([:])
      return
    }

    let url = URL(fileURLWithPath: filePath)
    if FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.removeItem(at: url)
    }
    if currentFileURL?.path == filePath {
      currentFileURL = nil
    }
    result([:])
  }

  private func handleRecognitionCallback(
    recognitionResult: SFSpeechRecognitionResult?,
    error: Error?
  ) {
    guard let promptId = currentPromptId else { return }

    if let error {
      emitEvent([
        "type": "error",
        "promptId": promptId,
        "errorCode": SpeechPracticeError.noSpeech.rawValue,
        "errorMessage": error.localizedDescription
      ])
      cleanupLiveSession(cancelRecognition: true, restorePlayback: true)
      return
    }

    guard let recognitionResult else {
      return
    }

    let transcript = recognitionResult.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
    if !transcript.isEmpty {
      emitEvent([
        "type": recognitionResult.isFinal
          ? "finalTranscriptReady"
          : "partialTranscriptUpdated",
        "promptId": promptId,
        "transcript": transcript
      ])
    }

    if recognitionResult.isFinal {
      cleanupLiveSession(cancelRecognition: false, restorePlayback: true)
    }
  }

  private func emitError(code: String, message: String) {
    guard let promptId = currentPromptId else { return }
    emitEvent([
      "type": "error",
      "promptId": promptId,
      "errorCode": code,
      "errorMessage": message
    ])
  }

  private func emitEvent(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(event)
    }
  }

  private func handleVoiceActivity(buffer: AVAudioPCMBuffer) {
    guard let promptId = currentPromptId else { return }
    let bufferDurationMs = (Double(buffer.frameLength) / buffer.format.sampleRate) * 1000
    let bufferStartMs = recordedDurationMs
    let bufferEndMs = bufferStartMs + bufferDurationMs

    if isSpeechDetected(in: buffer) {
      if !hasDetectedSpeech {
        hasDetectedSpeech = true
        emitEvent([
          "type": "speechStarted",
          "promptId": promptId
        ])
      }
      firstDetectedSpeechMs = firstDetectedSpeechMs ?? bufferStartMs
      lastDetectedSpeechMs = bufferEndMs

      if silenceStartAt != nil || lastReportedSilenceMs > 0 {
        emitEvent([
          "type": "silenceProgress",
          "promptId": promptId,
          "silenceMs": 0
        ])
      }
      silenceStartAt = nil
      lastReportedSilenceMs = 0
      recordedDurationMs = bufferEndMs
      return
    }

    recordedDurationMs = bufferEndMs
    guard hasDetectedSpeech else { return }

    let now = Date()
    if silenceStartAt == nil {
      silenceStartAt = now
    }
    let silenceMs = Int(now.timeIntervalSince(silenceStartAt ?? now) * 1000)
    if silenceMs == 0 || silenceMs - lastReportedSilenceMs >= 200 {
      lastReportedSilenceMs = silenceMs
      emitEvent([
        "type": "silenceProgress",
        "promptId": promptId,
        "silenceMs": silenceMs
      ])
    }
  }

  private func isSpeechDetected(in buffer: AVAudioPCMBuffer) -> Bool {
    let threshold: Float = 0.015

    if let channelData = buffer.floatChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return false }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let sample = channel[frame]
        sum += sample * sample
      }
      let rms = sqrt(sum / Float(frameLength))
      return rms >= threshold
    }

    if let channelData = buffer.int16ChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return false }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let normalized = Float(channel[frame]) / Float(Int16.max)
        sum += normalized * normalized
      }
      let rms = sqrt(sum / Float(frameLength))
      return rms >= threshold
    }

    return false
  }

  private func trimRecordingIfNeeded(fileURL: URL) {
    do {
      let sourceFile = try AVAudioFile(forReading: fileURL)
      guard let trimRange = detectSpeechRange(in: sourceFile) else {
        return
      }

      let sampleRate = sourceFile.processingFormat.sampleRate
      let startMs = max(0, trimRange.startMs - trimLeadingPaddingMs)
      let endMs = min(trimRange.endMs + trimTrailingPaddingMs, (Double(sourceFile.length) / sampleRate) * 1000.0)
      guard endMs - startMs > 120 else {
        return
      }

      let startFrame = AVAudioFramePosition((startMs / 1000.0) * sampleRate)
      let endFrame = AVAudioFramePosition((endMs / 1000.0) * sampleRate)
      let totalFrames = sourceFile.length
      let safeStartFrame = max(0, min(startFrame, totalFrames))
      let safeEndFrame = max(safeStartFrame, min(endFrame, totalFrames))
      let framesToCopy = safeEndFrame - safeStartFrame
      guard framesToCopy > 0 else { return }

      let tempURL = fileURL.deletingLastPathComponent()
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("caf")
      let outputFile = try AVAudioFile(
        forWriting: tempURL,
        settings: sourceFile.fileFormat.settings
      )

      sourceFile.framePosition = safeStartFrame
      let chunkSize: AVAudioFrameCount = 4096
      while sourceFile.framePosition < safeEndFrame {
        let remainingFrames = safeEndFrame - sourceFile.framePosition
        let framesThisPass = AVAudioFrameCount(min(Int64(chunkSize), remainingFrames))
        guard let buffer = AVAudioPCMBuffer(
          pcmFormat: sourceFile.processingFormat,
          frameCapacity: framesThisPass
        ) else {
          break
        }
        try sourceFile.read(into: buffer, frameCount: framesThisPass)
        if buffer.frameLength == 0 {
          break
        }
        try outputFile.write(from: buffer)
      }

      try FileManager.default.removeItem(at: fileURL)
      try FileManager.default.moveItem(at: tempURL, to: fileURL)
    } catch {
      // 保留原始录音即可，不阻塞识别结果返回。
    }
  }

  private func detectSpeechRange(in audioFile: AVAudioFile) -> (startMs: Double, endMs: Double)? {
    let chunkSize: AVAudioFrameCount = 2048
    let threshold: Float = 0.022
    let sampleRate = audioFile.processingFormat.sampleRate
    var firstSpeechFrame: AVAudioFramePosition?
    var lastSpeechFrame: AVAudioFramePosition?

    audioFile.framePosition = 0

    while audioFile.framePosition < audioFile.length {
      let remainingFrames = audioFile.length - audioFile.framePosition
      let framesThisPass = AVAudioFrameCount(min(Int64(chunkSize), remainingFrames))
      guard let buffer = AVAudioPCMBuffer(
        pcmFormat: audioFile.processingFormat,
        frameCapacity: framesThisPass
      ) else {
        break
      }

      let chunkStartFrame = audioFile.framePosition
      try? audioFile.read(into: buffer, frameCount: framesThisPass)
      if buffer.frameLength == 0 {
        break
      }

      if rmsLevel(of: buffer) >= threshold {
        firstSpeechFrame = firstSpeechFrame ?? chunkStartFrame
        lastSpeechFrame = chunkStartFrame + AVAudioFramePosition(buffer.frameLength)
      }
    }

    audioFile.framePosition = 0

    guard let firstSpeechFrame, let lastSpeechFrame, lastSpeechFrame > firstSpeechFrame else {
      return nil
    }

    return (
      startMs: (Double(firstSpeechFrame) / sampleRate) * 1000.0,
      endMs: (Double(lastSpeechFrame) / sampleRate) * 1000.0
    )
  }

  private func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
    if let channelData = buffer.floatChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return 0 }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let sample = channel[frame]
        sum += sample * sample
      }
      return sqrt(sum / Float(frameLength))
    }

    if let channelData = buffer.int16ChannelData {
      let frameLength = Int(buffer.frameLength)
      guard frameLength > 0 else { return 0 }
      var sum: Float = 0
      let channel = channelData[0]
      for frame in 0..<frameLength {
        let normalized = Float(channel[frame]) / Float(Int16.max)
        sum += normalized * normalized
      }
      return sqrt(sum / Float(frameLength))
    }

    return 0
  }

  private func makeAmplifiedBuffer(from buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
    guard let copy = AVAudioPCMBuffer(
      pcmFormat: buffer.format,
      frameCapacity: buffer.frameCapacity
    ) else {
      return buffer
    }
    copy.frameLength = buffer.frameLength

    if let source = buffer.floatChannelData, let destination = copy.floatChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = sourceChannel[frame] * gain
          destinationChannel[frame] = max(-1.0, min(1.0, amplified))
        }
      }
      return copy
    }

    if let source = buffer.int16ChannelData, let destination = copy.int16ChannelData {
      for channel in 0..<Int(buffer.format.channelCount) {
        let sourceChannel = source[channel]
        let destinationChannel = destination[channel]
        for frame in 0..<Int(buffer.frameLength) {
          let amplified = Float(sourceChannel[frame]) * gain
          let clamped = max(Float(Int16.min), min(Float(Int16.max), amplified))
          destinationChannel[frame] = Int16(clamped)
        }
      }
      return copy
    }

    return buffer
  }

  private func cleanupLiveSession(cancelRecognition: Bool, restorePlayback: Bool) {
    audioEngine?.inputNode.removeTap(onBus: 0)
    audioEngine?.stop()
    audioEngine = nil
    audioFile = nil

    recognitionRequest?.endAudio()
    recognitionRequest = nil

    if cancelRecognition {
      recognitionTask?.cancel()
    }
    recognitionTask = nil
    currentPromptId = nil
    hasDetectedSpeech = false
    silenceStartAt = nil
    lastReportedSilenceMs = -1
    recordedDurationMs = 0
    firstDetectedSpeechMs = nil
    lastDetectedSpeechMs = nil

    if restorePlayback {
      restorePlaybackSession()
    }
  }

  private func configureRecordingSession() throws {
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
    try session.setActive(true)
  }

  private func restorePlaybackSession() {
    do {
      let session = AVAudioSession.sharedInstance()
      try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
      try session.setActive(true)
    } catch {
      // Flutter 侧已有播放配置兜底，这里静默失败即可。
    }
  }

  private func sanitizedFileName(_ promptId: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
    let unicodeScalars = promptId.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
    return String(unicodeScalars)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var speechPracticeHandler: IOSSpeechPracticeHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let controller = window?.rootViewController as! FlutterViewController
    let networkChannel = FlutterMethodChannel(
      name: "top.valuespot.fluency/network",
      binaryMessenger: controller.binaryMessenger
    )
    networkChannel.setMethodCallHandler { (call, result) in
      if call.method == "triggerNetworkPermission" {
        guard let args = call.arguments as? [String: String],
              let urlString = args["url"],
              let url = URL(string: urlString) else {
          result(FlutterError(code: "INVALID_URL", message: "Invalid URL", details: nil))
          return
        }
        let task = URLSession.shared.dataTask(with: url) { _, _, _ in }
        task.resume()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    speechPracticeHandler = IOSSpeechPracticeHandler(binaryMessenger: controller.binaryMessenger)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
