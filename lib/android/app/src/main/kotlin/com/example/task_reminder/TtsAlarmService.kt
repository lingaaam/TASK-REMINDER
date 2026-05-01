package com.example.task_reminder

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import androidx.core.app.NotificationCompat
import java.util.Locale

class TtsAlarmService : Service(), TextToSpeech.OnInitListener {

    private lateinit var tts: TextToSpeech
    private var taskTitle = ""
    private val handler = Handler(Looper.getMainLooper())

    companion object {
        const val CHANNEL_ID = "task_alarm_channel"
        const val NOTIF_ID = 9999
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
        tts = TextToSpeech(this, this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        taskTitle = intent?.getStringExtra("taskTitle") ?: "Reminder"
        startForeground(NOTIF_ID, buildNotif(taskTitle))
        triggerAlarm()
        triggerVibration()
        return START_NOT_STICKY
    }

    override fun onInit(status: Int) {
        if (status != TextToSpeech.SUCCESS) { stopSelf(); return }

        val result = tts.setLanguage(Locale("ta", "IN"))
        if (result == TextToSpeech.LANG_MISSING_DATA || result == TextToSpeech.LANG_NOT_SUPPORTED) {
            tts.setLanguage(Locale.ENGLISH)
        }
        tts.setSpeechRate(0.85f)
        tts.setPitch(1.05f)

        // 3 நொடி alarm ஒலிக்கு பிறகு heading இரண்டு முறை சொல்லும்
        handler.postDelayed({ speakTwice() }, 3000)
    }

    private fun speakTwice() {
        // முதல் முறை
        tts.speak(taskTitle, TextToSpeech.QUEUE_FLUSH, null, "first")

        tts.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(u: String?) {}
            override fun onDone(u: String?) {
                if (u == "first") {
                    // 1 நொடி இடைவெளி பிறகு இரண்டாம் முறை
                    handler.postDelayed({
                        tts.speak(taskTitle, TextToSpeech.QUEUE_FLUSH, null, "second")
                    }, 1000)
                } else if (u == "second") {
                    handler.postDelayed({ stopSelf() }, 500)
                }
            }
            override fun onError(u: String?) { stopSelf() }
        })
    }

    private fun triggerAlarm() {
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            ringtone.play()
            handler.postDelayed({ try { ringtone.stop() } catch (_: Exception) {} }, 2500)
        } catch (_: Exception) {}
    }

    private fun triggerVibration() {
        try {
            val pattern = longArrayOf(0, 500, 300, 500, 300, 500)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (getSystemService(VIBRATOR_MANAGER_SERVICE) as VibratorManager)
                    .defaultVibrator.vibrate(VibrationEffect.createWaveform(pattern, -1))
            } else {
                @Suppress("DEPRECATION")
                val v = getSystemService(VIBRATOR_SERVICE) as Vibrator
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    v.vibrate(VibrationEffect.createWaveform(pattern, -1))
                } else {
                    @Suppress("DEPRECATION")
                    v.vibrate(pattern, -1)
                }
            }
        } catch (_: Exception) {}
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(CHANNEL_ID, "Task Alarm", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(null, null)
            (getSystemService(NotificationManager::class.java)).createNotificationChannel(ch)
        }
    }

    private fun buildNotif(title: String): Notification =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("⏰ Task Reminder")
            .setContentText(title)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true)
            .build()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        if (::tts.isInitialized) { tts.stop(); tts.shutdown() }
        super.onDestroy()
    }
}
