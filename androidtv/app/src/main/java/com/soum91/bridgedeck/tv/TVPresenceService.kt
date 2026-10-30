package com.soum91.bridgedeck.tv

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.IBinder
import org.json.JSONObject
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.concurrent.thread

/**
 * Discovery and nonsensitive status only.
 *
 * There is intentionally NO remote shell, install, uninstall, or disable endpoint:
 * ADB must be authorized separately by Android. Port 47719 never accepts commands.
 */
class TVPresenceService : Service() {
    private val alive = AtomicBoolean(false)
    private var server: ServerSocket? = null
    private var registration: NsdManager.RegistrationListener? = null
    private var nsd: NsdManager? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createNotification()
        startForeground(77, Notification.Builder(this, "bridgedeck")
            .setContentTitle("BridgeDeck TV")
            .setContentText("Ready for iPhone discovery")
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentIntent(PendingIntent.getActivity(
                this, 0, Intent(this, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT))
            .build())
        startAdvertiser()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    private fun createNotification() {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(NotificationChannel(
            "bridgedeck", "BridgeDeck connection", NotificationManager.IMPORTANCE_LOW))
    }

    private fun startAdvertiser() {
        if (!alive.compareAndSet(false, true)) return
        thread(name = "BridgeDeck-Status", isDaemon = true) {
            try {
                ServerSocket(47719).use { listener ->
                    server = listener
                    registerDiscovery(listener.localPort)
                    while (alive.get()) {
                        val client = listener.accept()
                        serveStatus(client)
                    }
                }
            } catch (_: Exception) {
                // Discovery remains optional. Reopening the app restarts the service.
            }
        }
    }

    private fun registerDiscovery(port: Int) {
        nsd = getSystemService(NSD_SERVICE) as NsdManager
        val info = NsdServiceInfo().apply {
            serviceName = "BridgeDeck ${Build.MODEL}"
            serviceType = "_bridgedeck._tcp."
            setPort(port)
        }
        val callback = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(serviceInfo: NsdServiceInfo) = Unit
            override fun onRegistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit
            override fun onServiceUnregistered(serviceInfo: NsdServiceInfo) = Unit
            override fun onUnregistrationFailed(serviceInfo: NsdServiceInfo, errorCode: Int) = Unit
        }
        registration = callback
        try {
            nsd?.registerService(info, NsdManager.PROTOCOL_DNS_SD, callback)
        } catch (_: Exception) { }
    }

    private fun serveStatus(socket: Socket) {
        socket.use { client ->
            client.soTimeout = 2000
            try {
                val reader = client.getInputStream().bufferedReader()
                val request = reader.readLine() ?: return
                // Ignore any request body, headers, and commands.
                val body = if (request == "GET /status HTTP/1.1" ||
                    request == "GET /status HTTP/1.0") {
                    JSONObject().put("app", "BridgeDeck TV")
                        .put("model", Build.MODEL)
                        .put("android", Build.VERSION.RELEASE)
                        .put("version", "0.1.0").toString()
                } else "{}"
                val status = if (request.startsWith("GET /status ")) "200 OK" else "404 Not Found"
                val bytes = body.toByteArray(Charsets.UTF_8)
                client.getOutputStream().write(
                    "HTTP/1.1 $status\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n"
                        .toByteArray(Charsets.US_ASCII))
                client.getOutputStream().write(bytes)
                client.getOutputStream().flush()
            } catch (_: Exception) { }
        }
    }

    override fun onDestroy() {
        alive.set(false)
        try { server?.close() } catch (_: Exception) { }
        val manager = nsd
        val listener = registration
        if (manager != null && listener != null) {
            try { manager.unregisterService(listener) } catch (_: Exception) { }
        }
        super.onDestroy()
    }
}
