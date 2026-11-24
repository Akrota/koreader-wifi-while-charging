-- Beschreibung auf Deutsch oder Englisch, je nach KOReader-Sprache
local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
local de = ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de"
return {
    fullname = de and "WLAN beim Laden" or "Wi-Fi while charging",
    description = de
        and "Solange der E-Reader am Ladekabel hängt, schaltet KOReader das WLAN nicht wegen Inaktivität ab. Auf Wunsch schaltet es das WLAN beim Einstecken auch ein."
        or "While the e-reader is plugged in, KOReader does not turn Wi-Fi off for inactivity. If you like, Wi-Fi is also turned on when you plug it in.",
    version = "0.1.0",
}
