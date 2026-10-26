#if DEBUG
import SwiftUI
import WidgetKit
import EkadashiCore

/// Deliberately unavailable without an explicit testing launch argument.
/// No controls, payload strings or clock configuration are emitted in Release.
struct DebugLifecycleClockView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedUID = ""
    @State private var rate = 0.0
    private var event: EkadashiOccurrence? {
        model.ekadashis.first { $0.occurrenceUid == selectedUID }
            ?? model.ekadashis.last { $0.fastingStart.map { $0 <= Date() } ?? false }
    }
    var body: some View {
        List {
            Section {
                Text(DebugClockWords.text("explanation", model.language))
                Picker(DebugClockWords.text("occurrence", model.language), selection: $selectedUID) {
                    ForEach(model.ekadashis) { item in
                        Text("\(item.date.iso) · \(item.name)").tag(item.occurrenceUid)
                    }
                }.accessibilityIdentifier("test_clock_occurrence")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(DisplayClock.date(context.date).formatted(date: .complete, time: .standard))
                        .accessibilityIdentifier("test_clock_time")
                }
            }
            if let event, let start = event.fastingStart, let parana = event.paranaStart, let end = event.paranaEnd {
                Section(DebugClockWords.text("boundaries", model.language)) {
                    jump("midnight", model.scheduleZone.utc(event.date), "test_clock_midnight")
                    jump("before_start", start.addingTimeInterval(-5), "test_clock_before_start")
                    jump("start", start, "test_clock_start")
                    jump("halfway", start.addingTimeInterval(parana.timeIntervalSince(start) / 2), "test_clock_halfway")
                    jump("next_midnight", model.scheduleZone.utc(event.date.adding(days: 1)), "test_clock_following_midnight")
                    jump("before_parana", parana.addingTimeInterval(-5), "test_clock_before_parana")
                    jump("parana", parana, "test_clock_parana")
                    jump("before_end", end.addingTimeInterval(-5), "test_clock_before_end")
                    jump("end", end, "test_clock_end")
                }
            }
            Section(DebugClockWords.text("speed", model.language)) {
                Picker(DebugClockWords.text("speed", model.language), selection: $rate) {
                    Text(DebugClockWords.text("paused", model.language)).tag(0.0); Text(DebugClockWords.text("realtime", model.language)).tag(1.0)
                    Text("60×").tag(60.0); Text("3600×").tag(3600.0)
                }.onChange(of: rate) { _, value in set(DisplayClock.date(Date()), rate: value) }
                Button(DebugClockWords.text("live", model.language)) {
                    // Remain in the isolated session even when displaying real time.
                    rate = 1
                    WidgetClock.set(Date(), rate: 1)
                    model.selectCurrentOccurrence(now: Date()); model.syncWidgets()
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
        .navigationTitle(DebugClockWords.text("title", model.language))
        .onAppear { if selectedUID.isEmpty { selectedUID = event?.occurrenceUid ?? "" } }
    }
    private func jump(_ title: String, _ date: Date, _ id: String) -> some View {
        Button(DebugClockWords.text(title, model.language)) { set(date, rate: rate) }.accessibilityIdentifier(id)
    }
    private func set(_ date: Date, rate: Double) {
        WidgetClock.set(date, rate: rate)
        model.selectCurrentOccurrence(now: date); model.syncWidgets()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
enum DebugClockWords {
    private static let languages = ["en", "hi", "ta", "te", "gu", "bn"]
    private static let words: [String: [String]] = [
        "title": ["Lifecycle test clock", "परीक्षण घड़ी", "சோதனைக் கடிகாரம்", "పరీక్ష గడియారం", "પરીક્ષણ ઘડિયાળ", "পরীক্ষার ঘড়ি"],
        "banner": ["TEST CLOCK · Notifications and recording disabled", "परीक्षण घड़ी · सूचनाएँ और प्रविष्टि बंद", "சோதனைக் கடிகாரம் · அறிவிப்புகளும் பதிவும் முடக்கப்பட்டுள்ளன", "పరీక్ష గడియారం · నోటిఫికేషన్లు మరియు నమోదు నిలిపివేయబడ్డాయి", "પરીક્ષણ ઘડિયાળ · સૂચનાઓ અને નોંધ બંધ", "পরীক্ষার ঘড়ি · বিজ্ঞপ্তি ও নথিভুক্তি বন্ধ"],
        "explanation": ["Test only. The device clock stays unchanged. Settings, history and widget data are isolated. This mode is absent from Release.", "केवल परीक्षण। फ़ोन की घड़ी नहीं बदलेगी। सेटिंग, इतिहास और विजेट डेटा अलग हैं। यह मोड जारी ऐप में नहीं है।", "சோதனைக்கு மட்டும். சாதனக் கடிகாரம் மாறாது. அமைப்புகள், வரலாறு, விட்ஜெட் தரவுகள் தனியாக இருக்கும். வெளியீட்டு செயலியில் இம்முறை இல்லை.", "పరీక్ష కోసం మాత్రమే. పరికర గడియారం మారదు. సెట్టింగ్‌లు, చరిత్ర మరియు విడ్జెట్ సమాచారం వేరుగా ఉంటాయి. విడుదల యాప్‌లో ఈ విధానం ఉండదు.", "ફક્ત પરીક્ષણ. ફોનની ઘડિયાળ બદલાતી નથી. સેટિંગ, ઇતિહાસ અને વિજેટ માહિતી અલગ છે. પ્રકાશિત ઍપમાં આ રીત નથી.", "শুধু পরীক্ষার জন্য। ফোনের ঘড়ি বদলাবে না। সেটিংস, ইতিহাস ও উইজেটের তথ্য আলাদা। প্রকাশিত অ্যাপে এই ব্যবস্থা নেই।"],
        "occurrence": ["Occurrence", "एकादशी", "ஏகாதசி", "ఏకాదశి", "એકાદશી", "একাদশী"],
        "boundaries": ["Jump to a boundary", "समय सीमा चुनें", "நேர எல்லையைத் தேர்ந்தெடு", "సమయ హద్దును ఎంచుకోండి", "સમયની સીમા પસંદ કરો", "সময়ের সীমা বেছে নিন"],
        "speed": ["Clock speed", "घड़ी की गति", "கடிகார வேகம்", "గడియార వేగం", "ઘડિયાળની ગતિ", "ঘড়ির গতি"],
        "paused": ["Paused", "रुका हुआ", "இடைநிறுத்தம்", "నిలిపివేయబడింది", "થોભાવેલું", "বিরত"],
        "realtime": ["Real time · 1×", "वास्तविक समय · 1×", "இயல்பு நேரம் · 1×", "వాస్తవ సమయం · 1×", "વાસ્તવિક સમય · 1×", "প্রকৃত সময় · 1×"],
        "live": ["Return to live time", "वास्तविक समय पर लौटें", "இயல்பு நேரத்திற்குத் திரும்பு", "వాస్తవ సమయానికి తిరిగి వెళ్ళండి", "વાસ્તવિક સમયે પાછા જાઓ", "প্রকৃত সময়ে ফিরুন"],
        "midnight": ["Fasting day midnight", "व्रत के दिन आधी रात", "விரத நாளின் நள்ளிரவு", "ఉపవాస రోజు అర్ధరాత్రి", "ઉપવાસના દિવસની મધરાત", "উপবাসের দিনের মধ্যরাত"],
        "before_start": ["5 seconds before fast starts", "व्रत शुरू होने से 5 सेकंड पहले", "விரதம் தொடங்க 5 நொடிகள் முன்", "ఉపవాసం ప్రారంభానికి 5 సెకన్ల ముందు", "ઉપવાસ શરૂ થવાની 5 સેકન્ડ પહેલાં", "উপবাস শুরুর 5 সেকেন্ড আগে"],
        "start": ["Fast starts · 0%", "व्रत आरंभ · 0%", "விரதம் தொடக்கம் · 0%", "ఉపవాస ప్రారంభం · 0%", "ઉપવાસ શરૂ · 0%", "উপবাস শুরু · 0%"],
        "halfway": ["Halfway · 50%", "आधा समय · 50%", "பாதி நேரம் · 50%", "సగం సమయం · 50%", "અડધો સમય · 50%", "অর্ধেক সময় · 50%"],
        "next_midnight": ["Following midnight", "अगली आधी रात", "அடுத்த நள்ளிரவு", "తదుపరి అర్ధరాత్రి", "પછીની મધરાત", "পরের মধ্যরাত"],
        "before_parana": ["5 seconds before Parana", "पारण से 5 सेकंड पहले", "பாரணைக்கு 5 நொடிகள் முன்", "పారణకు 5 సెకన్ల ముందు", "પારણાની 5 સેકન્ડ પહેલાં", "পারণের 5 সেকেন্ড আগে"],
        "parana": ["Parana · 100%", "पारण · 100%", "பாரணை · 100%", "పారణ · 100%", "પારણું · 100%", "পারণ · 100%"],
        "before_end": ["5 seconds before Parana ends", "पारण समाप्त होने से 5 सेकंड पहले", "பாரணை முடிய 5 நொடிகள் முன்", "పారణ ముగియడానికి 5 సెకన్ల ముందు", "પારણું પૂરું થવાની 5 સેકન્ડ પહેલાં", "পারণ শেষের 5 সেকেন্ড আগে"],
        "end": ["Parana ends · next occurrence", "पारण समाप्त · अगली एकादशी", "பாரணை முடிவு · அடுத்த ஏகாதசி", "పారణ ముగింపు · తదుపరి ఏకాదశి", "પારણું પૂર્ણ · આગામી એકાદશી", "পারণ শেষ · পরবর্তী একাদশী"],
    ]
    static var keys: [String] { words.keys.sorted() }
    static func text(_ key: String, _ language: String) -> String {
        words[key]?[languages.firstIndex(of: language) ?? 0] ?? key
    }
}

#endif
