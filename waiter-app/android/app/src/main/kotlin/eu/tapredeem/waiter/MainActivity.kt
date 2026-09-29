package eu.tapredeem.waiter

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity because local_auth's BiometricPrompt needs a
 * FragmentActivity. Hosts the app's own platform channels (09 §7, §8).
 */
class MainActivity : FlutterFragmentActivity() {

    private var feedback: WaiterFeedback? = null
    private var system: WaiterSystem? = null
    private var isResumedState = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        feedback = WaiterFeedback(this, messenger).also { it.foreground = isResumedState }
        system = WaiterSystem(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        feedback?.dispose()
        feedback = null
        system?.dispose()
        system = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onResume() {
        super.onResume()
        isResumedState = true
        feedback?.foreground = true
    }

    override fun onPause() {
        isResumedState = false
        feedback?.foreground = false
        super.onPause()
    }
}
