package com.applausestudios.ekadashi_calendar

import android.content.Context
import android.content.res.Configuration
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.util.Locale

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28,35])
class WidgetPreviewRegressionTest {
 private fun texts(view:View):List<TextView> = when(view) {
  is TextView -> listOf(view)
  is ViewGroup -> (0 until view.childCount).flatMap { texts(view.getChildAt(it)) }
  else -> emptyList()
 }
 @Test fun pickerPreviewsUseLocalizedLabelsWithoutInventedDates() {
  val context=ApplicationProvider.getApplicationContext<Context>()
  for(code in listOf("en","ta","hi","te")) {
   val configuration=Configuration(context.resources.configuration).apply { setLocale(Locale.forLanguageTag(code)) }
   val localized=context.createConfigurationContext(configuration)
   for((layout,string) in listOf(R.layout.preview_widget_next to R.string.widget_next_ekadashi,
    R.layout.preview_widget_today to R.string.widget_today_title,
    R.layout.preview_widget_upcoming to R.string.widget_upcoming_ekadashis)) {
    val view=LayoutInflater.from(localized).inflate(layout,null)
    assertEquals("Preview locale $code",listOf(localized.getString(string)),texts(view).map { it.text.toString() })
   }
  }
 }
 @Test fun smallPreviewFitsItsMinimumCellWithoutLetterByLetterWrapping() {
  val context=ApplicationProvider.getApplicationContext<Context>()
  for(code in listOf("en","ta","hi","te")) {
   val configuration=Configuration(context.resources.configuration).apply { setLocale(Locale.forLanguageTag(code)) }
   val localized=context.createConfigurationContext(configuration)
   val view=LayoutInflater.from(localized).inflate(R.layout.preview_widget_next,null)
   val width=(110*localized.resources.displayMetrics.density).toInt()
   view.measure(View.MeasureSpec.makeMeasureSpec(width,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED))
   view.layout(0,0,width,view.measuredHeight)
   val title=texts(view).first()
   assertTrue("Compact preview height $code: ${view.measuredHeight}",view.measuredHeight<=width)
   assertTrue("Bounded title lines $code",title.maxLines<=2)
   assertTrue("Readable title width $code",title.measuredWidth>=width/2)
  }
 }
}
