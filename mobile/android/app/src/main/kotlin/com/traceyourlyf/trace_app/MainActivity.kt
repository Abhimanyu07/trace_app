package com.traceyourlyf.trace_app

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.traceyourlyf/usage_stats"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> {
                    result.success(hasUsageStatsPermission())
                }
                "requestPermission" -> {
                    val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(intent)
                    result.success(true)
                }
                "getUsageToday" -> {
                    if (!hasUsageStatsPermission()) {
                        result.success(mapOf("error" to "no_permission", "apps" to listOf<Map<String, Any>>()))
                        return@setMethodCallHandler
                    }
                    val stats = getUsageStatsToday()
                    result.success(mapOf("apps" to stats))
                }
                "getUsageForDate" -> {
                    if (!hasUsageStatsPermission()) {
                        result.success(mapOf("error" to "no_permission", "apps" to listOf<Map<String, Any>>()))
                        return@setMethodCallHandler
                    }
                    val year = call.argument<Int>("year") ?: 0
                    val month = call.argument<Int>("month") ?: 0
                    val day = call.argument<Int>("day") ?: 0
                    val stats = getUsageStatsForDate(year, month, day)
                    result.success(mapOf("apps" to stats))
                }
                "getUsageWeekly" -> {
                    if (!hasUsageStatsPermission()) {
                        result.success(mapOf("error" to "no_permission", "days" to listOf<Map<String, Any>>()))
                        return@setMethodCallHandler
                    }
                    val weekly = getUsageStatsWeekly()
                    result.success(mapOf("days" to weekly))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun getUsageStatsToday(): List<Map<String, Any>> {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val startTime = cal.timeInMillis
        val endTime = System.currentTimeMillis()

        return queryUsageStats(startTime, endTime)
    }

    private fun getUsageStatsForDate(year: Int, month: Int, day: Int): List<Map<String, Any>> {
        val cal = Calendar.getInstance()
        cal.set(year, month - 1, day, 0, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        val startTime = cal.timeInMillis

        cal.add(Calendar.DAY_OF_YEAR, 1)
        val endTime = cal.timeInMillis

        return queryUsageStats(startTime, endTime)
    }

    private fun getUsageStatsWeekly(): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val cal = Calendar.getInstance()

        // Go back to Monday of current week
        val dayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        val daysFromMonday = if (dayOfWeek == Calendar.SUNDAY) 6 else dayOfWeek - Calendar.MONDAY
        cal.add(Calendar.DAY_OF_YEAR, -daysFromMonday)
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)

        for (i in 0..6) {
            val dayStart = cal.timeInMillis
            cal.add(Calendar.DAY_OF_YEAR, 1)
            val dayEnd = cal.timeInMillis

            if (dayStart > System.currentTimeMillis()) {
                // Future days - empty
                result.add(mapOf(
                    "date" to (dayStart / 1000),
                    "total_seconds" to 0,
                    "apps" to listOf<Map<String, Any>>()
                ))
            } else {
                val apps = queryUsageStats(dayStart, minOf(dayEnd, System.currentTimeMillis()))
                val totalSeconds = apps.sumOf { (it["total_seconds"] as? Long) ?: 0L }
                result.add(mapOf(
                    "date" to (dayStart / 1000),
                    "total_seconds" to totalSeconds,
                    "apps" to apps
                ))
            }
        }
        return result
    }

    private fun queryUsageStats(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)

        if (stats == null || stats.isEmpty()) return emptyList()

        val pm = packageManager
        return stats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .mapNotNull { stat ->
                try {
                    val appInfo = pm.getApplicationInfo(stat.packageName, 0)
                    val appName = pm.getApplicationLabel(appInfo).toString()
                    val totalSeconds = stat.totalTimeInForeground / 1000

                    if (totalSeconds < 1) return@mapNotNull null

                    mapOf(
                        "package_name" to stat.packageName,
                        "app_name" to appName,
                        "total_seconds" to totalSeconds,
                        "last_used" to (stat.lastTimeUsed / 1000)
                    )
                } catch (e: PackageManager.NameNotFoundException) {
                    null
                }
            }
    }
}
