import Foundation

/// Writes a Latin place name in Hindi, Tamil, Telugu, Gujarati or Bengali
/// script by sound ("Toronto" → "टोरोंटो"), for the cities the place-name
/// table does not cover, so no Latin letters appear outside English.
/// lib/l10n/transliterator.dart is the same algorithm; the shared fixture
/// test/fixtures/transliteration.json keeps them identical.
public enum Transliterator {
    /// [name] in [language]'s script; unchanged in English or an unknown language.
    public static func transliterate(_ name: String, language: String) -> String {
        guard let script = scripts[language] else { return name }
        var out = ""
        var word = ""
        func flush() {
            if !word.isEmpty { out += render(units(word), script) }
            word = ""
        }
        for ch in fold(name) {
            if ch.isASCII && ch.isLetter { word.append(ch) } else {
                flush()
                if ch.isNumber || " -.,()/&".contains(ch) { out.append(ch) }
            }
        }
        flush()
        return out.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespaces)
    }

    // MARK: Latin to sounds

    static let special: [Character: String] = ["ə": "e", "Ə": "e", "ı": "i", "ł": "l", "Ł": "l", "ø": "o", "Ø": "o",
                                               "æ": "ae", "Æ": "ae", "ß": "ss", "đ": "d", "Đ": "d", "ħ": "h", "Ħ": "h",
                                               "þ": "th", "Þ": "th", "ŋ": "ng", "œ": "oe", "Œ": "oe", "ð": "d"]

    /// Lowercase ASCII letters, with accents and apostrophes removed.
    static func fold(_ text: String) -> String {
        var mapped = ""
        for ch in text { mapped += special[ch] ?? String(ch) }
        let decomposed = mapped.decomposedStringWithCanonicalMapping.lowercased()
        return String(decomposed.unicodeScalars.filter { scalar in
            !(0x300...0x36F).contains(scalar.value) && !"'’‘ʻʼ`".unicodeScalars.contains(scalar)
        }.map(Character.init))
    }

    static let vowelLetters: Set<Character> = ["a", "e", "i", "o", "u"]
    static let vowels: Set<String> = ["a", "aa", "i", "ii", "u", "uu", "e", "ai", "o", "au"]

    /// Longest match first.
    static let clusters: [(String, [String])] = [
        ("chr", ["k", "r"]), ("tch", ["ch"]), ("sch", ["sh"]), ("chh", ["ch"]), ("ch", ["ch"]), ("sh", ["sh"]), ("zh", ["j"]),
        ("th", ["th"]), ("dh", ["dh"]), ("kh", ["kh"]), ("gh", ["g"]), ("bh", ["bh"]), ("ph", ["f"]),
        ("jh", ["jh"]), ("ck", ["k"]), ("qu", ["k", "v"]), ("x", ["k", "s"]),
        ("aa", ["aa"]), ("ee", ["ii"]), ("ea", ["ii"]), ("oo", ["uu"]), ("ou", ["u"]), ("ow", ["o"]),
        ("ai", ["ai"]), ("ay", ["e"]), ("au", ["au"]), ("aw", ["o"]), ("ei", ["e"]), ("ey", ["e"]),
        ("ie", ["ii"]), ("oa", ["o"]), ("oe", ["o"]), ("ue", ["uu"]),
    ]

    static let singles: [Character: String] = [
        "a": "a", "e": "e", "i": "i", "o": "o", "u": "u", "b": "b", "d": "D", "f": "f", "g": "g", "h": "h",
        "j": "j", "k": "k", "l": "l", "m": "m", "n": "n", "p": "p", "q": "k", "r": "r", "s": "s", "t": "T",
        "v": "v", "w": "v", "z": "z",
    ]

    static func units(_ word: String) -> [String] {
        var letters = Array(word)
        // A silent final "e" after a consonant ("Melbourne").
        if letters.count >= 5, letters.last == "e", !vowelLetters.contains(letters[letters.count - 2]) {
            letters.removeLast()
        }
        var result: [String] = []
        var i = 0
        while i < letters.count {
            let ch = letters[i]
            // Doubled consonants sound once ("Seattle").
            if i > 0, letters[i - 1] == ch, !vowelLetters.contains(ch), ch != "y" { i += 1; continue }
            // A final "gh" is silent ("Raleigh"); "g" is soft before e, i, y ("George").
            if ch == "g", i + 1 < letters.count, letters[i + 1] == "h", i + 2 == letters.count { i += 2; continue }
            if ch == "g", i + 1 < letters.count, "eiy".contains(letters[i + 1]), i > 0 || letters.count > 3 {
                result.append("j")
                i += 1
                continue
            }
            // A silent "h" after a vowel with no vowel after it ("John", "Sharjah").
            if ch == "h", i > 0, vowelLetters.contains(letters[i - 1]),
               i + 1 == letters.count || !vowelLetters.contains(letters[i + 1]) {
                i += 1
                continue
            }
            if let (pattern, sounds) = clusters.first(where: { cluster in
                guard matches(cluster.0, letters, i) else { return false }
                // "aw", "ay", "ow", "ey" glide into a following vowel ("Ottawa").
                if "wy".contains(cluster.0.last!), cluster.0.count == 2, i + 2 < letters.count,
                   vowelLetters.contains(letters[i + 2]) { return false }
                return true
            }) {
                result += sounds
                i += pattern.count
                continue
            }
            if ch == "c" {
                let next = i + 1 < letters.count ? letters[i + 1] : " "
                result.append("eiy".contains(next) ? "s" : "k")
            } else if ch == "y" {
                // A consonant before a vowel ("York"), else a vowel ("Sydney").
                let next = i + 1 < letters.count ? letters[i + 1] : " "
                result.append(vowelLetters.contains(next) ? "y" : "ii")
            } else if let sound = singles[ch] {
                result.append(sound)
            }
            i += 1
        }
        // Word-final "a" is long in place names ("Agra"); an unstressed final
        // "-on", "-en", "-er" is a short a ("Boston", "Manchester"); "n"
        // before a consonant is a nasal sign.
        if result.count > 1, result.last == "a" { result[result.count - 1] = "aa" }
        if result.count > 1, result.last == "i" { result[result.count - 1] = "ii" }
        if letters.count >= 5, result.count >= 3, !vowels.contains(result[result.count - 1]),
           ["o", "e"].contains(result[result.count - 2]), !vowels.contains(result[result.count - 3]) {
            result[result.count - 2] = "a"
        }
        for k in result.indices where result[k] == "n" && k + 1 < result.count && !vowels.contains(result[k + 1])
            && k > 0 && vowels.contains(result[k - 1]) {
            result[k] = "N"
        }
        // A glide between two vowels: "Miami" (i·y·aa), "Kuala" (u·v·a).
        var glided: [String] = []
        for sound in result {
            if let last = glided.last, vowels.contains(last), vowels.contains(sound) {
                if ["i", "ii", "e"].contains(last) { glided.append("y") }
                else if ["u", "uu", "o"].contains(last), ["a", "aa"].contains(sound) { glided.append("v") }
            }
            glided.append(sound)
        }
        return glided
    }

    static func matches(_ pattern: String, _ letters: [Character], _ at: Int) -> Bool {
        let p = Array(pattern)
        guard at + p.count <= letters.count else { return false }
        return letters[at..<at + p.count].elementsEqual(p)
    }

    // MARK: Sounds to script

    struct Script {
        let consonants: [String: String]
        let independent: [String: String]
        let signs: [String: String]
        let virama: String
        let nasal: String
        /// Tamil and Telugu close a final consonant with the virama.
        let finalVirama: Bool
        /// Tamil writes a word-initial n as ந and a later one as ன.
        let initialN: String?
        /// Bengali writes a word-initial y as ইয় ("York").
        var initialY: String? = nil
        /// Tamil's nasal letter of the following consonant's group.
        var nasalBefore: [String: String] = [:]
    }

    static func render(_ sounds: [String], _ s: Script) -> String {
        var out = ""
        var i = 0
        while i < sounds.count {
            let sound = sounds[i]
            if sound == "N" {
                let next = i + 1 < sounds.count ? sounds[i + 1] : ""
                out += s.nasalBefore[next] ?? s.nasal
            } else if vowels.contains(sound) {
                out += s.independent[sound] ?? ""
            } else {
                var letter = s.consonants[sound] ?? ""
                if sound == "n", i == 0, let initial = s.initialN { letter = initial }
                if sound == "y", i == 0, let initial = s.initialY { letter = initial }
                out += letter
                let next = i + 1 < sounds.count ? sounds[i + 1] : nil
                if let next, vowels.contains(next) {
                    if next != "a" { out += s.signs[next] ?? "" }
                    i += 1
                } else if next != nil || s.finalVirama {
                    // A cluster, or a final consonant in Tamil and Telugu.
                    out += s.virama
                }
            }
            i += 1
        }
        return out
    }

    static func table(_ keys: String, _ values: String) -> [String: String] {
        // Split on scalars: a vowel sign after a space would join it into
        // one Character.
        func parts(_ text: String) -> [String] {
            text.unicodeScalars.split(separator: " ").map { String(String.UnicodeScalarView($0)) }
        }
        return Dictionary(uniqueKeysWithValues: zip(parts(keys), parts(values)))
    }

    static let consonantKeys = "k kh g gh ch j jh T Th D Dh t th d dh n p f b bh m y r l v sh s h z"
    static let vowelKeys = "a aa i ii u uu e ai o au"
    static let signKeys = "aa i ii u uu e ai o au"

    static let scripts: [String: Script] = [
        "hi": Script(
            consonants: table(consonantKeys, "क ख ग घ च ज झ ट ठ ड ढ त थ द ध न प फ़ ब भ म य र ल व श स ह ज़"),
            independent: table(vowelKeys, "अ आ इ ई उ ऊ ए ऐ ओ औ"),
            signs: table(signKeys, "ा ि ी ु ू े ै ो ौ"), virama: "्", nasal: "ं", finalVirama: false, initialN: nil),
        "gu": Script(
            consonants: table(consonantKeys, "ક ખ ગ ઘ ચ જ ઝ ટ ઠ ડ ઢ ત થ દ ધ ન પ ફ બ ભ મ ય ર લ વ શ સ હ ઝ"),
            independent: table(vowelKeys, "અ આ ઇ ઈ ઉ ઊ એ ઐ ઓ ઔ"),
            signs: table(signKeys, "ા િ ી ુ ૂ ે ૈ ો ૌ"), virama: "્", nasal: "ં", finalVirama: false, initialN: nil),
        "bn": Script(
            consonants: table(consonantKeys, "ক খ গ ঘ চ জ ঝ ট ঠ ড ঢ ত থ দ ধ ন প ফ ব ভ ম য় র ল ভ শ স হ জ"),
            independent: table(vowelKeys, "অ আ ই ঈ উ ঊ এ ঐ ও ঔ"),
            signs: table(signKeys, "া ি ী ু ূ ে ৈ ো ৌ"), virama: "্", nasal: "ং", finalVirama: false, initialN: nil,
            initialY: "ইয়"),
        "te": Script(
            consonants: table(consonantKeys, "క ఖ గ ఘ చ జ ఝ ట ఠ డ ఢ త థ ద ధ న ప ఫ బ భ మ య ర ల వ శ స హ జ"),
            independent: table(vowelKeys, "అ ఆ ఇ ఈ ఉ ఊ ఏ ఐ ఓ ఔ"),
            signs: table(signKeys, "ా ి ీ ు ూ ే ై ో ౌ"), virama: "్", nasal: "ం", finalVirama: true, initialN: nil),
        "ta": Script(
            consonants: table(consonantKeys, "க க க க ச ஜ ஜ ட ட ட ட த த த த ன ப ப ப ப ம ய ர ல வ ஷ ஸ ஹ ஜ"),
            independent: table(vowelKeys, "அ ஆ இ ஈ உ ஊ ஏ ஐ ஓ ஔ"),
            signs: table(signKeys, "ா ி ீ ு ூ ே ை ோ ௌ"), virama: "்", nasal: "ன்", finalVirama: true, initialN: "ந",
            nasalBefore: table("k kh g gh ch j jh T Th D Dh t th d dh p f b bh m",
                               "ங் ங் ங் ங் ஞ் ஞ் ஞ் ண் ண் ண் ண் ந் ந் ந் ந் ம் ம் ம் ம் ம்")),
    ]
}
