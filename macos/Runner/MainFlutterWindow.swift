import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var speechPracticeHandler: MacSpeechPracticeHandler?
  private var textEmbeddingHandler: MacTextEmbeddingHandler?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    speechPracticeHandler = MacSpeechPracticeHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)
    textEmbeddingHandler = MacTextEmbeddingHandler(binaryMessenger: flutterViewController.engine.binaryMessenger)

    // 设置最小窗口尺寸，避免内容过窄导致布局混乱
    self.minSize = NSSize(width: 400, height: 600)

    super.awakeFromNib()
  }
}
