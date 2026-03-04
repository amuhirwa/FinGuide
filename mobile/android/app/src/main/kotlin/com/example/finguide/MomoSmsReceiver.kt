package com.example.finguide

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.telephony.SmsMessage
import androidx.core.app.NotificationCompat

/**
 * MomoSmsReceiver
 * ===============
 * Native Android BroadcastReceiver that fires whenever an SMS is received,
 * even when the Flutter engine is not running (app killed / backgrounded).
 *
 * For each MoMo-matching SMS that contains a significant amount (≥ 40 000 RWF)
 * it shows an immediate local notification.  The SMS itself stays in the
 * device inbox, so the next time FinGuide is opened SmsService.syncNewMessages()
 * will find it, forward it to the backend, and display the AI-personalised nudge.
 */
class MomoSmsReceiver : BroadcastReceiver() {

    companion object {
        private const val CHANNEL_ID   = "finguide_nudges"
        private const val CHANNEL_NAME = "FinGuide Smart Nudges"
        private const val CHANNEL_DESC = "Personalized saving and investment reminders"
        private const val SIGNIFICANT_THRESHOLD = 40_000.0

        // ── Mirrors sms_service.dart filter lists ──────────────────────────
        private val MOMO_SENDERS = listOf(
            "m-money", "momo", "mtn", "mobilemoney", "8199", "162", "164", "165"
        )
        private val MOMO_KEYWORDS = listOf(
            "rwf", "balance:", "transferred to", "received", "payment of",
            "transaction of", "ft id", "mokash"
        )
        private val INCOME_KEYWORDS = listOf(
            "received", "you have received", "has been deposited", "cash in"
        )

        fun isMomo(address: String, body: String): Boolean {
            val a = address.lowercase()
            val b = body.lowercase()
            return MOMO_SENDERS.any { a.contains(it) } || MOMO_KEYWORDS.any { b.contains(it) }
        }

        fun extractAmount(body: String): Double? {
            val match = Regex("""([\d,]+)\s*RWF""", RegexOption.IGNORE_CASE).find(body)
                ?: return null
            return match.groupValues[1].replace(",", "").toDoubleOrNull()
        }

        fun isIncome(body: String): Boolean {
            val lower = body.lowercase()
            return INCOME_KEYWORDS.any { lower.contains(it) }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "android.provider.Telephony.SMS_RECEIVED") return

        val bundle = intent.extras ?: return
        @Suppress("UNCHECKED_CAST")
        val pdus = bundle["pdus"] as? Array<Any> ?: return
        val format = bundle.getString("format")

        val messages = pdus.mapNotNull { pdu ->
            runCatching {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                    SmsMessage.createFromPdu(pdu as ByteArray, format)
                else
                    @Suppress("DEPRECATION") SmsMessage.createFromPdu(pdu as ByteArray)
            }.getOrNull()
        }

        for (sms in messages) {
            val address = sms.originatingAddress ?: ""
            val body    = sms.messageBody    ?: ""
            if (!isMomo(address, body)) continue

            val amount = extractAmount(body) ?: continue
            if (amount < SIGNIFICANT_THRESHOLD) continue

            val isIncomeMsg = isIncome(body)
            val fmt = when {
                amount >= 1_000_000.0 -> "${"%.1f".format(amount / 1_000_000)}M"
                else                  -> "${(amount / 1_000).toInt()}k"
            }

            val title = if (isIncomeMsg) "💰 RWF $fmt received!" else "📊 RWF $fmt spent"
            val text  = if (isIncomeMsg)
                "Open FinGuide to get your personalised savings nudge."
            else
                "Open FinGuide to check your safe-to-spend balance."

            showNotification(context, title, text)
        }
    }

    private fun showNotification(context: Context, title: String, text: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager

        // Create channel on Android 8+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH
            ).apply { description = CHANNEL_DESC }
            manager.createNotificationChannel(channel)
        }

        // Tap-to-open: brings FinGuide to the foreground
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP }

        val pendingFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        else PendingIntent.FLAG_UPDATE_CURRENT

        val pendingIntent = if (launchIntent != null)
            PendingIntent.getActivity(context, 0, launchIntent, pendingFlags)
        else null

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .apply { if (pendingIntent != null) setContentIntent(pendingIntent) }
            .build()

        manager.notify(System.currentTimeMillis().toInt(), notification)
    }
}
