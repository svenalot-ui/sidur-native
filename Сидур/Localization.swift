import SwiftUI

enum Lang: String, CaseIterable {
    case ru, he
    var isRTL: Bool { self == .he }
    var locale: Locale { Locale(identifier: self == .he ? "he_IL" : "ru_RU") }
    var layoutDirection: LayoutDirection { isRTL ? .rightToLeft : .leftToRight }
}

// Minimal string table for the screens implemented so far.
struct Strings {
    let lang: Lang
    private func t(_ ru: String, _ he: String) -> String { lang == .he ? he : ru }

    // tabs
    var today: String { t("Сегодня", "היום") }
    var zmanim: String { t("Зманим", "זמנים") }
    var prayers: String { t("Молитвы", "תפילות") }
    var brachot: String { t("Брахот", "ברכות") }
    var tehillim: String { t("Теилим", "תהילים") }
    var more: String { t("Ещё", "עוד") }

    // today
    var nearest: String { t("Ближайшая молитва", "התפילה הקרובה") }
    var locating: String { t("Определяем место…", "מאתר מיקום…") }
    var navDir: String { t("Направление", "כיוון") }
    var navCal: String { t("Календарь", "לוח") }
    var navTz: String { t("Цдака", "צדקה") }
    var favorites: String { t("Избранное", "שמורים") }
    var sh: String { t("Шахарит", "שַׁחֲרִית") }
    var mi: String { t("Минха", "מִנְחָה") }
    var ma: String { t("Маарив", "מַעֲרִיב") }
    var now: String { t("идёт сейчас", "עכשיו") }
    var tehTitle: String { t("Теилим сегодня", "תהילים היום") }
    var tehOpen: String { t("Читать главы дня", "קריאת פרקי היום") }

    // zmanim
    var zIntro: String { t("Основные времена дня. Нажмите на любое, чтобы увидеть варианты и включить напоминание.",
                            "זמני היום העיקריים. הקישו על כל אחד כדי לראות חישובים ולהפעיל תזכורת.") }
    var allVariants: String { t("Все варианты", "כל החישובים") }
    var remind: String { t("Напоминание", "תזכורת") }
    var remindOn: String { t("Напоминание включено", "התזכורת הופעלה") }
    var remindOff: String { t("Напоминание выключено", "התזכורת בוטלה") }
    var remindBefore: String { t("За сколько до", "כמה זמן לפני") }
    var onTime: String { t("Вовремя", "בזמן") }
    var min5: String { t("5 мин", "5 דק׳") }
    var min10: String { t("10 мин", "10 דק׳") }
    var min15: String { t("15 мин", "15 דק׳") }

    // common
    var settings: String { t("Настройки", "הגדרות") }
}

extension Lang {
    var s: Strings { Strings(lang: self) }
}
