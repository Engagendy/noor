#!/usr/bin/env python3
"""Merge the per-language translation files into App/Resources/Localizable.xcstrings.

Usage:  python3 Tools/i18n/merge_translations.py

Reads  Tools/i18n/translations/<code>.json            (flat key -> string, or
                                                       {"plural": {...}} )
       Tools/i18n/translations/<code>.onboarding.json (the first-run screens,
                                                       added as new keys)
Writes App/Resources/Localizable.xcstrings in place.

Idempotent: re-running with the same inputs produces the same file. Existing
`en` and `ar` localizations are never touched.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, "App/Resources/Localizable.xcstrings")
TRANSLATIONS = os.path.join(ROOT, "Tools/i18n/translations")

LANGUAGES = ["id", "ur", "fa", "tr", "ms", "bn", "fr", "es"]

# The onboarding screens, moved out of hardcoded Swift into the catalog.
# The Arabic is the text that was already in OnboardingView.swift — reviewed
# copy, not generated here. English is the key itself, as elsewhere.
ONBOARDING_AR = {
    "Welcome to Noor": "أهلًا بك في نور",
    "Quran, prayer times, and athkar — private and free forever":
        "القرآن ومواقيت الصلاة والأذكار — خاص ومجاني للأبد",
    "App language": "لغة التطبيق",
    "Continue": "متابعة",
    "Your city for prayer times": "مدينتك لمواقيت الصلاة",
    "A beautiful adhan at every prayer. You can change or silence it anytime.":
        "أذان جميل عند كل صلاة. يمكنك تغيير الصوت أو إيقافه لاحقًا.",
    "Enable adhan": "تفعيل الأذان",
    "Maybe later": "لاحقًا",
}

SPECIFIER = re.compile(r"%(?:(\d+)\$)?[-+ #0]*[\d*]*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|t|j)?([@dioufeEgGxXcspa%])")


def specifiers(value):
    """Multiset of conversion characters, ignoring position and %% escapes."""
    return sorted(m.group(2) for m in SPECIFIER.finditer(value) if m.group(2) != "%")


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def main():
    with open(CATALOG, encoding="utf-8") as handle:
        catalog = json.load(handle)
    strings = catalog["strings"]

    # 1. New onboarding keys (en is the key itself; ar is the existing copy).
    for key, arabic in ONBOARDING_AR.items():
        entry = strings.setdefault(key, {})
        localizations = entry.setdefault("localizations", {})
        localizations.setdefault("ar", unit(arabic))

    # 2. Five keys never had an Arabic localization. Three are pure layout
    # templates with no words in them; the other two are `%@` twins of
    # `%lld` keys that ARE translated, so the Arabic is copied from the
    # sibling rather than written here (hard rule: no invented Arabic).
    glue = {
        "%@  %@%@": "%1$@  %2$@%3$@",
        "%@ · %@": "%1$@ · %2$@",
        "%@ −%@:%@": "%1$@ −%2$@:%3$@",
    }
    for key, value in glue.items():
        strings.setdefault(key, {}).setdefault("localizations", {}).setdefault("ar", unit(value))
    for key, sibling in {"%@ min": "%lld min", "Repeat %@×": "Repeat %lld×"}.items():
        source = (strings.get(sibling, {}).get("localizations", {}).get("ar", {})
                  .get("stringUnit", {}).get("value"))
        if source:
            strings.setdefault(key, {}).setdefault("localizations", {}) \
                .setdefault("ar", unit(source.replace("%lld", "%@")))

    problems = []
    for language in LANGUAGES:
        values = {}
        for name in (f"{language}.json", f"{language}.onboarding.json"):
            path = os.path.join(TRANSLATIONS, name)
            if not os.path.exists(path):
                problems.append(f"{language}: missing {name}")
                continue
            with open(path, encoding="utf-8") as handle:
                values.update(json.load(handle))

        for key, entry in strings.items():
            if key not in values:
                problems.append(f"{language}: no translation for {key!r}")
                continue
            value = values[key]
            localizations = entry.setdefault("localizations", {})
            if isinstance(value, dict) and "plural" in value:
                localizations[language] = {
                    "variations": {
                        "plural": {
                            category: unit(text)
                            for category, text in value["plural"].items()
                        }
                    }
                }
                continue
            if not isinstance(value, str) or not value.strip():
                problems.append(f"{language}: empty value for {key!r}")
                continue
            source = (entry.get("localizations", {}).get("en", {})
                      .get("stringUnit", {}).get("value", key))
            if specifiers(source) != specifiers(value):
                problems.append(
                    f"{language}: format specifiers differ for {key!r}: "
                    f"{specifiers(source)} vs {specifiers(value)}")
            localizations[language] = unit(value)

        extra = set(values) - set(strings)
        for key in sorted(extra):
            problems.append(f"{language}: translation for unknown key {key!r}")

    catalog["strings"] = {key: strings[key] for key in sorted(strings)}
    with open(CATALOG, "w", encoding="utf-8") as handle:
        json.dump(catalog, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"{len(strings)} keys, {len(LANGUAGES)} languages merged")
    for problem in problems:
        print("PROBLEM:", problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
