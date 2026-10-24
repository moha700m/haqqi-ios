import Foundation

/// Arabic normalization + synonym folding used by the chatbot retriever.
public enum ArabicText {
    /// Remove tashkeel/tatweel, unify alef/yaa/taa marbuta/hamza forms, Arabic-Indic digits -> Latin.
    public static func normalize(_ input: String) -> String {
        var out = ""
        for scalar in input.lowercased().unicodeScalars {
            let v = scalar.value
            if (0x064B...0x065F).contains(v) || v == 0x0670 || v == 0x0640 { continue } // tashkeel, tatweel
            switch v {
            case 0x0622, 0x0623, 0x0625, 0x0671: out.append("ا")
            case 0x0649: out.append("ي")
            case 0x0629: out.append("ه")
            case 0x0624: out.append("و")
            case 0x0626: out.append("ي")
            case 0x0660...0x0669: out.append(Character(UnicodeScalar(v - 0x0660 + 48)!))
            case 0x06F0...0x06F9: out.append(Character(UnicodeScalar(v - 0x06F0 + 48)!))
            default:
                if CharacterSet.punctuationCharacters.contains(scalar) || CharacterSet.symbols.contains(scalar) {
                    out.append(" ")
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Canonical concept -> surface forms (already normalized-compatible, normalized at load).
    public static let synonymGroups: [String: [String]] = [
        "ارجاع": ["ارجاع", "ارجع", "استرجاع", "استرجع", "رجع", "ارجعه", "رجعه", "اردها", "ارده", "رد", "فسخ", "الغاء الطلب", "استرداد", "استرد", "ترجيع", "رجّع"],
        "استبدال": ["استبدال", "ابدل", "ابدله", "تبديل", "بدل", "استبدل", "اغيره"],
        "عيب": ["عيب", "معيب", "مكسور", "خربان", "خراب", "خرب", "عطلان", "عطل", "تالف", "مضروب", "ما يشتغل", "مغشوش", "تقليد", "معطوب"],
        "تاخير": ["تاخير", "تاخر", "متاخر", "ما وصل", "ماوصل", "تاخرت", "ما جاني", "ما جا", "تأخر", "طول", "تاخرو", "ما وصلني"],
        "ضمان": ["ضمان", "كفاله", "الضمان", "مضمون"],
        "قطع": ["قطع", "قطعه", "قطع غيار", "صيانه", "الصيانه", "وكيل", "الوكاله", "تصليح", "اصلاح"],
        "اونلاين": ["اونلاين", "انترنت", "الانترنت", "متجر الكتروني", "متجر", "تطبيق", "موقع", "طلبت", "طلب", "نون", "امازون", "شي ان"],
        "محل": ["محل", "المحل", "معرض", "سوق", "بقاله", "فرع", "الكاشير"],
        "قسيمه": ["قسيمه", "كوبون", "رصيد", "فاوتشر", "قسيمة شرائيه", "credit"],
        "لا ترد": ["لا ترد", "لا تستبدل", "ما ترد", "ما تستبدل", "لاترد"],
        "غلط": ["غلط", "غير اللي طلبته", "مو اللي طلبت", "مختلف", "مو مطابق", "غير مطابق", "لون ثاني", "مقاس ثاني"],
        "تكرر": ["تكرر", "ثالث مره", "مره ثالثه", "رجع العطل", "نفس العطل", "كل مره", "يتكرر"],
        "استخدام": ["استخدمت", "استعملت", "فتحته", "جربته", "استخدام", "مستعمل"],
        "بلاغ": ["بلاغ", "اشتكي", "شكوى", "اشتكى", "1900", "الوزاره", "وزاره التجاره", "ابلغ"],
        "سياسه": ["سياسه", "سياسه الاسترجاع", "شروط"],
    ]

    private static let normalizedGroups: [(String, [String])] = synonymGroups.map { k, v in
        (k, Array(Set(v.map { normalize($0) })).sorted { $0.count > $1.count })
    }

    /// Returns the set of canonical concepts present in the text, plus raw tokens (len>=3).
    public static func concepts(in text: String) -> Set<String> {
        let n = " " + normalize(text) + " "
        var found = Set<String>()
        for (key, forms) in normalizedGroups {
            for f in forms where !f.isEmpty {
                let a: String = " " + f
                let b: String = " ال" + f
                let c: String = "و" + f + " "
                if n.contains(a) || n.contains(b) || n.contains(c) {
                    found.insert(key); break
                }
            }
        }
        return found
    }

    public static func tokens(_ text: String) -> Set<String> {
        var out = Set<String>()
        let words: [Substring] = normalize(text).split(separator: " ")
        for w in words where w.count >= 3 {
            let t = String(w)
            if t.hasPrefix("ال") && t.count > 4 {
                out.insert(String(t.dropFirst(2)))
            } else {
                out.insert(t)
            }
        }
        return out
    }
}
