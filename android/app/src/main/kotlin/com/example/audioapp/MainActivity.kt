package com.example.audioapp

import android.Manifest
import android.annotation.TargetApi
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val callbackExecutor = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Tells the app which speech recognizers this phone can use, so voice
        // input can prefer on-device (offline) recognition. The speech_to_text
        // plugin can create an on-device recognizer but cannot say whether the
        // English model is actually installed; only checkRecognitionSupport
        // (Android 13+) can.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "audiolearner/speech_capabilities")
            .setMethodCallHandler { call, result ->
                if (call.method == "query") {
                    queryCapabilities(result)
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Answers with:
     *  - sdk: Android API level
     *  - network: a default (usually Google, network-backed) recognizer exists
     *  - onDevice: an on-device recognizer exists (Android 12+)
     *  - installed / pending: on-device languages installed / downloading
     *    (Android 13+ only, null when unknown)
     */
    private fun queryCapabilities(result: MethodChannel.Result) {
        val caps = hashMapOf<String, Any?>(
            "sdk" to Build.VERSION.SDK_INT,
            "network" to SpeechRecognizer.isRecognitionAvailable(this),
            "onDevice" to false,
            "installed" to null,
            "pending" to null,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            caps["onDevice"] = SpeechRecognizer.isOnDeviceRecognitionAvailable(this)
        }
        val canListLanguages = Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            caps["onDevice"] == true &&
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
        if (!canListLanguages) {
            result.success(caps)
            return
        }
        queryInstalledLanguages(caps, result)
    }

    @TargetApi(Build.VERSION_CODES.TIRAMISU)
    private fun queryInstalledLanguages(caps: HashMap<String, Any?>, result: MethodChannel.Result) {
        // Must be created and destroyed on the main thread.
        val recognizer = SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
        var answered = false
        fun answer() {
            if (answered) return
            answered = true
            recognizer.destroy()
            result.success(caps)
        }
        // Some devices never call back; answer without the language list then.
        val timeout = Runnable { answer() }
        mainHandler.postDelayed(timeout, 3000)
        recognizer.checkRecognitionSupport(
            Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH),
            callbackExecutor,
            object : RecognitionSupportCallback {
                override fun onSupportResult(support: RecognitionSupport) {
                    mainHandler.post {
                        mainHandler.removeCallbacks(timeout)
                        caps["installed"] = support.installedOnDeviceLanguages
                        caps["pending"] = support.pendingOnDeviceLanguages
                        answer()
                    }
                }

                override fun onError(error: Int) {
                    mainHandler.post {
                        mainHandler.removeCallbacks(timeout)
                        answer()
                    }
                }
            },
        )
    }
}
