package eu.tapredeem.waiter

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.view.HapticFeedbackConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Haptics and sounds on Android (09 §7.8, 11 §4.1, §5.2, §7) behind the
 * channel `giftcard_waiter/feedback`. Dart decides WHAT plays (tokens, Menu
 * switches, T5/T6 spacing); this class decides HOW, and applies the system
 * settings of 11 §7.1.
 */
internal class WaiterFeedback(private val activity: Activity, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, CHANNEL).also { it.setMethodCallHandler(this) }
    private val mainHandler = Handler(Looper.getMainLooper())
    private val audioManager: AudioManager? = activity.getSystemService(AudioManager::class.java)
    private val notificationManager: NotificationManager? =
        activity.getSystemService(NotificationManager::class.java)
    private val vibrator: Vibrator? = resolveVibrator(activity)

    private val soundAttributes: AudioAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()
    private val soundPool: SoundPool = SoundPool.Builder()
        .setMaxStreams(MAX_STREAMS)
        .setAudioAttributes(soundAttributes)
        .build()
    private val soundIds = HashMap<String, Int>()
    private val loadedSoundIds = HashSet<Int>()
    private var playingStreamId = 0

    private var pendingWaveform: Runnable? = null

    /** T8: no haptics or sounds while the app is not in the foreground. */
    var foreground = false

    init {
        soundPool.setOnLoadCompleteListener { _, sampleId, status ->
            if (status == 0) loadedSoundIds.add(sampleId)
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        cancelPendingWaveform()
        soundPool.release()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "preload" -> preload(call.argument<List<String>>("sounds").orEmpty(), result)
            "haptic" -> {
                val key = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) "api30" else "fallback"
                call.argument<Map<String, Any?>>(key)?.let(::playHaptic)
                result.success(null)
            }
            "sound" -> {
                call.argument<String>("file")?.let(::playSound)
                result.success(null)
            }
            // `prepare` warms up the iOS Taptic Engine; nothing to prepare on Android.
            else -> result.notImplemented()
        }
    }

    // region Sounds

    private fun preload(files: List<String>, result: MethodChannel.Result) {
        val unknown = mutableListOf<String>()
        for (file in files) {
            if (soundIds.containsKey(file)) continue
            val resource = SOUND_RESOURCES[file]
            if (resource == null) {
                unknown.add(file)
                continue
            }
            soundIds[file] = soundPool.load(activity, resource, 1)
        }
        if (unknown.isEmpty()) {
            result.success(null)
        } else {
            result.error("unknown_sound", "No res/raw resource for ${unknown.joinToString()}", null)
        }
    }

    private fun playSound(file: String) {
        if (!foreground || !soundAllowedBySystem()) return
        val soundId = soundIds[file] ?: return
        if (soundId !in loadedSoundIds) return
        // T7: only one sound voice at a time — a new sound stops the playing one.
        if (playingStreamId != 0) soundPool.stop(playingStreamId)
        playingStreamId = soundPool.play(soundId, 1f, 1f, 1, 0, 1f)
    }

    /** 11 §7.1: no sound in silent or vibrate ringer mode, nor during Do Not Disturb. */
    private fun soundAllowedBySystem(): Boolean {
        val audio = audioManager ?: return false
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return false
        val filter = notificationManager?.currentInterruptionFilter ?: NotificationManager.INTERRUPTION_FILTER_ALL
        return filter == NotificationManager.INTERRUPTION_FILTER_ALL ||
            filter == NotificationManager.INTERRUPTION_FILTER_UNKNOWN
    }

    // endregion

    // region Haptics

    private fun playHaptic(spec: Map<String, Any?>) {
        if (!foreground) return
        // 11 §7.1: ringer mode Silent = no vibration by user choice.
        if (audioManager?.ringerMode == AudioManager.RINGER_MODE_SILENT) return
        cancelPendingWaveform()

        val constant = (spec["constant"] as? String)?.let(::hapticConstant)
        if (constant != null) {
            // View-based constants follow the system "touch feedback" setting by themselves.
            activity.window?.decorView?.performHapticFeedback(constant)
        }

        val oneShot = spec["oneShot"] as? Map<*, *>
        if (oneShot != null) {
            oneShotEffect(oneShot)?.let(::vibrate)
        }

        val waveform = spec["waveform"] as? Map<*, *>
        if (waveform != null) {
            val effect = waveformEffect(waveform) ?: return
            val delayMs = if (constant != null) (spec["waveformDelayMs"] as? Number)?.toLong() ?: 0L else 0L
            if (delayMs > 0) {
                val task = Runnable {
                    pendingWaveform = null
                    if (foreground) vibrate(effect)
                }
                pendingWaveform = task
                mainHandler.postDelayed(task, delayMs)
            } else {
                vibrate(effect)
            }
        }
    }

    private fun cancelPendingWaveform() {
        pendingWaveform?.let(mainHandler::removeCallbacks)
        pendingWaveform = null
    }

    private fun hapticConstant(name: String): Int? = when (name) {
        "KEYBOARD_TAP" -> HapticFeedbackConstants.KEYBOARD_TAP
        "CLOCK_TICK" -> HapticFeedbackConstants.CLOCK_TICK
        "CONFIRM" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM
            else HapticFeedbackConstants.VIRTUAL_KEY
        "REJECT" ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.REJECT
            else HapticFeedbackConstants.LONG_PRESS
        else -> null
    }

    private fun oneShotEffect(spec: Map<*, *>): VibrationEffect? {
        val vib = vibrator ?: return null
        val duration = (spec["durationMs"] as? Number)?.toLong() ?: return null
        if (duration <= 0) return null
        val amplitude = if (vib.hasAmplitudeControl()) {
            ((spec["amplitude"] as? Number)?.toInt() ?: VibrationEffect.DEFAULT_AMPLITUDE).coerceIn(1, 255)
        } else {
            VibrationEffect.DEFAULT_AMPLITUDE
        }
        return VibrationEffect.createOneShot(duration, amplitude)
    }

    /**
     * `timings` / `amplitudes` segments (11 §2.1). Without amplitude control the
     * segments collapse into an off/on rhythm at full strength (11 §5.2).
     */
    private fun waveformEffect(spec: Map<*, *>): VibrationEffect? {
        val vib = vibrator ?: return null
        val timings = (spec["timings"] as? List<*>)?.map { (it as? Number)?.toLong() ?: 0L } ?: return null
        val amplitudes = (spec["amplitudes"] as? List<*>)?.map { (it as? Number)?.toInt() ?: 0 } ?: return null
        if (timings.isEmpty() || timings.size != amplitudes.size) return null
        if (timings.any { it < 0 } || timings.sum() == 0L) return null

        if (vib.hasAmplitudeControl()) {
            return VibrationEffect.createWaveform(
                timings.toLongArray(),
                amplitudes.map { it.coerceIn(0, 255) }.toIntArray(),
                NO_REPEAT,
            )
        }

        // On/off pattern starting with "off": merge neighbouring segments of the same state.
        val onOff = ArrayList<Long>(timings.size)
        var on = false
        var accumulated = 0L
        for (index in timings.indices) {
            val segmentOn = amplitudes[index] > 0
            if (segmentOn == on) {
                accumulated += timings[index]
            } else {
                onOff.add(accumulated)
                accumulated = timings[index]
                on = segmentOn
            }
        }
        onOff.add(accumulated)
        return VibrationEffect.createWaveform(onOff.toLongArray(), NO_REPEAT)
    }

    private fun vibrate(effect: VibrationEffect) {
        val vib = vibrator ?: return
        if (!vib.hasVibrator() || !touchFeedbackEnabled()) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Usage "touch": the system touch-feedback intensity applies (11 §4.1).
            vib.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_TOUCH))
        } else {
            vibrateLegacy(vib, effect)
        }
    }

    @Suppress("DEPRECATION") // Replaced by VibrationAttributes on API 33+ (branch above).
    private fun vibrateLegacy(vib: Vibrator, effect: VibrationEffect) {
        vib.vibrate(effect, soundAttributes)
    }

    /** System "Touch feedback" switch; waveforms are suppressed when it is off (11 §7.1). */
    @Suppress("DEPRECATION") // Still the switch behind Settings → Sound & vibration → Touch feedback.
    private fun touchFeedbackEnabled(): Boolean =
        Settings.System.getInt(activity.contentResolver, Settings.System.HAPTIC_FEEDBACK_ENABLED, 1) != 0

    // endregion

    private companion object {
        const val CHANNEL = "giftcard_waiter/feedback"
        const val MAX_STREAMS = 2
        const val NO_REPEAT = -1

        /** Binding file names (10 §2.5, 11 §6.1). */
        val SOUND_RESOURCES: Map<String, Int> = mapOf(
            "gcw_card_detected" to R.raw.gcw_card_detected,
            "gcw_success" to R.raw.gcw_success,
            "gcw_warning" to R.raw.gcw_warning,
            "gcw_error" to R.raw.gcw_error,
        )

        fun resolveVibrator(context: Context): Vibrator? =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(VibratorManager::class.java)?.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            }
    }
}
