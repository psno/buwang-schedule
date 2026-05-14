package com.sno.buwang_schedule

import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.provider.AlarmClock
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ALARM_CHANNEL = "com.sno.buwang_schedule/alarm"
    private val CALENDAR_CHANNEL = "com.sno.buwang_schedule/calendar"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ─── 闹钟通道 ───
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 0
                    val minute = call.argument<Int>("minute") ?: 0
                    val label = call.argument<String>("label") ?: "不忘课表"
                    val skipUi = call.argument<Boolean>("skipUi") ?: true
                    result.success(setSystemAlarm(hour, minute, label, skipUi))
                }
                else -> result.notImplemented()
            }
        }

        // ─── 日历通道（原生 ContentResolver） ───
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CALENDAR_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listCalendars" -> {
                    result.success(listCalendars())
                }
                "deleteEventsByKeyword" -> {
                    val keyword = call.argument<String>("keyword") ?: "课表"
                    result.success(deleteEventsByKeyword(keyword))
                }
                "deleteAllEventsInCalendar" -> {
                    val calendarId = call.argument<Int>("calendarId") ?: -1
                    result.success(deleteAllEventsInCalendar(calendarId.toLong()))
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 列出所有日历账户
     * 返回 List<Map>，每个 map 有 id, name, accountName, accountType
     */
    private fun listCalendars(): List<Map<String, Any?>> {
        val calendars = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CalendarContract.Calendars._ID,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
            CalendarContract.Calendars.ACCOUNT_NAME,
            CalendarContract.Calendars.ACCOUNT_TYPE,
        )

        try {
            contentResolver.query(
                CalendarContract.Calendars.CONTENT_URI,
                projection,
                null, null, null
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(CalendarContract.Calendars._ID)
                val nameIdx = cursor.getColumnIndex(CalendarContract.Calendars.CALENDAR_DISPLAY_NAME)
                val accountIdx = cursor.getColumnIndex(CalendarContract.Calendars.ACCOUNT_NAME)
                val typeIdx = cursor.getColumnIndex(CalendarContract.Calendars.ACCOUNT_TYPE)

                while (cursor.moveToNext()) {
                    calendars.add(mapOf(
                        "id" to cursor.getLong(idIdx),
                        "name" to (cursor.getString(nameIdx) ?: ""),
                        "accountName" to (cursor.getString(accountIdx) ?: ""),
                        "accountType" to (cursor.getString(typeIdx) ?: ""),
                    ))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("CalendarNative", "listCalendars error: ${e.message}")
        }
        return calendars
    }

    /**
     * 删除所有日历中标题或描述包含关键词的事件
     * 返回删除数量
     */
    private fun deleteEventsByKeyword(keyword: String): Map<String, Any> {
        var totalDeleted = 0
        val log = mutableListOf<String>()

        try {
            // 查询所有事件
            val projection = arrayOf(
                CalendarContract.Events._ID,
                CalendarContract.Events.TITLE,
                CalendarContract.Events.DESCRIPTION,
                CalendarContract.Events.CALENDAR_ID,
                CalendarContract.Events.CALENDAR_DISPLAY_NAME,
            )

            contentResolver.query(
                CalendarContract.Events.CONTENT_URI,
                projection,
                "${CalendarContract.Events.TITLE} LIKE ? OR ${CalendarContract.Events.DESCRIPTION} LIKE ?",
                arrayOf("%$keyword%", "%$keyword%"),
                null
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndex(CalendarContract.Events._ID)
                val titleIdx = cursor.getColumnIndex(CalendarContract.Events.TITLE)
                val calNameIdx = cursor.getColumnIndex(CalendarContract.Events.CALENDAR_DISPLAY_NAME)

                log.add("查询到 ${cursor.count} 个含「$keyword」的事件")

                while (cursor.moveToNext()) {
                    val eventId = cursor.getLong(idIdx)
                    val title = cursor.getString(titleIdx) ?: "(无标题)"
                    val calName = cursor.getString(calNameIdx) ?: "(未知日历)"

                    try {
                        val uri = ContentUris.withAppendedId(CalendarContract.Events.CONTENT_URI, eventId)
                        val rowsDeleted = contentResolver.delete(uri, null, null)
                        if (rowsDeleted > 0) {
                            totalDeleted++
                            log.add("✅ 已删: $title (日历: $calName)")
                        } else {
                            log.add("❌ 未删: $title (日历: $calName)")
                        }
                    } catch (e: Exception) {
                        log.add("❌ 异常: $title → ${e.message}")
                    }
                }
            } ?: log.add("查询返回 null，可能无日历权限")

        } catch (e: Exception) {
            log.add("查询异常: ${e.message}")
        }

        log.add(0, "通过原生 ContentResolver 删除含「$keyword」的事件")
        log.add("共删除 $totalDeleted 个事件")

        return mapOf(
            "deleted" to totalDeleted,
            "log" to log.joinToString("\n"),
        )
    }

    /**
     * 删除指定日历下的所有事件
     */
    private fun deleteAllEventsInCalendar(calendarId: Long): Map<String, Any> {
        var totalDeleted = 0
        val log = mutableListOf<String>()

        try {
            val uri = CalendarContract.Events.CONTENT_URI
            val rowsDeleted = contentResolver.delete(
                uri,
                "${CalendarContract.Events.CALENDAR_ID} = ?",
                arrayOf(calendarId.toString())
            )
            totalDeleted = rowsDeleted
            log.add("删除日历 $calendarId 下的 $rowsDeleted 个事件")
        } catch (e: Exception) {
            log.add("删除异常: ${e.message}")
        }

        return mapOf(
            "deleted" to totalDeleted,
            "log" to log.joinToString("\n"),
        )
    }

    private fun setSystemAlarm(hour: Int, minute: Int, label: String, skipUi: Boolean): Boolean {
        return try {
            val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                putExtra(AlarmClock.EXTRA_HOUR, hour)
                putExtra(AlarmClock.EXTRA_MINUTES, minute)
                putExtra(AlarmClock.EXTRA_MESSAGE, label)
                putExtra(AlarmClock.EXTRA_VIBRATE, true)
                putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }

            val clockPackages = listOf(
                "com.google.android.deskclock",
                "com.android.deskclock",
                "com.coloros.alarmclock",
                "com.bbk.alarmclock",
                "com.xiaomi.clock",
                "com.sec.android.app.clockpackage",
                "com.huawei.deskclock",
            )

            for (pkg in clockPackages) {
                try {
                    intent.setPackage(pkg)
                    startActivity(intent)
                    return true
                } catch (_: Exception) {
                }
            }

            intent.setPackage(null)
            try {
                startActivity(intent)
                return true
            } catch (_: Exception) {
                false
            }
        } catch (e: Exception) {
            false
        }
    }
}
