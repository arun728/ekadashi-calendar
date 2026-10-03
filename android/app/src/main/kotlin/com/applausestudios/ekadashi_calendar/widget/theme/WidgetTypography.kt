package com.applausestudios.ekadashi_calendar.widget.theme

/**
 * Centralized typography constants for Ekadashi Calendar 2.0 home-screen widgets.
 * Standardizes the 10-20% readability increase across Widget A, B, and C while
 * ensuring balanced hierarchy without clipping or layout breaking.
 */
object WidgetTypography {
    // Widget Title & Badges
    const val TITLE_SP = 11f
    const val BADGE_SP = 10f

    // Ekadashi Names (Hero focal point)
    const val HERO_NAME_SMALL_SP = 17f   // Widget A: ~13% increase from 15sp
    const val HERO_NAME_MEDIUM_SP = 18f  // Widget B: ~12.5% increase from 16sp
    const val HERO_NAME_LARGE_SP = 19f   // Widget C: ~12% increase from 17sp

    // Dates & Paksha
    const val DATE_SMALL_SP = 12f        // ~9% increase from 11sp
    const val DATE_MEDIUM_SP = 12f       // ~9% increase from 11sp
    const val DATE_LARGE_SP = 13f        // ~18% increase from 11sp

    // Timing Labels & Values (Fasting start & Parana window)
    const val TIMING_LABEL_SP = 10f      // ~11% increase from 9sp
    const val TIMING_VALUE_SP = 13f      // ~18% increase from 11sp
    const val TIMING_VALUE_MEDIUM_SP = 14f // ~16.7% increase from 12sp

    // Countdown / State
    const val COUNTDOWN_LABEL_SP = 11f   // ~10% increase from 10sp
    const val COUNTDOWN_VALUE_SMALL_SP = 16f // ~14% increase from 14sp
    const val COUNTDOWN_VALUE_MEDIUM_SP = 15f // ~15% increase from 13sp

    // Upcoming Collection List (Widget C)
    const val LIST_ITEM_NAME_SP = 14f    // ~16.7% increase from 12sp
    const val LIST_ITEM_DATE_SP = 11f    // ~10% increase from 10sp
    const val LIST_ITEM_CHEVRON_SP = 19f

    // Footer & Secondary Text
    const val SECONDARY_SP = 11f        // ~10% increase from 10sp
}
