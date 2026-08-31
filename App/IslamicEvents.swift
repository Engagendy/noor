import Foundation

/// "On this day" in Islamic history, keyed by Hijri (day, month).
/// Curated, well-attested dates; entries whose day is historically debated
/// say "على المشهور" (per the well-known account).
struct IslamicEvent: Identifiable {
    let day: Int
    let month: Int   // 1 = Muharram … 12 = Dhul-Hijjah
    let yearHijri: Int?
    let arabic: String
    let english: String
    /// Longer story shown in the detail sheet.
    let detailArabic: String
    let detailEnglish: String

    var id: String { "\(month)-\(day)-\(arabic.prefix(24))" }

    static let hijriMonthsArabic = [
        "محرم", "صفر", "ربيع الأول", "ربيع الآخر", "جمادى الأولى", "جمادى الآخرة",
        "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
    ]
    static let hijriMonthsEnglish = [
        "Muharram", "Safar", "Rabi al-Awwal", "Rabi al-Thani", "Jumada al-Ula",
        "Jumada al-Akhirah", "Rajab", "Sha'ban", "Ramadan", "Shawwal",
        "Dhul-Qi'dah", "Dhul-Hijjah",
    ]

    func monthName(arabicUI: Bool) -> String {
        let names = arabicUI ? Self.hijriMonthsArabic : Self.hijriMonthsEnglish
        return (1...12).contains(month) ? names[month - 1] : ""
    }

    static func events(day: Int, month: Int) -> [IslamicEvent] {
        all.filter { $0.day == day && $0.month == month }
    }

    static let all: [IslamicEvent] = [
        // Muharram
        IslamicEvent(day: 1, month: 1, yearHijri: 17,
            arabic: "اعتماد التقويم الهجري في عهد أمير المؤمنين عمر بن الخطاب رضي الله عنه.",
            english: "The Hijri calendar was adopted during the caliphate of Umar ibn al-Khattab.",
            detailArabic: "لما اتسعت الدولة الإسلامية واحتاج المسلمون إلى تاريخ موحّد للمراسلات والعهود، جمع عمر بن الخطاب رضي الله عنه الصحابة للتشاور. أشار علي بن أبي طالب رضي الله عنه بأن يبدأ التاريخ من هجرة النبي ﷺ، لأنها فرّقت بين الحق والباطل وقامت بها دولة الإسلام، فاعتُمد المحرم أول شهور السنة. وبقي هذا التقويم معمولًا به عند المسلمين إلى يومنا هذا.",
            detailEnglish: "As the Islamic state grew, Muslims needed a unified calendar for treaties and correspondence. Umar ibn al-Khattab gathered the Companions to consult, and Ali ibn Abi Talib suggested dating from the Prophet's ﷺ Hijra — the event that separated truth from falsehood and established the Muslim community. Muharram was set as the first month, and this calendar has been used by Muslims ever since."),
        IslamicEvent(day: 10, month: 1, yearHijri: nil,
            arabic: "يوم عاشوراء: نجّى الله موسى عليه السلام وقومه من فرعون، ويُسنّ صيامه.",
            english: "Ashura: Allah saved Musa (peace be upon him) and his people from Pharaoh; fasting this day is Sunnah.",
            detailArabic: "لما قدم النبي ﷺ المدينة وجد اليهود يصومون يوم عاشوراء، فقالوا: هذا يوم نجّى الله فيه موسى وقومه وأغرق فرعون. فقال ﷺ: «نحن أحق بموسى منكم»، فصامه وأمر بصيامه. وأخبر ﷺ أن صيامه يكفّر السنة الماضية، واستُحب صيام التاسع معه مخالفةً لأهل الكتاب.",
            detailEnglish: "When the Prophet ﷺ arrived in Madinah he found the Jews fasting on Ashura, commemorating the day Allah saved Musa and his people and drowned Pharaoh. He said, 'We have more right to Musa than you,' fasted the day, and encouraged fasting it. He taught that its fast expiates the previous year's sins, and recommended adding the 9th to differ from the People of the Book."),
        IslamicEvent(day: 10, month: 1, yearHijri: 61,
            arabic: "استشهاد الحسين بن علي رضي الله عنهما في كربلاء.",
            english: "The martyrdom of al-Husayn ibn Ali (may Allah be pleased with them) at Karbala.",
            detailArabic: "استُشهد سبط النبي ﷺ وريحانته الحسين بن علي رضي الله عنهما في كربلاء بالعراق سنة ٦١هـ، بعد أن خرج طالبًا الإصلاح في أمة جده. وقعت الفاجعة يوم عاشوراء، وعدّها المسلمون من أعظم المصائب، مع بقاء منهجهم في حب أهل البيت جميعًا.",
            detailEnglish: "Al-Husayn ibn Ali, the beloved grandson of the Prophet ﷺ, was martyred at Karbala in Iraq in 61 AH after setting out seeking reform in his grandfather's ummah. The tragedy fell on the day of Ashura and is counted among the gravest losses in Muslim history, mourned with love for the Prophet's household."),
        // Safar
        IslamicEvent(day: 27, month: 2, yearHijri: nil,
            arabic: "خروج النبي ﷺ من مكة مهاجرًا إلى المدينة (على المشهور).",
            english: "The Prophet ﷺ departed Makkah beginning the Hijra to Madinah (per the well-known account).",
            detailArabic: "بعد أن اشتد أذى قريش وأذن الله لنبيه ﷺ بالهجرة، خرج ﷺ من بيته ليلًا ومعه أبو بكر الصديق رضي الله عنه، فاختبآ في غار ثور ثلاث ليالٍ والمشركون يطلبونهما. قال ﷺ لصاحبه وقد بلغ المشركون باب الغار: «لا تحزن إن الله معنا». ثم سلكا طريق الساحل إلى المدينة، فكانت الهجرة فاتحة عهد جديد للإسلام.",
            detailEnglish: "When Quraysh's persecution intensified and Allah permitted His Prophet ﷺ to emigrate, he left his home by night with Abu Bakr as-Siddiq. They hid in the cave of Thawr for three nights while the Makkans hunted them; when the pursuers reached the cave's mouth, the Prophet ﷺ reassured his companion: 'Do not grieve — Allah is with us.' They then took the coastal route to Madinah, and the Hijra opened a new era for Islam."),
        IslamicEvent(day: 27, month: 2, yearHijri: 589,
            arabic: "وفاة السلطان صلاح الدين الأيوبي، محرر القدس.",
            english: "The death of Sultan Salah ad-Din al-Ayyubi, liberator of Jerusalem.",
            detailArabic: "توفي السلطان صلاح الدين يوسف بن أيوب في دمشق سنة ٥٨٩هـ بعد حياة قضاها في توحيد المسلمين وجهاد الصليبيين، وأعظم مآثره استعادة بيت المقدس بعد معركة حطين. وعُرف بزهده حتى إنه لم يترك في خزانته ما يكفي لجنازته، وبعفوه عن أعدائه يوم قدر عليهم.",
            detailEnglish: "Sultan Salah ad-Din Yusuf ibn Ayyub died in Damascus in 589 AH after a life spent uniting the Muslims and confronting the Crusaders, his greatest legacy being the recovery of Jerusalem after the Battle of Hattin. Famed for his asceticism — his treasury at death could barely pay for his funeral — he was equally renowned for pardoning enemies when he had full power over them."),
        // Rabi al-Awwal
        IslamicEvent(day: 8, month: 3, yearHijri: nil,
            arabic: "وصول النبي ﷺ إلى قباء وتأسيس أول مسجد في الإسلام.",
            english: "The Prophet ﷺ arrived at Quba, where the first mosque in Islam was founded.",
            detailArabic: "وصل النبي ﷺ في هجرته إلى قباء في ضاحية المدينة، فأقام فيها أيامًا وأسّس مسجد قباء، أول مسجد بُني في الإسلام، وهو الذي وصفه الله بأنه أُسس على التقوى من أول يوم. وأخبر ﷺ أن من تطهّر في بيته ثم أتاه فصلى فيه كان له كأجر عمرة.",
            detailEnglish: "On his Hijra journey the Prophet ﷺ reached Quba on the outskirts of Madinah, stayed several days, and founded the Quba Mosque — the first mosque built in Islam, described in the Quran as 'a mosque founded on piety from the first day.' He ﷺ taught that whoever purifies himself at home and prays in it has the reward of an Umrah."),
        IslamicEvent(day: 12, month: 3, yearHijri: nil,
            arabic: "مولد النبي محمد ﷺ (على المشهور).",
            english: "The birth of Prophet Muhammad ﷺ (per the well-known account).",
            detailArabic: "وُلد النبي محمد ﷺ بمكة عام الفيل، في الثاني عشر من ربيع الأول على المشهور عند أهل السير. نشأ يتيمًا في بني هاشم، وعُرف قبل البعثة بالصادق الأمين، حتى بعثه الله على رأس الأربعين رحمةً للعالمين وخاتمًا للنبيين.",
            detailEnglish: "Prophet Muhammad ﷺ was born in Makkah in the Year of the Elephant — on 12 Rabi al-Awwal per the well-known account of the biographers. Orphaned young, raised among Banu Hashim, he was known even before prophethood as 'the truthful, the trustworthy,' until Allah sent him at forty as a mercy to the worlds and the seal of the prophets."),
        IslamicEvent(day: 12, month: 3, yearHijri: 11,
            arabic: "وفاة النبي محمد ﷺ في المدينة المنورة.",
            english: "The passing of Prophet Muhammad ﷺ in Madinah.",
            detailArabic: "توفي النبي ﷺ ضحى يوم الاثنين ١٢ ربيع الأول سنة ١١هـ في حجرة عائشة رضي الله عنها، بعد أن بلّغ الرسالة وأدى الأمانة وترك أمته على المحجة البيضاء. اضطرب الصحابة لهول المصاب حتى قام أبو بكر فقال كلمته الخالدة: «من كان يعبد محمدًا فإن محمدًا قد مات، ومن كان يعبد الله فإن الله حي لا يموت».",
            detailEnglish: "The Prophet ﷺ passed away on Monday morning, 12 Rabi al-Awwal 11 AH, in the room of Aisha, having delivered the message in full and left his ummah upon the clear path. The Companions were shaken until Abu Bakr rose with his immortal words: 'Whoever worshipped Muhammad — Muhammad has died. Whoever worships Allah — Allah is Ever-Living and never dies.'"),
        // Rabi al-Thani
        IslamicEvent(day: 25, month: 4, yearHijri: 583,
            arabic: "معركة حطين: انتصار صلاح الدين ومهّدت لتحرير القدس.",
            english: "The Battle of Hattin: Salah ad-Din's victory that paved the way to liberating Jerusalem.",
            detailArabic: "التقى جيش صلاح الدين بجموع الصليبيين عند قرون حطين قرب طبرية سنة ٥٨٣هـ، فقطع عنهم الماء وأحاط بهم حتى تحطمت قوتهم العسكرية في يوم واحد، وأُسر ملك بيت المقدس. كانت حطين الضربة التي مهدت لاستعادة القدس بعد نحو تسعين سنة من الاحتلال الصليبي.",
            detailEnglish: "Salah ad-Din met the massed Crusader army at the Horns of Hattin near Tiberias in 583 AH. Cutting them off from water and encircling them, he shattered their military power in a single day and captured the king of Jerusalem. Hattin was the decisive blow that opened the way to recovering al-Quds after nearly ninety years of Crusader occupation."),
        // Jumada al-Ula
        IslamicEvent(day: 20, month: 5, yearHijri: 857,
            arabic: "فتح القسطنطينية على يد السلطان محمد الفاتح.",
            english: "The conquest of Constantinople by Sultan Muhammad al-Fatih.",
            detailArabic: "فتح السلطان العثماني محمد الثاني القسطنطينية سنة ٨٥٧هـ (١٤٥٣م) بعد حصار دام نحو شهرين، جرّ فيه السفن على اليابسة ودكّ الأسوار بمدافع لم يُعرف مثلها. وبه انتهت الإمبراطورية البيزنطية وصارت المدينة إسلامبول، وتحققت البشارة النبوية: «لتُفتحن القسطنطينية فلنعم الأمير أميرها ولنعم الجيش ذلك الجيش».",
            detailEnglish: "Ottoman Sultan Muhammad II took Constantinople in 857 AH (1453 CE) after a two-month siege in which he hauled ships overland and breached the walls with unprecedented cannon. The Byzantine Empire ended, the city became Istanbul, and the Prophet's ﷺ glad tiding was fulfilled: 'Constantinople shall surely be conquered — how excellent its commander, and how excellent that army.'"),
        // Jumada al-Akhirah
        IslamicEvent(day: 20, month: 6, yearHijri: nil,
            arabic: "ولادة فاطمة الزهراء بنت النبي ﷺ رضي الله عنها (على المشهور).",
            english: "The birth of Fatimah az-Zahra, daughter of the Prophet ﷺ (per the well-known account).",
            detailArabic: "وُلدت فاطمة رضي الله عنها بمكة قبل البعثة على المشهور، وهي أصغر بنات النبي ﷺ وأحبهن إليه، قال فيها: «فاطمة بضعة مني». تزوجها علي بن أبي طالب رضي الله عنه، وهي أم الحسن والحسين، وسيدة نساء أهل الجنة.",
            detailEnglish: "Fatimah was born in Makkah before the prophethood, per the well-known account — the youngest and dearest of the Prophet's ﷺ daughters, of whom he said: 'Fatimah is a part of me.' She married Ali ibn Abi Talib and was the mother of al-Hasan and al-Husayn; she is the leading lady of the women of Paradise."),
        IslamicEvent(day: 22, month: 6, yearHijri: 13,
            arabic: "وفاة الخليفة أبي بكر الصديق رضي الله عنه.",
            english: "The death of Caliph Abu Bakr as-Siddiq (may Allah be pleased with him).",
            detailArabic: "توفي أبو بكر الصديق رضي الله عنه سنة ١٣هـ بعد خلافة دامت سنتين وأشهرًا، ثبّت الله به الأمة يوم الردة، وجُمع في عهده القرآن، وسُيّرت الجيوش لفتح الشام والعراق. وهو صاحب رسول الله ﷺ في الغار، وأول الخلفاء الراشدين، ودُفن بجواره ﷺ.",
            detailEnglish: "Abu Bakr as-Siddiq died in 13 AH after a caliphate of just over two years, in which Allah steadied the ummah through the wars of apostasy, the Quran was gathered, and the armies set out toward Syria and Iraq. The Prophet's ﷺ companion in the cave and the first of the rightly-guided caliphs, he was buried beside him ﷺ."),
        // Rajab
        IslamicEvent(day: 5, month: 7, yearHijri: 15,
            arabic: "معركة اليرموك: انتصار المسلمين بقيادة خالد بن الوليد على الروم.",
            english: "The Battle of Yarmouk: the Muslims' victory over the Byzantines under Khalid ibn al-Walid.",
            detailArabic: "التقى المسلمون بجموع الروم العظيمة على ضفاف نهر اليرموك سنة ١٥هـ، وكان عدد الروم أضعاف عدد المسلمين. نظّم خالد بن الوليد رضي الله عنه الجيش تنظيمًا محكمًا، ودارت معركة حاسمة انتهت بهزيمة الروم وخروجهم من الشام، فقال هرقل كلمته الشهيرة: «سلامٌ عليك يا سورية».",
            detailEnglish: "The Muslims met the massed Byzantine host on the banks of the Yarmouk in 15 AH, outnumbered several times over. Khalid ibn al-Walid organized the army with unprecedented skill, and the decisive battle ended with the Byzantines' defeat and withdrawal from Syria — Heraclius famously bidding it farewell: 'Peace be upon you, O Syria.'"),
        IslamicEvent(day: 27, month: 7, yearHijri: nil,
            arabic: "الإسراء والمعراج (على المشهور).",
            english: "Al-Isra wal-Mi'raj — the Night Journey (per the well-known account).",
            detailArabic: "أُسري بالنبي ﷺ ليلًا من المسجد الحرام إلى المسجد الأقصى، ثم عُرج به إلى السماوات العلا حيث فُرضت الصلوات الخمس. صلى ﷺ بالأنبياء إمامًا في بيت المقدس، ورأى من آيات ربه الكبرى، وكانت الرحلة تثبيتًا له بعد عام الحزن وتشريفًا لبيت المقدس برباطه بالمسجد الحرام.",
            detailEnglish: "The Prophet ﷺ was taken by night from the Sacred Mosque in Makkah to al-Masjid al-Aqsa, then ascended through the heavens, where the five daily prayers were ordained. He led the prophets in prayer at Jerusalem and was shown the greatest signs of his Lord — a journey of consolation after the Year of Sorrow, forever binding al-Aqsa to the Sacred Mosque."),
        IslamicEvent(day: 27, month: 7, yearHijri: 583,
            arabic: "استعادة صلاح الدين للقدس ودخوله المسجد الأقصى.",
            english: "Salah ad-Din restored Jerusalem and entered al-Masjid al-Aqsa.",
            detailArabic: "بعد حطين سار صلاح الدين إلى بيت المقدس فتسلمه صلحًا سنة ٥٨٣هـ، وأعاد الأقصى مسجدًا وطهّره، ونصب فيه منبر نور الدين زنكي. وعفا عن أهله عفوًا شهدت به كتب خصومه، على خلاف ما فعله الصليبيون عند دخولهم قبل تسعين سنة.",
            detailEnglish: "After Hattin, Salah ad-Din advanced on Jerusalem and received its surrender in 583 AH. He restored and purified al-Aqsa, installing the minbar Nur ad-Din had prepared, and pardoned the city's inhabitants with a clemency recorded even by his enemies' chroniclers — the opposite of the massacre the Crusaders had wrought ninety years earlier."),
        IslamicEvent(day: 28, month: 7, yearHijri: 1342,
            arabic: "إلغاء الخلافة العثمانية، آخر خلافة إسلامية.",
            english: "The abolition of the Ottoman Caliphate, the last Islamic caliphate.",
            detailArabic: "في ٢٨ رجب سنة ١٣٤٢هـ (١٩٢٤م) أعلنت الجمعية الوطنية التركية إلغاء الخلافة ونفي آخر الخلفاء عبد المجيد الثاني، فطُويت صفحة مؤسسة جمعت المسلمين قرونًا منذ الخلفاء الراشدين. وقد عدّه المسلمون حدثًا جللًا في تاريخ الأمة الحديث.",
            detailEnglish: "On 28 Rajab 1342 AH (1924 CE) the Turkish National Assembly abolished the caliphate and exiled the last caliph, Abdulmejid II — closing an institution that had, in one form or another, linked the Muslim world since the rightly-guided caliphs. Muslims have regarded it as one of the gravest turning points of the modern era."),
        // Sha'ban
        IslamicEvent(day: 15, month: 8, yearHijri: 2,
            arabic: "تحويل القبلة من بيت المقدس إلى المسجد الحرام (على قولٍ مشهور).",
            english: "The Qibla changed from Jerusalem to the Sacred Mosque in Makkah (per a well-known account).",
            detailArabic: "كان النبي ﷺ يصلي نحو بيت المقدس ويحب أن تكون قبلته الكعبة، فيقلّب وجهه في السماء، حتى نزل الأمر بالتوجه شطر المسجد الحرام في السنة الثانية للهجرة. وتحوّل المسلمون وهم في الصلاة، وسُمي مسجد بني سلمة «مسجد القبلتين» لأن الصحابة صلوا فيه صلاة واحدة إلى قبلتين.",
            detailEnglish: "The Prophet ﷺ had prayed toward Jerusalem while longing for the Kaaba, turning his face to the sky, until the command came down in 2 AH to face the Sacred Mosque. Worshippers pivoted mid-prayer, and the mosque of Banu Salamah became known as 'the Mosque of the Two Qiblas' — one prayer, two directions."),
        // Ramadan
        IslamicEvent(day: 10, month: 9, yearHijri: nil,
            arabic: "وفاة أم المؤمنين خديجة بنت خويلد رضي الله عنها في عام الحزن.",
            english: "The death of the Mother of the Believers Khadijah bint Khuwaylid in the Year of Sorrow.",
            detailArabic: "توفيت خديجة رضي الله عنها بمكة قبل الهجرة بنحو ثلاث سنين، في العام الذي سُمي عام الحزن لوفاتها ووفاة أبي طالب. كانت أول من آمن بالنبي ﷺ وواسته بمالها ونفسها، وقال فيها: «إني رُزقت حبها»، وبشّرها ربها ببيت في الجنة لا صخب فيه ولا نصب.",
            detailEnglish: "Khadijah died in Makkah about three years before the Hijra, in the year named 'the Year of Sorrow' for her passing and that of Abu Talib. The first believer in the Prophet ﷺ, she supported him with her wealth and her whole self; he said, 'I was blessed with her love,' and her Lord sent her glad tidings of a house in Paradise free of noise and weariness."),
        IslamicEvent(day: 15, month: 9, yearHijri: 3,
            arabic: "ولادة الحسن بن علي رضي الله عنهما، سبط النبي ﷺ.",
            english: "The birth of al-Hasan ibn Ali, grandson of the Prophet ﷺ.",
            detailArabic: "وُلد الحسن بن علي رضي الله عنهما في رمضان سنة ٣هـ، وهو أشبه الناس برسول الله ﷺ الذي قال فيه: «إن ابني هذا سيد، ولعل الله أن يصلح به بين فئتين عظيمتين من المسلمين» — فتحقق ذلك حين تنازل عن الخلافة لمعاوية سنة ٤١هـ حقنًا لدماء المسلمين، فسُمي ذلك عام الجماعة.",
            detailEnglish: "Al-Hasan ibn Ali was born in Ramadan 3 AH, and of all people he most resembled the Messenger ﷺ, who said of him: 'This son of mine is a sayyid, and perhaps Allah will reconcile through him two great parties of the Muslims.' It came true when he ceded the caliphate to Mu'awiyah in 41 AH to spare Muslim blood — a year remembered as the Year of Unity."),
        IslamicEvent(day: 17, month: 9, yearHijri: 2,
            arabic: "غزوة بدر الكبرى: الفرقان الذي أعزّ الله به الإسلام.",
            english: "The great Battle of Badr — the Criterion by which Allah honored Islam.",
            detailArabic: "التقى المسلمون وهم ثلاثمائة وبضعة عشر بقريش وهي نحو الألف عند ماء بدر في ١٧ رمضان سنة ٢هـ. أمدّ الله المؤمنين بالملائكة، وقُتل صناديد قريش، وسُمي يوم الفرقان. قال ﷺ يوم بدر: «اللهم إن تهلك هذه العصابة لا تُعبد في الأرض»، فكان النصر أول عز للإسلام.",
            detailEnglish: "Three hundred and a few more Muslims met nearly a thousand of Quraysh at the wells of Badr on 17 Ramadan 2 AH. Allah reinforced the believers with angels, the chiefs of Quraysh fell, and the day was named the Day of the Criterion. The Prophet ﷺ had pleaded, 'O Allah, if this band perishes, You will not be worshipped on earth' — and the victory became Islam's first great honor."),
        IslamicEvent(day: 17, month: 9, yearHijri: 58,
            arabic: "وفاة أم المؤمنين عائشة رضي الله عنها.",
            english: "The death of the Mother of the Believers Aisha (may Allah be pleased with her).",
            detailArabic: "توفيت عائشة بنت أبي بكر رضي الله عنهما سنة ٥٨هـ ودُفنت بالبقيع ليلًا كما أوصت. كانت أفقه نساء الأمة وأكثرهن روايةً عن النبي ﷺ، حتى كان أكابر الصحابة يسألونها. ونزلت براءتها من فوق سبع سماوات في آياتٍ تُتلى إلى يوم القيامة.",
            detailEnglish: "Aisha bint Abi Bakr died in 58 AH and was buried at al-Baqi by night, as she had requested. The most learned woman of the ummah and among the greatest narrators from the Prophet ﷺ, even senior Companions sought her rulings. Her innocence was proclaimed from above the seven heavens in verses recited to this day."),
        IslamicEvent(day: 20, month: 9, yearHijri: 8,
            arabic: "فتح مكة: دخل النبي ﷺ مكة وحطّم الأصنام حول الكعبة.",
            english: "The Conquest of Makkah: the Prophet ﷺ entered Makkah and the idols around the Kaaba were removed.",
            detailArabic: "دخل النبي ﷺ مكة في رمضان سنة ٨هـ في عشرة آلاف من أصحابه، مطأطئ الرأس تواضعًا لله، بعد أن نقضت قريش عهدها. أزال الأصنام من حول الكعبة، ثم قال لأهل مكة: «اذهبوا فأنتم الطلقاء»، فكان الفتح الأعظم الذي دخل الناس بعده في دين الله أفواجًا.",
            detailEnglish: "The Prophet ﷺ entered Makkah in Ramadan 8 AH with ten thousand Companions, head bowed in humility before Allah, after Quraysh broke their treaty. He removed the idols from around the Kaaba, then told the Makkans: 'Go — you are free.' After this greatest of openings, people entered Allah's religion in multitudes."),
        IslamicEvent(day: 21, month: 9, yearHijri: 40,
            arabic: "استشهاد الخليفة علي بن أبي طالب رضي الله عنه.",
            english: "The martyrdom of Caliph Ali ibn Abi Talib (may Allah be pleased with him).",
            detailArabic: "طعن الخارجيُّ ابنُ ملجم عليًا رضي الله عنه وهو خارج لصلاة الفجر بالكوفة في رمضان سنة ٤٠هـ، فتوفي بعدها بليال. وهو ابن عم النبي ﷺ وزوج فاطمة، وأول من أسلم من الصبيان، ورابع الخلفاء الراشدين، وقال فيه ﷺ يوم خيبر: «لأعطين الراية غدًا رجلًا يحب الله ورسوله ويحبه الله ورسوله».",
            detailEnglish: "The Kharijite Ibn Muljam struck Ali as he went out for Fajr prayer in Kufa in Ramadan 40 AH; he died nights later. Cousin of the Prophet ﷺ, husband of Fatimah, the first boy to embrace Islam and the fourth rightly-guided caliph — of him the Prophet ﷺ said at Khaybar: 'Tomorrow I shall give the banner to a man who loves Allah and His Messenger, and whom Allah and His Messenger love.'"),
        IslamicEvent(day: 25, month: 9, yearHijri: 658,
            arabic: "معركة عين جالوت: انتصار المسلمين على المغول.",
            english: "The Battle of Ain Jalut: the Muslims' victory over the Mongols.",
            detailArabic: "بعد أن اجتاح المغول بغداد وأسقطوا الخلافة وظن الناس أن لا قِبل لأحد بهم، خرج المظفر قطز ومعه بيبرس بجيش مصر فالتقوا بهم عند عين جالوت بفلسطين في رمضان سنة ٦٥٨هـ. صاح قطز «وا إسلاماه» واقتحم المعركة بنفسه، فانكسر المغول لأول مرة كسرة كبرى، وأُنقذت مصر والشام والحرمان.",
            detailEnglish: "After the Mongols had sacked Baghdad, ended the caliphate, and seemed unstoppable, al-Muzaffar Qutuz marched out of Egypt with Baybars and met them at Ain Jalut in Palestine, Ramadan 658 AH. Crying 'Wa Islamah!' Qutuz plunged into the battle himself; the Mongols suffered their first shattering defeat, and Egypt, Syria, and the two Sanctuaries were saved."),
        IslamicEvent(day: 28, month: 9, yearHijri: 92,
            arabic: "بدء فتح الأندلس بقيادة طارق بن زياد.",
            english: "The opening of al-Andalus began under Tariq ibn Ziyad.",
            detailArabic: "عبر طارق بن زياد بجيشه المضيق الذي حمل اسمه من بعدُ (جبل طارق) سنة ٩٢هـ، ثم هزم القوط في معركة وادي لكة الحاسمة. وبذلك فُتحت الأندلس التي أضاءت ثمانية قرون بحضارة قرطبة وغرناطة وإشبيلية، ونقلت العلوم إلى أوروبا كلها.",
            detailEnglish: "Tariq ibn Ziyad crossed the strait that would bear his name (Gibraltar — Jabal Tariq) in 92 AH, then defeated the Visigoths at the decisive Battle of Guadalete. Thus opened al-Andalus, which for eight centuries shone with the civilization of Cordoba, Granada, and Seville, carrying the sciences into all of Europe."),
        // Shawwal
        IslamicEvent(day: 1, month: 10, yearHijri: nil,
            arabic: "عيد الفطر المبارك، تقبّل الله منا ومنكم.",
            english: "Eid al-Fitr — may Allah accept from us and from you.",
            detailArabic: "شرع الله عيد الفطر شكرًا له على إتمام صيام رمضان، يفتتحه المسلمون بزكاة الفطر طهرةً للصائم وطعمةً للمساكين، ثم صلاة العيد والتكبير. وهو يوم فرح قال فيه ﷺ: «للصائم فرحتان: فرحة عند فطره وفرحة عند لقاء ربه».",
            detailEnglish: "Allah ordained Eid al-Fitr as thanksgiving for completing the fast of Ramadan. Muslims open it with Zakat al-Fitr — purification for the fasting person and food for the poor — then the Eid prayer and takbir. A day of joy, as the Prophet ﷺ said: 'The fasting person has two joys: one when he breaks his fast, and one when he meets his Lord.'"),
        IslamicEvent(day: 7, month: 10, yearHijri: 3,
            arabic: "غزوة أُحد ودرسها الخالد في الثبات على أمر النبي ﷺ.",
            english: "The Battle of Uhud and its lasting lesson in holding to the Prophet's ﷺ command.",
            detailArabic: "خرجت قريش سنة ٣هـ لتثأر لبدر، فالتقى الجمعان عند جبل أحد. كان النصر أولًا للمسلمين حتى خالف الرماةُ أمرَ النبي ﷺ ونزلوا عن الجبل، فدارت الدائرة واستُشهد سبعون من الصحابة منهم حمزة سيد الشهداء. فنزلت آيات آل عمران تربي الأمة على الثبات وتبيّن ثمرة المخالفة.",
            detailEnglish: "Quraysh marched in 3 AH to avenge Badr, and the armies met at Mount Uhud. Victory was first with the Muslims — until the archers left their post against the Prophet's ﷺ explicit command, and the tide turned; seventy Companions were martyred, among them Hamzah, master of martyrs. The verses of Aal Imran came down, teaching the ummah forever the price of disobedience and the virtue of steadfastness."),
        // Dhul-Hijjah
        IslamicEvent(day: 9, month: 12, yearHijri: 10,
            arabic: "يوم عرفة: خطبة الوداع ونزول ﴿الْيَوْمَ أَكْمَلْتُ لَكُمْ دِينَكُمْ﴾.",
            english: "The Day of Arafah: the Farewell Sermon and the revelation 'This day I have perfected your religion for you.'",
            detailArabic: "وقف النبي ﷺ بعرفة في حجة الوداع سنة ١٠هـ وخطب في نحو مائة ألف من أصحابه خطبته الجامعة: حرّم الدماء والأموال والأعراض، ووضع ربا الجاهلية، وأوصى بالنساء خيرًا، وقال: «فليبلغ الشاهد الغائب». وفي عشية ذلك اليوم نزلت آية إكمال الدين. وصيام يوم عرفة لغير الحاج يكفّر سنتين.",
            detailEnglish: "At Arafah during the Farewell Pilgrimage in 10 AH, the Prophet ﷺ addressed some hundred thousand Companions: sanctifying life, property, and honor, abolishing the usury of Jahiliyyah, enjoining kindness to women, and charging those present to convey the message. That very evening the verse of the religion's completion was revealed. Fasting Arafah, for those not on Hajj, expiates two years."),
        IslamicEvent(day: 10, month: 12, yearHijri: nil,
            arabic: "عيد الأضحى المبارك، تقبّل الله منا ومنكم.",
            english: "Eid al-Adha — may Allah accept from us and from you.",
            detailArabic: "عيد الأضحى ذكرى فداء إسماعيل عليه السلام حين أسلم إبراهيمُ وابنُه لأمر الله ففداه الله بذبح عظيم. فيه ينحر الحجاج هديهم بمنى ويذبح المسلمون أضاحيهم في الآفاق، وهو أعظم أيام السنة، قال ﷺ: «أعظم الأيام عند الله يوم النحر».",
            detailEnglish: "Eid al-Adha commemorates the ransom of Ismail (peace be upon him), when Ibrahim and his son submitted wholly to Allah's command and Allah ransomed him with a great sacrifice. Pilgrims offer their sacrifices at Mina and Muslims worldwide slaughter their udhiyah — the greatest of days, as the Prophet ﷺ said: 'The greatest of days with Allah is the Day of Sacrifice.'"),
        IslamicEvent(day: 18, month: 12, yearHijri: 35,
            arabic: "استشهاد الخليفة عثمان بن عفان رضي الله عنه.",
            english: "The martyrdom of Caliph Uthman ibn Affan (may Allah be pleased with him).",
            detailArabic: "حاصر الثائرون دار عثمان رضي الله عنه أيامًا وهو يأبى أن يُراق بسببه دم مسلم، حتى قُتل وهو صائم يقرأ القرآن سنة ٣٥هـ. وهو ذو النورين زوج ابنتي النبي ﷺ، جهّز جيش العسرة، وجمع الناس على مصحف واحد، وبشّره ﷺ بالجنة على بلوى تصيبه.",
            detailEnglish: "Rebels besieged Uthman's house for days while he refused to let a single Muslim's blood be shed on his account — until he was killed, fasting, with the Quran open before him, in 35 AH. Dhun-Nurayn, husband of two of the Prophet's ﷺ daughters, he equipped the Army of Hardship and united the ummah upon one mushaf; the Prophet ﷺ had foretold him Paradise 'after a trial that would befall him.'"),
        IslamicEvent(day: 26, month: 12, yearHijri: 23,
            arabic: "طعن الخليفة عمر بن الخطاب رضي الله عنه وهو يصلي الفجر.",
            english: "Caliph Umar ibn al-Khattab was stabbed while leading the Fajr prayer.",
            detailArabic: "طعن المجوسيُّ أبو لؤلؤة عمرَ رضي الله عنه وهو يصلي الفجر بالناس في المدينة سنة ٢٣هـ، فتوفي بعدها بأيام ودُفن بجوار النبي ﷺ وأبي بكر بإذن عائشة. في خلافته فُتحت الشام والعراق ومصر وبيت المقدس، وأرسى دواوين الدولة، وقال فيه ﷺ: «لو كان بعدي نبي لكان عمر».",
            detailEnglish: "The Magian Abu Lu'lu'ah stabbed Umar as he led the Fajr prayer in Madinah in 23 AH; he died days later and was buried beside the Prophet ﷺ and Abu Bakr with Aisha's consent. His caliphate saw the opening of Syria, Iraq, Egypt, and Jerusalem and the founding of the state's institutions; the Prophet ﷺ had said: 'Were there a prophet after me, it would be Umar.'"),
    ]
}
