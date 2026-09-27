package eu.tapredeem.waiter

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

/**
 * FlutterFragmentActivity because local_auth's BiometricPrompt needs a
 * FragmentActivity. Hosts the app's own platform channels (09 §7, §8).
 */
class MainActivity : FlutterFragmentActivity() {

    private lateinit var nfc: WaiterNfc
    private var feedback: WaiterFeedback? = null
    private var system: WaiterSystem? = null
    private var isResumedState = false

    override fun onCreate(savedInstanceState: Bundle?) {
        nfc = WaiterNfc(this)
        // Before super.onCreate: plugins (app_links) read the launch intent while
        // the Flutter fragment attaches, so the NFC tap must be taken out first.
        nfc.handleIntent(intent, restoredActivity = savedInstanceState != null)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        nfc.attach(messenger)
        feedback = WaiterFeedback(this, messenger).also { it.foreground = isResumedState }
        system = WaiterSystem(this, messenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        nfc.detach()
        feedback?.dispose()
        feedback = null
        system?.dispose()
        system = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onNewIntent(intent: Intent) {
        nfc.handleIntent(intent, restoredActivity = false)
        super.onNewIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        isResumedState = true
        feedback?.foreground = true
        nfc.onResume()
    }

    override fun onPause() {
        isResumedState = false
        feedback?.foreground = false
        nfc.onPause()
        super.onPause()
    }

    override fun onTopResumedActivityChanged(isTopResumedActivity: Boolean) {
        super.onTopResumedActivityChanged(isTopResumedActivity)
        nfc.onTopResumedActivityChanged(isTopResumedActivity)
    }

    override fun onDestroy() {
        nfc.dispose()
        super.onDestroy()
    }
}
