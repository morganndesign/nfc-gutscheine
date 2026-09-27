package eu.tapredeem.waiter

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.security.GeneralSecurityException
import java.security.KeyStore
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

/**
 * Device facts, the app's settings page and the biometric enrolment
 * fingerprint (09 §7.5, §7.6) behind the channel `giftcard_waiter/system`.
 */
internal class WaiterSystem(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Keystore work (key generation can take > 100 ms) stays off the main thread. */
    private val keystoreExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    fun dispose() {
        channel.setMethodCallHandler(null)
        keystoreExecutor.shutdown()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "deviceFacts" -> result.success(deviceFacts())
            "openAppSettings" -> {
                openAppSettings()
                result.success(null)
            }
            "biometricEnrollment" -> runKeystore(result) { enrollmentState() }
            "resetBiometricEnrollment" -> runKeystore(result) {
                resetEnrollmentKey()
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun deviceFacts(): Map<String, Any> = mapOf(
        "platform" to "android",
        "osVersion" to Build.VERSION.RELEASE,
        "model" to Build.MODEL,
        "isTablet" to (activity.resources.configuration.smallestScreenWidthDp >= TABLET_MIN_WIDTH_DP),
    )

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", activity.packageName, null))
        try {
            activity.startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            try {
                activity.startActivity(Intent(Settings.ACTION_SETTINGS))
            } catch (_: ActivityNotFoundException) {
                // No settings app reachable on this device.
            }
        }
    }

    private fun runKeystore(result: MethodChannel.Result, work: () -> String?) {
        keystoreExecutor.execute {
            val value = work()
            mainHandler.post { result.success(value) }
        }
    }

    // region Biometric enrolment (09 §7.5)

    /**
     * "valid" while the enrolment key is usable, "changed" once a biometric was
     * added (the key is permanently invalidated until [resetEnrollmentKey]),
     * null when no biometrics are enrolled (the key cannot be created). Any
     * Keystore failure also yields null, which the Dart side treats as
     * "not the stored value" → password required (fail safe).
     */
    private fun enrollmentState(): String? {
        val keyStore = loadKeyStore() ?: return null
        val key = try {
            keyStore.getKey(ENROLLMENT_KEY_ALIAS, null) as? SecretKey
        } catch (_: GeneralSecurityException) {
            null
        } ?: return if (createKey(ENROLLMENT_KEY_ALIAS)) STATE_VALID else null

        return try {
            Cipher.getInstance(CIPHER_TRANSFORMATION).init(Cipher.ENCRYPT_MODE, key)
            STATE_VALID
        } catch (_: KeyPermanentlyInvalidatedException) {
            // Invalidated by a new enrolment — or because every biometric was
            // removed, which counts as "none enrolled".
            if (biometricsEnrolled(keyStore)) STATE_CHANGED else null
        } catch (_: GeneralSecurityException) {
            STATE_CHANGED
        }
    }

    /** After a password sign-in (P13): a fresh key bound to the current enrolment. */
    private fun resetEnrollmentKey() {
        val keyStore = loadKeyStore() ?: return
        deleteQuietly(keyStore, ENROLLMENT_KEY_ALIAS)
        createKey(ENROLLMENT_KEY_ALIAS)
    }

    /** A key requiring biometric authentication can only be created while one is enrolled. */
    private fun biometricsEnrolled(keyStore: KeyStore): Boolean {
        val created = createKey(PROBE_KEY_ALIAS)
        deleteQuietly(keyStore, PROBE_KEY_ALIAS)
        return created
    }

    private fun createKey(alias: String): Boolean = try {
        val spec = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(KEY_SIZE_BITS)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .build()
        KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
            init(spec)
            generateKey()
        }
        true
    } catch (_: GeneralSecurityException) {
        false
    } catch (_: RuntimeException) {
        // IllegalStateException "At least one biometric must be enrolled…", ProviderException.
        false
    }

    private fun loadKeyStore(): KeyStore? = try {
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    } catch (_: GeneralSecurityException) {
        null
    } catch (_: IOException) {
        null
    }

    private fun deleteQuietly(keyStore: KeyStore, alias: String) {
        try {
            if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        } catch (_: GeneralSecurityException) {
            // Entry already gone.
        }
    }

    // endregion

    private companion object {
        const val CHANNEL = "giftcard_waiter/system"
        const val TABLET_MIN_WIDTH_DP = 600

        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val ENROLLMENT_KEY_ALIAS = "gcw_biometric_enrollment"
        const val PROBE_KEY_ALIAS = "gcw_biometric_enrollment_probe"
        const val CIPHER_TRANSFORMATION = "AES/GCM/NoPadding"
        const val KEY_SIZE_BITS = 256

        const val STATE_VALID = "valid"
        const val STATE_CHANGED = "changed"
    }
}
