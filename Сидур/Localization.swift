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
    var edit: String { t("Изменить", "עריכה") }
    var editDone: String { t("Готово", "סיום") }
    var sh: String { t("Шахарит", "שַׁחֲרִית") }
    var mi: String { t("Минха", "מִנְחָה") }
    var ma: String { t("Маарив", "מַעֲרִיב") }
    var now: String { t("идёт сейчас", "עכשיו") }
    var startsAt: String { t("начало", "תחילה") }
    var tehTitle: String { t("Теилим сегодня", "תהילים היום") }
    var tehOpen: String { t("Читать главы дня", "קריאת פרקי היום") }
    var shmaWord: String { t("Шма", "ק״ש") }
    var nightWord: String { t("ночь", "לילה") }
    var graShort: String { t("Гра", "גר״א") }
    var untilShort: String { t("до", "עד") }

    // zmanim
    var zIntro: String { t("Основные времена дня. Нажмите на любое, чтобы увидеть варианты и включить напоминание.",
                            "זמני היום העיקריים. הקישו על כל אחד כדי לראות חישובים ולהפעיל תזכורת.") }
    var allVariants: String { t("Все варианты", "כל החישובים") }
    var chooseTime: String { t("Какое время показывать", "איזה זמן להציג") }
    var zDisclaimer: String { t("Времена рассчитаны приблизительно и даны для справки — уточняйте по вашей общине.",
                                "הזמנים מחושבים בקירוב ומיועדים לעיון בלבד — בדקו מול הקהילה שלכם.") }
    var remind: String { t("Напоминание", "תזכורת") }
    var remindOn: String { t("Напоминание включено", "התזכורת הופעלה") }
    var remindOff: String { t("Напоминание выключено", "התזכורת בוטלה") }
    var remindBefore: String { t("За сколько до", "כמה זמן לפני") }
    var onTime: String { t("Вовремя", "בזמן") }
    var min5: String { t("5 мин", "5 דק׳") }
    var min10: String { t("10 мин", "10 דק׳") }
    var min15: String { t("15 мин", "15 דק׳") }
    var remindHint: String { t("Уведомления приходят, даже когда приложение закрыто", "ההתראות מגיעות גם כשהאפליקציה סגורה") }
    var remindWhich: String { t("Время для напоминания", "זמן לתזכורת") }
    var notifDenied: String { t("Разрешите уведомления: Настройки iPhone → Сидур", "אשרו התראות בהגדרות האייפון") }

    // prayers / brachot
    var often: String { t("Часто нужные", "הנפוצות") }
    var beforeEat: String { t("Перед едой", "לפני האכילה") }
    var afterEat: String { t("После еды", "לאחר האכילה") }
    var daily: String { t("Ежедневные", "יומיות") }
    var personal: String { t("Личные молитвы", "תפילות אישיות") }
    var otherPrayers: String { t("Другие", "אחרות") }
    var brachotMore: String { t("Все благословения", "עוד ברכות") }
    var soon: String { t("Полный текст скоро", "הטקסט המלא בקרוב") }
    var soonComing: String { t("Текст скоро появится", "הטקסט יתווסף בקרוב") }

    // tehillim
    var tehBook: String { t("Вся книга", "כל הספר") }
    var tehByDay: String { t("По дням", "לפי יום") }
    var tehDay: String { t("День", "יום") }
    var psalm: String { t("Псалом", "מזמור") }
    var tehFavTitle: String { t("Избранные", "מועדפים") }
    var needNet: String { t("Нужна сеть при первом открытии", "דרושה רשת בפתיחה הראשונה") }
    var retry: String { t("Повторить", "נסו שוב") }
    var continueReading: String { t("Продолжить чтение", "המשך קריאה") }
    var segulot: String { t("Сгулот", "סגולות") }
    var segIntro: String { t("Подборки глав Теилим на разные нужды", "מבחר פרקי תהילים לצרכים שונים") }
    var nextZman: String { t("следующий", "הבא") }
    var setLoc: String { t("Местоположение", "מיקום") }
    var setLocRefresh: String { t("Обновить по GPS", "רענון לפי GPS") }
    var feedback: String { t("Обратная связь", "משוב") }
    var candleLighting: String { t("Зажигание свечей", "הדלקת נרות") }
    var shabbatEnd: String { t("Исход Шаббата", "צאת השבת") }
    var shabbatShalom: String { t("Шаббат шалом", "שבת שלום") }
    var shabbatResting: String { t("Приложение отдыхает до исхода Шаббата", "האפליקציה נחה עד צאת השבת") }
    var shabbatEndsAt: String { t("Исход", "צאת השבת") }
    var notShabbat: String { t("Сейчас не Шаббат", "עכשיו לא שבת") }
    var chagSameach: String { t("Хаг самеах", "חג שמח") }
    var chagResting: String { t("Приложение отдыхает до исхода праздника", "האפליקציה נחה עד צאת החג") }
    var chagEndsAt: String { t("Исход праздника", "צאת החג") }
    var notChag: String { t("Сейчас не праздник", "עכשיו לא חג") }
    var erevChag: String { t("Канун праздника", "ערב חג") }
    var candleReminderTitle: String { t("Напоминание о свечах", "תזכורת הדלקת נרות") }
    var candleReminderSub: String { t("За 30 минут до зажигания", "30 דקות לפני ההדלקה") }
    var sections: String { t("Разделы", "פרקים") }
    var noRu: String { t("Русский перевод недоступен — показана транслитерация", "תרגום רוסי לא זמין") }
    var bookHdr: [String] { lang == .he
        ? ["ספר ראשון", "ספר שני", "ספר שלישי", "ספר רביעי", "ספר חמישי"]
        : ["Книга первая", "Книга вторая", "Книга третья", "Книга четвёртая", "Книга пятая"] }

    // reader
    var fSize: String { t("Размер", "גודל") }
    var fBg: String { t("Фон", "רקע") }
    var he_: String { t("Иврит", "עברית") }
    var translit: String { t("Транслит.", "תעתיק") }
    var ru_: String { t("Русский", "רוסית") }
    var bgPaper: String { t("Бумага", "נייר") }
    var bgSepia: String { t("Сепия", "ספיה") }
    var bgWhite: String { t("Белый", "לבן") }
    var bgNight: String { t("Ночь", "לילה") }

    // mizrah (compass)
    var mizrahTitle: String { t("Направление молитвы", "כיוון התפילה") }
    var toJerusalem: String { t("до Иерусалима", "לירושלים") }
    var km: String { t("км", "ק״מ") }
    var facing: String { t("Лицом к Иерусалиму", "פונה לירושלים") }
    var rotateHint: String { t("Поворачивайтесь, пока стрелка не укажет вверх", "סובבו עד שהחץ יפנה למעלה") }
    var calibHint: String { t("Если неточно — поводите телефоном «восьмёркой»", "אם לא מדויק — הניעו בצורת שמינייה") }

    // tzedaka
    var tzedakaTitle: String { t("Цдака", "צדקה") }
    var tzedakaSub: String { t("Цдака перед молитвой", "צדקה לפני התפילה") }
    var tzedakaText: String { t("Принято давать цдаку перед молитвой. «Цдака спасает от смерти». Отсканируйте QR в приложении банка — реквизиты подставятся.",
                                 "נהגו לתת צדקה לפני התפילה. «וּצְדָקָה תַּצִּיל מִמָּוֶת». סרקו את הקוד באפליקציית הבנק.") }
    var requisites: String { t("Реквизиты", "פרטי תשלום") }
    var rqName: String { t("Получатель", "מקבל") }
    var rqAcc: String { t("Расчётный счёт", "חשבון") }
    var rqBank: String { t("Банк", "בנק") }
    var rqBik: String { t("БИК", "BIC") }
    var rqCor: String { t("Корр. счёт", "נוסטרו") }
    var copied: String { t("Скопировано", "הועתק") }

    // onboarding
    var onbTitle: String { t("Выберите нусах молитвы", "בחרו נוסח תפילה") }
    var onbSub: String { t("Влияет на тексты и порядок молитв. Можно изменить в настройках.", "משפיע על נוסח וסדר התפילות. ניתן לשנות בהגדרות.") }
    var setNusach: String { t("Нусах молитвы", "נוסח התפילה") }
    var soonBadge: String { t("Скоро", "בקרוב") }

    // calendar
    var calTitle: String { t("Еврейский календарь", "לוח עברי") }
    var calEvents: String { t("События", "אירועים") }
    var calNoEvents: String { t("Нет особых событий", "אין אירועים מיוחדים") }
    var calError: String { t("Не удалось загрузить календарь — нужна сеть", "טעינת הלוח נכשלה — דרושה רשת") }

    // settings
    var setLang: String { t("Язык приложения", "שפת האפליקציה") }
    var setTheme: String { t("Оформление", "מראה") }
    var themeAuto: String { t("Авто", "אוטומטי") }
    var themeLight: String { t("День", "יום") }
    var themeDark: String { t("Ночь", "לילה") }

    // common
    var settings: String { t("Настройки", "הגדרות") }
}

extension Lang {
    var s: Strings { Strings(lang: self) }
}
