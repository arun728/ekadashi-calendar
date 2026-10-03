package com.applausestudios.ekadashi_calendar.widget.ui

/**
 * ============================================================================
 * JETPACK GLANCE DECLARATIVE WIDGET IMPLEMENTATION (Module 13 Specification)
 * ============================================================================
 *
 * For projects adopting androidx.glance:glance-appwidget, this file provides the
 * idiomatic Glance declarative UI components matching the 3 widget form factors.
 *
 * Prerequisites in build.gradle.kts:
 *   implementation("androidx.glance:glance-appwidget:1.1.0")
 *   implementation("androidx.glance:glance-material3:1.1.0")
 *
 * Sample Jetpack Glance Architecture:
 *
 * class EkadashiGlanceWidget : GlanceAppWidget() {
 *     override val sizeMode = SizeMode.Responsive(
 *         setOf(
 *             DpSize(140.dp, 110.dp), // Small (2x2)
 *             DpSize(260.dp, 110.dp), // Medium (4x2)
 *             DpSize(260.dp, 220.dp)  // Large (4x4)
 *         )
 *     )
 *
 *     override suspend fun provideGlance(context: Context, id: GlanceId) {
 *         val storage = WidgetStorage.getInstance(context)
 *         val result = storage.loadPayload()
 *         val payload = result.payload
 *         val canDisplay = result.status.canDisplay
 *
 *         provideContent {
 *             GlanceTheme {
 *                 val size = LocalSize.current
 *                 when {
 *                     size.height >= 200.dp -> LargeGlanceView(payload, canDisplay)
 *                     size.width >= 220.dp -> MediumGlanceView(payload, canDisplay)
 *                     else -> SmallGlanceView(payload, canDisplay)
 *                 }
 *             }
 *         }
 *     }
 * }
 *
 * @Composable
 * fun SmallGlanceView(payload: WidgetPayload, canDisplay: Boolean) {
 *     val next = payload.nextEkadashi
 *     Column(
 *         modifier = GlanceModifier
 *             .fillMaxSize()
 *             .background(GlanceTheme.colors.surface)
 *             .clickable(actionStartActivity(WidgetDeepLinks.createIntent(LocalContext.current, WidgetDeepLinks.buildDashboardUri())))
 *             .padding(12.dp)
 *     ) {
 *         Row(verticalAlignment = Alignment.CenterVertically) {
 *             Text("🕉️", style = TextStyle(fontSize = 14.sp))
 *             Spacer(GlanceModifier.width(4.dp))
 *             Text(
 *                 text = payload.localized("widget.next_ekadashi", "NEXT EKADASHI").uppercase(),
 *                 style = TextStyle(
 *                     color = ColorProvider(day = Color.White, night = Color.White),
 *                     fontWeight = FontWeight.Bold,
 *                     fontSize = 10.sp
 *                 )
 *             )
 *         }
 *         Spacer(GlanceModifier.defaultWeight())
 *         Text(
 *             text = next?.localizedName ?: "Ekadashi Calendar",
 *             style = TextStyle(
 *                 fontWeight = FontWeight.Bold,
 *                 fontSize = 15.sp,
 *                 color = GlanceTheme.colors.onSurface
 *             ),
 *             maxLines = 2
 *         )
 *         Text(
 *             text = "${next?.localizedDate ?: ""} • ${next?.paksha ?: ""}",
 *             style = TextStyle(fontSize = 11.sp, color = GlanceTheme.colors.secondary)
 *         )
 *     }
 * }
 *
 * @Composable
 * fun MediumGlanceView(payload: WidgetPayload, canDisplay: Boolean) {
 *     val next = payload.nextEkadashi
 *     Row(
 *         modifier = GlanceModifier
 *             .fillMaxSize()
 *             .background(GlanceTheme.colors.surface)
 *             .clickable(actionStartActivity(WidgetDeepLinks.createIntent(LocalContext.current, WidgetDeepLinks.buildTodayUri())))
 *             .padding(14.dp)
 *     ) {
 *         Column(modifier = GlanceModifier.defaultWeight()) {
 *             Text("🕉️ " + (next?.localizedName ?: "Ekadashi"), style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 16.sp))
 *             Text("${next?.localizedDate ?: ""} • ${next?.paksha ?: ""}", style = TextStyle(fontSize = 12.sp, color = GlanceTheme.colors.secondary))
 *             Spacer(GlanceModifier.defaultWeight())
 *             Text("📍 ${payload.metadata.locationName}", style = TextStyle(fontSize = 10.sp, color = GlanceTheme.colors.secondary))
 *         }
 *         Column(modifier = GlanceModifier.defaultWeight()) {
 *             Text("FASTING: " + (next?.fastingStartUTC?.substring(11, 16) ?: "--"), style = TextStyle(fontSize = 11.sp))
 *             Text("PARANA: " + (next?.paranaStartUTC?.substring(11, 16) ?: "--"), style = TextStyle(fontSize = 11.sp))
 *         }
 *     }
 * }
 *
 * @Composable
 * fun LargeGlanceView(payload: WidgetPayload, canDisplay: Boolean) {
 *     Column(
 *         modifier = GlanceModifier
 *             .fillMaxSize()
 *             .background(GlanceTheme.colors.surface)
 *             .padding(14.dp)
 *     ) {
 *         MediumGlanceView(payload, canDisplay)
 *         Spacer(GlanceModifier.height(8.dp))
 *         Text("UPCOMING", style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 11.sp))
 *         payload.upcomingEkadashis.take(3).forEach { item ->
 *             Text("• ${item.localizedName} (${item.localizedDate})", style = TextStyle(fontSize = 12.sp))
 *         }
 *     }
 * }
 * ============================================================================
 * MODULE 13 — COMPACT PREVIEW COMPONENTS (Jetpack Compose / Glance Specification)
 * ============================================================================
 *
 * @Composable
 * fun CompactTodayEkadashiPreview(modifier: GlanceModifier = GlanceModifier) {
 *     Box(
 *         modifier = modifier
 *             .fillMaxWidth()
 *             .cornerRadius(16.dp)
 *             .background(Color(0xFF011820))
 *     ) {
 *         // Background Banner Image Layer
 *         Image(
 *             provider = ImageProvider(R.drawable.widget_banner_bg),
 *             contentDescription = null,
 *             modifier = GlanceModifier.fillMaxSize(),
 *             contentScale = ContentScale.Crop
 *         )
 *         // Translucent Dark Overlay for readability
 *         Box(modifier = GlanceModifier.fillMaxSize().background(Color(0xB2000E14))) {}
 *         // Content Row
 *         Row(
 *             modifier = GlanceModifier
 *                 .fillMaxWidth()
 *                 .padding(horizontal = 16.dp, vertical = 16.dp),
 *             verticalAlignment = Alignment.CenterVertically
 *         ) {
 *             Image(
 *                 provider = ImageProvider(R.drawable.widget_lotus_deity),
 *                 contentDescription = null,
 *                 modifier = GlanceModifier.size(52.dp).cornerRadius(10.dp),
 *                 contentScale = ContentScale.Fit
 *             )
 *             Spacer(GlanceModifier.width(14.dp))
 *             Text(
 *                 text = "EKADASHI TODAY",
 *                 style = TextStyle(
 *                     color = ColorProvider(day = Color.White, night = Color.White),
 *                     fontWeight = FontWeight.Bold,
 *                     fontSize = 20.sp
 *                 )
 *             )
 *         }
 *     }
 * }
 *
 * @Composable
 * fun CompactNextEkadashiPreview(modifier: GlanceModifier = GlanceModifier) {
 *     Box(
 *         modifier = modifier
 *             .fillMaxWidth()
 *             .cornerRadius(16.dp)
 *             .background(Color(0xFF011820))
 *     ) {
 *         // Background Banner Image Layer
 *         Image(
 *             provider = ImageProvider(R.drawable.widget_banner_bg),
 *             contentDescription = null,
 *             modifier = GlanceModifier.fillMaxSize(),
 *             contentScale = ContentScale.Crop
 *         )
 *         // Translucent Dark Overlay for readability
 *         Box(modifier = GlanceModifier.fillMaxSize().background(Color(0xB2000E14))) {}
 *         // Content Row
 *         Row(
 *             modifier = GlanceModifier
 *                 .fillMaxWidth()
 *                 .padding(horizontal = 16.dp, vertical = 16.dp),
 *             verticalAlignment = Alignment.CenterVertically
 *         ) {
 *             Image(
 *                 provider = ImageProvider(R.drawable.widget_lotus_deity),
 *                 contentDescription = null,
 *                 modifier = GlanceModifier.size(54.dp).cornerRadius(10.dp),
 *                 contentScale = ContentScale.Fit
 *             )
 *             Spacer(GlanceModifier.width(14.dp))
 *             Column(modifier = GlanceModifier.defaultWeight()) {
 *                 Text(
 *                     text = "NEXT EKADASHI",
 *                     style = TextStyle(
 *                         color = ColorProvider(day = Color.White, night = Color.White),
 *                         fontWeight = FontWeight.Bold,
 *                         fontSize = 20.sp
 *                     )
 *                 )
 *                 Spacer(GlanceModifier.height(5.dp))
 *                 Text(
 *                     text = "Starts in 2 days",
 *                     style = TextStyle(
 *                         color = ColorProvider(day = Color(0xFFE0F7FA), night = Color(0xFFE0F7FA)),
 *                         fontWeight = FontWeight.Medium,
 *                         fontSize = 14.sp
 *                     )
 *                 )
 *             }
 *         }
 *     }
 * }
 *
 * @Composable
 * fun CompactUpcomingEkadashiPreview(
 *     dates: List<Pair<String, String>>,
 *     modifier: GlanceModifier = GlanceModifier
 * ) {
 *     Box(
 *         modifier = modifier
 *             .fillMaxWidth()
 *             .cornerRadius(16.dp)
 *             .background(Color(0xFF011820))
 *     ) {
 *         // Background Banner Image Layer
 *         Image(
 *             provider = ImageProvider(R.drawable.widget_banner_bg),
 *             contentDescription = null,
 *             modifier = GlanceModifier.fillMaxSize(),
 *             contentScale = ContentScale.Crop
 *         )
 *         // Translucent Dark Overlay for readability
 *         Box(modifier = GlanceModifier.fillMaxSize().background(Color(0xB2000E14))) {}
 *         // Content Row
 *         Row(
 *             modifier = GlanceModifier
 *                 .fillMaxWidth()
 *                 .padding(horizontal = 16.dp, vertical = 16.dp),
 *             verticalAlignment = Alignment.CenterVertically
 *         ) {
 *             Image(
 *                 provider = ImageProvider(R.drawable.widget_lotus_deity),
 *                 contentDescription = null,
 *                 modifier = GlanceModifier.size(56.dp).cornerRadius(10.dp),
 *                 contentScale = ContentScale.Fit
 *             )
 *             Spacer(GlanceModifier.width(14.dp))
 *             Column(modifier = GlanceModifier.defaultWeight()) {
 *                 Text(
 *                     text = "UPCOMING EKADASHI",
 *                     style = TextStyle(
 *                         color = ColorProvider(day = Color.White, night = Color.White),
 *                         fontWeight = FontWeight.Bold,
 *                         fontSize = 20.sp
 *                     )
 *                 )
 *                 Spacer(GlanceModifier.height(10.dp))
 *                 Row(
 *                     modifier = GlanceModifier.fillMaxWidth(),
 *                     horizontalAlignment = Alignment.Start
 *                 ) {
 *                     dates.take(3).forEach { (month, day) ->
 *                         Column(
 *                             modifier = GlanceModifier
 *                                 .width(50.dp)
 *                                 .cornerRadius(10.dp)
 *                                 .background(Color(0xFF021B24))
 *                                 .padding(vertical = 5.dp),
 *                             horizontalAlignment = Alignment.CenterHorizontally
 *                         ) {
 *                             Text(
 *                                 text = month,
 *                                 style = TextStyle(color = ColorProvider(Color(0xFF00E5FF), Color(0xFF00E5FF)), fontSize = 10.sp, fontWeight = FontWeight.Bold)
 *                             )
 *                             Text(
 *                                 text = day,
 *                                 style = TextStyle(color = ColorProvider(Color.White, Color.White), fontSize = 17.sp, fontWeight = FontWeight.Bold)
 *                             )
 *                         }
 *                         Spacer(GlanceModifier.width(8.dp))
 *                     }
 *                 }
 *             }
 *         }
 *     }
 * }
 * ============================================================================
 */
object EkadashiGlanceWidgetMetadata {
    const val SPEC_VERSION = "2.2.0"
}

