package app.echoloop

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var speechPracticeHandler: AndroidSpeechPracticeHandler? = null
    private var audioDecodeHandler: AndroidAudioDecodeHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        speechPracticeHandler = AndroidSpeechPracticeHandler(
            this, flutterEngine.dartExecutor.binaryMessenger,
        )
        audioDecodeHandler = AndroidAudioDecodeHandler(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        speechPracticeHandler?.dispose()
        speechPracticeHandler = null
        audioDecodeHandler?.dispose()
        audioDecodeHandler = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        speechPracticeHandler?.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
