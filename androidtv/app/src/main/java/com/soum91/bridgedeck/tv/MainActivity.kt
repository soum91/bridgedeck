package com.soum91.bridgedeck.tv

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startPresence()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(80, 52, 80, 52)
            setBackgroundColor(Color.rgb(8, 19, 26))
        }

        fun addText(text: String, size: Float, color: Int, bold: Boolean = false) {
            val view = TextView(this).apply {
                this.text = text
                textSize = size
                setTextColor(color)
                if (bold) setTypeface(null, Typeface.BOLD)
                setPadding(0, 0, 0, 18)
            }
            root.addView(view)
        }

        addText("BridgeDeck", 35f, Color.WHITE, true)
        addText("Your Android TV companion", 19f, Color.rgb(110, 215, 231))
        val installed = runCatching { packageManager.getPackageInfo(packageName, 0) }.getOrNull()
        val installedVersion = installed?.versionName ?: "Unknown"
        val installedBuild = installed?.let {
            (if (Build.VERSION.SDK_INT >= 28) it.longVersionCode else it.versionCode.toLong()).toString()
        } ?: "Unknown"
        addText("Installed version $installedVersion (build $installedBuild)", 14f, Color.LTGRAY)
        addText("This TV is visible to the BridgeDeck iPhone app when both devices can communicate over the local network.", 17f, Color.LTGRAY)
        addText("Device: ${Build.MODEL}   •   Android TV ${Build.VERSION.RELEASE}", 17f, Color.WHITE)
        addText("Discovery is available while the TV is running. For privileged controls, authorize ADB separately on the TV. This companion never opens ADB or runs shell commands.", 15f, Color.LTGRAY)

        val openDev = Button(this).apply {
            text = "Open Developer Options"
            setOnClickListener {
                try {
                    startActivity(Intent(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS))
                } catch (_: Exception) {
                    startActivity(Intent(Settings.ACTION_SETTINGS))
                }
            }
        }
        root.addView(openDev, LinearLayout.LayoutParams(380, ViewGroup.LayoutParams.WRAP_CONTENT))

        val restart = Button(this).apply {
            text = "Restart Companion Discovery"
            setOnClickListener {
                stopService(Intent(this@MainActivity, TVPresenceService::class.java))
                startPresence()
            }
        }
        root.addView(restart, LinearLayout.LayoutParams(380, ViewGroup.LayoutParams.WRAP_CONTENT))
        addText("ADB does not become available just because this app is installed. Android TV 12 may need initial PC/USB setup for TCP debugging.", 14f, Color.rgb(235, 189, 112))

        setContentView(root)
    }

    private fun startPresence() {
        val intent = Intent(this, TVPresenceService::class.java)
        if (Build.VERSION.SDK_INT >= 26) startForegroundService(intent)
        else startService(intent)
    }
}
