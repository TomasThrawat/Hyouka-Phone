package com.hyouka.hyouka_phone

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "hyouka_phone/calls"
    private val callPermissionRequestCode = 701

    private var pendingNumber: String? = null
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "placeCall" -> {
                    val number = call.arguments as? String
                    if (number.isNullOrBlank()) {
                        result.error("INVALID_NUMBER", "Phone number is empty.", null)
                    } else {
                        placeCall(number, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun placeCall(number: String, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.CALL_PHONE) != PackageManager.PERMISSION_GRANTED) {
            pendingNumber = number
            pendingResult = result
            requestPermissions(arrayOf(Manifest.permission.CALL_PHONE), callPermissionRequestCode)
            return
        }
        launchCall(number, result)
    }

    private fun launchCall(number: String, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_CALL).apply {
                data = Uri.parse("tel:${Uri.encode(number)}")
            }
            startActivity(intent)
            result.success(null)
        } catch (error: Exception) {
            result.error("CALL_FAILED", error.message ?: "Unable to start the call.", null)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != callPermissionRequestCode) return

        val result = pendingResult
        val number = pendingNumber
        pendingResult = null
        pendingNumber = null

        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && result != null && number != null) {
            launchCall(number, result)
        } else {
            result?.error("CALL_PERMISSION_DENIED", "Phone call permission was denied.", null)
        }
    }
}
