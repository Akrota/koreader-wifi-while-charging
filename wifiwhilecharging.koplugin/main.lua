-- WLAN beim Laden: Solange der E-Reader am Ladekabel haengt, schaltet KOReader das WLAN nicht
-- wegen Inaktivitaet ab ("WLAN-Verbindung bei Inaktivitaet trennen"). Auf Wunsch wird das WLAN
-- beim Einstecken auch eingeschaltet.
-- Wie: KOReader prueft alle paar Minuten, wie viele Pakete gesendet wurden
-- (NetworkListener:_getTxPackets). Am Ladekabel liefert das Plugin dort "keine Messung", dann
-- ueberspringt KOReader die Pruefung und laesst das WLAN an. Fehlt die Funktion nach einem
-- KOReader-Update, haengt sich das Plugin nirgends ein und KOReader verhaelt sich wie immer.
-- Nie eingeschaltet wird das WLAN, wenn es von Hand ausgeschaltet wurde (KOReader merkt sich
-- das als "wifi_was_on") oder das Plugin AirPlaneMode (kodermike) den Flugmodus an hat.
local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local NetworkMgr = require("ui/network/manager")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local util = require("util")

local strings = {
    de = {
        menu_title = "WLAN beim Laden: %s",
        state_off = "aus",
        state_keep = "anlassen",
        state_on = "anlassen und einschalten",
        mode_off = "Aus",
        mode_keep = "WLAN anlassen",
        mode_on = "WLAN anlassen und beim Einstecken einschalten",
        mode_off_help = "Das Plugin tut nichts, KOReader verhält sich wie immer.",
        mode_keep_help = "Am Ladekabel bleibt ein eingeschaltetes WLAN an: Der E-Reader schläft nicht von selbst ein, und KOReader schaltet es nicht wegen Inaktivität ab. Eingeschaltet wird es aber nie von selbst. Die vorsichtige Wahl, z. B. für Powerbank oder Flugzeug.",
        mode_on_help = "Wie „WLAN anlassen“. Dazu schaltet das Plugin das WLAN beim Einstecken ein, außer du hast es vorher von Hand ausgeschaltet. Gut für zu Hause.",
        no_hook = "Hinweis: wirkt mit dieser KOReader-Version nicht",
        no_hook_help = "Diese KOReader-Version prüft das WLAN anders, als das Plugin erwartet. Damit nichts kaputtgeht, greift „WLAN anlassen“ nicht ein. Einschalten beim Einstecken funktioniert trotzdem.",
        about = "Wie funktioniert das?",
        about_text = "Das WLAN geht normalerweise aus, wenn der E-Reader nach der eingestellten Zeit ohne Berührung von selbst einschläft, und, falls eingeschaltet, wenn ein paar Minuten kaum Daten fließen („WLAN-Verbindung bei Inaktivität trennen“). Das spart Akku, unterbricht aber z. B. lange KI-Anfragen oder Downloads.\n\nSolange der E-Reader am Ladekabel hängt, verhindert dieses Plugin beides. Hülle zuklappen und Einschaltknopf wirken weiter. Ziehst du das Kabel ab, gilt wieder alles wie gewohnt.\n\nZwei Stufen:\n• WLAN anlassen: Ein eingeschaltetes WLAN bleibt an. Von selbst eingeschaltet wird es nie. Die vorsichtige Wahl, z. B. an der Powerbank oder im Flugzeug.\n• … und beim Einstecken einschalten: Zusätzlich geht das WLAN beim Einstecken an. Hast du es vorher von Hand ausgeschaltet, bleibt es aus, bis du es selbst wieder einschaltest.\n\nIst das Plugin AirPlaneMode installiert und der Flugmodus an, schaltet dieses Plugin das WLAN nie ein.\n\nAusschalten von Hand geht immer, auch am Ladekabel.",
        turning_on = "Am Ladekabel: WLAN wird eingeschaltet …",
    },
    en = {
        menu_title = "Wi-Fi while charging: %s",
        state_off = "off",
        state_keep = "keep on",
        state_on = "keep on and turn on",
        mode_off = "Off",
        mode_keep = "Keep Wi-Fi on",
        mode_on = "Keep Wi-Fi on and turn it on when plugged in",
        mode_off_help = "The plugin does nothing, KOReader behaves as usual.",
        mode_keep_help = "While plugged in, Wi-Fi that is on stays on: the e-reader does not fall asleep by itself, and KOReader does not turn Wi-Fi off for inactivity. It never turns Wi-Fi on by itself, though. The careful choice, e.g. for a power bank or on a plane.",
        mode_on_help = "Like \"Keep Wi-Fi on\". In addition, the plugin turns Wi-Fi on when you plug in, unless you turned it off by hand before. Good for home.",
        no_hook = "Note: has no effect with this KOReader version",
        no_hook_help = "This KOReader version checks Wi-Fi differently than the plugin expects. So that nothing breaks, \"Keep Wi-Fi on\" does not step in. Turning it on when plugged in still works.",
        about = "How does it work?",
        about_text = "Wi-Fi normally goes off when the e-reader falls asleep by itself after the set time without touch, and, if enabled, when hardly any data flows for a few minutes (\"Disable Wi-Fi connection when inactive\"). That saves battery, but interrupts e.g. long AI requests or downloads.\n\nWhile the e-reader is plugged in, this plugin prevents both. Closing the cover and the power button still work. Once you unplug, everything is as usual again.\n\nTwo levels:\n• Keep Wi-Fi on: Wi-Fi that is on stays on. It is never turned on by itself. The careful choice, e.g. on a power bank or a plane.\n• … and turn it on when plugged in: in addition, Wi-Fi goes on when you plug in. If you turned it off by hand before, it stays off until you turn it on yourself.\n\nIf the AirPlaneMode plugin is installed and airplane mode is on, this plugin never turns Wi-Fi on.\n\nYou can always turn Wi-Fi off by hand, also while plugged in.",
        turning_on = "Plugged in: turning Wi-Fi on…",
    },
}

local function T(key, ...)
    local ok, lang = pcall(function() return G_reader_settings:readSetting("language") end)
    if not ok or type(lang) ~= "string" then
        ok, lang = pcall(function() return require("gettext").current_lang end)
    end
    local l = (ok and type(lang) == "string" and lang:sub(1, 2):lower() == "de") and "de" or "en"
    local s = strings[l][key] or strings.en[key] or key
    if select("#", ...) > 0 then return string.format(s, ...) end
    return s
end

-- ── Einstellungen ────────────────────────────────────────────────────────────────────────────────
local MODES = { "off", "keep", "on" }

local function mode()
    local m = G_reader_settings:readSetting("wifiwhilecharging_mode")
    if m == "off" or m == "keep" or m == "on" then return m end
    return "keep"
end

-- Sekunden nach dem Einstecken: Ein USB-Kabel fragt erst nach dem Datentraeger-Modus
-- (KOReader schliesst dann alles), nur reines Laden soll etwas einschalten.
local PLUG_DELAY = 15

local function isCharging()
    local ok, charging = pcall(function()
        local powerd = Device:getPowerDevice()
        return powerd and powerd:isCharging()
    end)
    return ok and charging and true or false
end

-- Flugmodus des Plugins AirPlaneMode (kodermike/airplanemode.koplugin): an, wenn seine Sicherung
-- der KOReader-Einstellungen existiert und "airplanemode_enabled" gesetzt ist.
local function airplaneMode()
    local ok, on = pcall(function()
        local DataStorage = require("datastorage")
        local lfs = require("libs/libkoreader-lfs")
        local dir = DataStorage:getDataDir()
        local file = dir .. "/settings/airplanemode.lua"
        if lfs.attributes(dir .. "/settings.reader.lua.airplane", "mode") ~= "file"
            or lfs.attributes(file, "mode") ~= "file" then
            return false
        end
        return require("luasettings"):open(file):isTrue("airplanemode_enabled")
    end)
    return ok and on or false
end

-- ── Eingriff in KOReaders Inaktivitaets-Pruefung ─────────────────────────────────────────────────
local hook_ok -- nil: noch nicht versucht, true/false: Ergebnis

local function shouldKeep()
    return mode() ~= "off" and isCharging()
end

local function installHook()
    if hook_ok ~= nil then return hook_ok end
    local ok, NetworkListener = pcall(require, "ui/network/networklistener")
    if not ok or type(NetworkListener) ~= "table" or type(NetworkListener._getTxPackets) ~= "function" then
        logger.info("WifiWhileCharging: KOReader's Wi-Fi activity check not found, not hooking in")
        hook_ok = false
        return false
    end
    local orig = NetworkListener._getTxPackets
    NetworkListener._getTxPackets = function(...)
        -- "Keine Messung": KOReader ueberspringt die Pruefung und fragt spaeter wieder.
        local keep_ok, keep = pcall(shouldKeep)
        if keep_ok and keep then
            logger.dbg("WifiWhileCharging: plugged in, skipping the inactivity check")
            return nil
        end
        return orig(...)
    end
    hook_ok = true
    return true
end

-- ── Einschlafen am Kabel ─────────────────────────────────────────────────────────────────────────
-- Schlaeft der E-Reader nach der eingestellten Zeit von selbst ein, schaltet KOReader vorher das
-- WLAN aus, auch am Kabel (der Kobo lehnt das Schlafen am Kabel dann zwar ab, das WLAN ist aber
-- weg). Am Kabel pausiert das Plugin deshalb das Einschlafen ueber KOReaders eigenen Schalter
-- (PluginShare.pause_auto_suspend). Huelle zuklappen und Einschaltknopf wirken weiter.
local suspend_paused = false

local function updateAutoSuspend()
    local ok, PluginShare = pcall(require, "pluginshare")
    if not ok or type(PluginShare) ~= "table" then return end
    local want = shouldKeep()
    if want and not suspend_paused and not PluginShare.pause_auto_suspend then
        PluginShare.pause_auto_suspend = true
        suspend_paused = true
    elseif not want and suspend_paused then
        -- Nur zuruecknehmen, was wir selbst gesetzt haben
        PluginShare.pause_auto_suspend = false
        suspend_paused = false
    end
end

-- ── Plugin ───────────────────────────────────────────────────────────────────────────────────────
local WifiWhileCharging = WidgetContainer:extend{
    name = "wifiwhilecharging",
}

-- Fuer Tests
WifiWhileCharging.shouldKeep = shouldKeep
WifiWhileCharging.airplaneMode = airplaneMode
WifiWhileCharging.PLUG_DELAY = PLUG_DELAY
WifiWhileCharging.updateAutoSuspend = updateAutoSuspend

function WifiWhileCharging:init()
    if not Device:hasWifiToggle() then return end
    installHook()
    updateAutoSuspend()
    -- Unser Eintrag direkt unter KOReaders "WLAN-Verbindung bei Inaktivitaet trennen"
    for _, file in ipairs({ "ui/elements/reader_menu_order", "ui/elements/filemanager_menu_order" }) do
        local ok, order = pcall(require, file)
        local network = ok and type(order) == "table" and order.network
        if type(network) == "table" and not util.arrayContains(network, "wifiwhilecharging") then
            local pos = util.arrayContains(network, "network_powersave")
            table.insert(network, pos and pos + 1 or #network + 1, "wifiwhilecharging")
        end
    end
    self.ui.menu:registerToMainMenu(self)
end

--- Darf das Plugin das WLAN jetzt einschalten?
function WifiWhileCharging:mayTurnOn()
    if mode() ~= "on" or not isCharging() then return false end
    if NetworkMgr:isWifiOn() then return false end
    -- Von Hand ausgeschaltet: KOReader setzt wifi_was_on dann auf false.
    if G_reader_settings:isFalse("wifi_was_on") then return false end
    if airplaneMode() then return false end
    return true
end

function WifiWhileCharging:turnOnIfWanted()
    if not self:mayTurnOn() then return end
    logger.info("WifiWhileCharging: plugged in, turning Wi-Fi on")
    UIManager:show(InfoMessage:new{ text = T("turning_on"), timeout = 2 })
    NetworkMgr:enableWifi()
end

function WifiWhileCharging:onCharging()
    updateAutoSuspend()
    if mode() ~= "on" then return end
    if self.plug_task then UIManager:unschedule(self.plug_task) end
    self.plug_task = function()
        self.plug_task = nil
        self:turnOnIfWanted()
    end
    UIManager:scheduleIn(PLUG_DELAY, self.plug_task)
end

function WifiWhileCharging:onNotCharging()
    if self.plug_task then
        UIManager:unschedule(self.plug_task)
        self.plug_task = nil
    end
    updateAutoSuspend()
end

function WifiWhileCharging:onCloseWidget()
    if self.plug_task then
        UIManager:unschedule(self.plug_task)
        self.plug_task = nil
    end
end

function WifiWhileCharging:addToMainMenu(menu_items)
    local mode_items = {}
    for _, m in ipairs(MODES) do
        mode_items[#mode_items + 1] = {
            text = T("mode_" .. m),
            help_text = T("mode_" .. m .. "_help"),
            radio = true,
            checked_func = function() return mode() == m end,
            callback = function()
                G_reader_settings:saveSetting("wifiwhilecharging_mode", m)
                updateAutoSuspend()
            end,
        }
    end
    mode_items[#mode_items].separator = true
    -- Hinweis nur, wenn er zutrifft
    local note = hook_ok == false and "no_hook"
    if note then
        mode_items[#mode_items + 1] = {
            text = T(note),
            help_text = T(note .. "_help"),
            keep_menu_open = true,
            callback = function() UIManager:show(InfoMessage:new{ text = T(note .. "_help") }) end,
        }
    end
    mode_items[#mode_items + 1] = {
        text = T("about"),
        keep_menu_open = true,
        callback = function() UIManager:show(InfoMessage:new{ text = T("about_text") }) end,
    }
    menu_items.wifiwhilecharging = {
        text_func = function() return T("menu_title", T("state_" .. mode())) end,
        sorting_hint = "network",
        sub_item_table = mode_items,
    }
end

return WifiWhileCharging
