package com.applausestudios.ekadashi_calendar.widget.data
import android.content.Context
import android.content.res.Configuration
import com.applausestudios.ekadashi_calendar.R
import java.util.Locale
object WidgetLocalization {
 fun locale(context:Context):String = context.getSharedPreferences("FlutterSharedPreferences",Context.MODE_PRIVATE).getString("flutter.language_code",null)?.takeIf { it in listOf("en","hi","ta","te","gu","bn") } ?: "en"
 fun strings(context:Context,code:String=locale(context)):Map<String,String> {
  val config=Configuration(context.resources.configuration);config.setLocale(Locale.forLanguageTag(code))
  val localized=context.createConfigurationContext(config)
  return mapOf(
   "widget.title" to localized.getString(R.string.widget_title),
   "widget.next_ekadashi" to localized.getString(R.string.widget_next_ekadashi),
   "widget.fasting_active" to localized.getString(R.string.widget_fasting_active),
   "widget.parana_available" to localized.getString(R.string.widget_parana_available),
   "widget.parana_completed" to localized.getString(R.string.widget_parana_completed),
   "widget.open_app_to_refresh" to localized.getString(R.string.widget_open_app_to_refresh),
   "widget.fasting_starts" to localized.getString(R.string.widget_fasting_starts),
   "widget.parana_window" to localized.getString(R.string.widget_parana_window),
   "widget.upcoming_ekadashis" to localized.getString(R.string.widget_upcoming_ekadashis),
   "widget.today" to localized.getString(R.string.widget_today),
   "widget.today_title" to localized.getString(R.string.widget_today_title),
   "widget.parana_in" to localized.getString(R.string.widget_parana_in),
   "widget.parana_ends" to localized.getString(R.string.widget_parana_ends),
   "widget.starts_in" to localized.getString(R.string.widget_starts_in),
   "widget.notice" to localized.getString(R.string.widget_notice),
   "widget.now" to localized.getString(R.string.widget_now),
   "widget.day_unit" to localized.getString(R.string.widget_day_unit),
   "widget.hour_unit" to localized.getString(R.string.widget_hour_unit),
   "widget.minute_unit" to localized.getString(R.string.widget_minute_unit),
   "widget.no_ekadashi" to localized.getString(R.string.widget_no_ekadashi))
 }
 fun term(context:Context,code:String,key:String,fallback:String):String {
  val ids=mapOf("paksha_krishna" to R.string.widget_paksha_krishna,
"paksha_shukla" to R.string.widget_paksha_shukla,
"lunar_month_adhika" to R.string.widget_lunar_month_adhika,
"lunar_month_ashadha" to R.string.widget_lunar_month_ashadha,
"lunar_month_ashwin" to R.string.widget_lunar_month_ashwin,
"lunar_month_bhadrapada" to R.string.widget_lunar_month_bhadrapada,
"lunar_month_chaitra" to R.string.widget_lunar_month_chaitra,
"lunar_month_jyeshtha" to R.string.widget_lunar_month_jyeshtha,
"lunar_month_kartik" to R.string.widget_lunar_month_kartik,
"lunar_month_magha" to R.string.widget_lunar_month_magha,
"lunar_month_margashirsha" to R.string.widget_lunar_month_margashirsha,
"lunar_month_pausha" to R.string.widget_lunar_month_pausha,
"lunar_month_phalguna" to R.string.widget_lunar_month_phalguna,
"lunar_month_shravana" to R.string.widget_lunar_month_shravana,
"lunar_month_vaishakha" to R.string.widget_lunar_month_vaishakha)
  val id=ids[key] ?: return fallback
  val config=Configuration(context.resources.configuration);config.setLocale(Locale.forLanguageTag(code))
  return context.createConfigurationContext(config).getString(id)
 }

}
