-- Test (25.10.2026): WLAN beim Laden. Spielt KOReaders Inaktivitaets-Pruefung mit nachgestellten
-- Paketzahlen durch (wie im Story-Recall-Test), dazu Ladekabel, Stufen, Einschalten beim Einstecken,
-- "von Hand ausgeschaltet", Flugmodus (AirPlaneMode) und den Menueeintrag. Laeuft mit und ohne
-- Story Recall (beide haengen sich in dieselbe Pruefung ein).
local UIManager = require("ui/uimanager")
local NetworkMgr = require("ui/network/manager")
local DataStorage = require("datastorage")
local OUT = os.getenv("WWC_TEST_OUT") or "."
local f = io.open(OUT .. "/wwc-results.txt", "w")
local function log(...) local p = {} for i = 1, select("#", ...) do p[#p+1] = tostring(select(i, ...)) end f:write(table.concat(p, " ") .. "\n"); f:flush() end
local function check(n, ok) log(ok and "PASS" or "FAIL", n) end

-- Der Emulator hat kein WLAN-Schalten: fuer den Test so tun als ob (wie auf dem Kobo)
local Device = require("device")
Device.hasWifiToggle = function() return true end
package.loaded["ui/network/networklistener"] = nil
local NetworkListener = require("ui/network/networklistener")

local stub = function() return 40 end
NetworkListener._getTxPackets = stub
local disabled, enabled = 0, 0
local wifi_on = true
NetworkMgr.disableWifi = function() disabled = disabled + 1 end
NetworkMgr.enableWifi = function() enabled = enabled + 1 end
NetworkMgr.isWifiOn = function() return wifi_on end

local charging = false
local powerd = Device:getPowerDevice()
powerd.isCharging = function() return charging end

local function round(last)
    NetworkListener._last_tx_packets = last
    NetworkListener._activity_check_delay_seconds = nil
    NetworkListener:_scheduleActivityCheck()
    UIManager:unschedule(NetworkListener._scheduleActivityCheck)
end

local function setMode(m) G_reader_settings:saveSetting("wifiwhilecharging_mode", m) end

UIManager:scheduleIn(4, function()
  local ok, e = pcall(function()
    local ui = require("apps/reader/readerui").instance
    local p = ui.wifiwhilecharging
    check("Plugin geladen", p ~= nil)
    check("haengt sich in die Pruefung ein", NetworkListener._getTxPackets ~= stub)
    local sr = ui.storyrecall
    if sr and sr.processor then sr.processor:stop("idle") end
    log("INFO Story Recall installiert:", sr ~= nil)

    -- Standard ist "anlassen"
    G_reader_settings:delSetting("wifiwhilecharging_mode")
    charging = false
    round(40)
    check("ohne Kabel: WLAN wird abgeschaltet", disabled == 1)
    charging = true
    round(40)
    check("am Kabel (Standard anlassen): WLAN bleibt an", disabled == 1)
    setMode("off")
    round(40)
    check("Stufe aus: am Kabel wird abgeschaltet", disabled == 2)
    setMode("keep")
    round(40)
    check("Stufe anlassen: bleibt an", disabled == 2)

    -- Abziehen: normale Regel (erste Runde misst, zweite schaltet ab)
    charging = false
    round(nil)
    round(40)
    check("nach dem Abziehen wieder normal abgeschaltet", disabled == 3)

    -- Einschalten beim Einstecken
    wifi_on = false
    charging = true
    G_reader_settings:makeTrue("wifi_was_on")
    setMode("keep")
    p:onCharging()
    check("Stufe anlassen: Einstecken plant nichts", p.plug_task == nil)
    setMode("on")
    p:onCharging()
    check("Stufe einschalten: Einstecken plant das Einschalten", p.plug_task ~= nil)
    p:onNotCharging()
    check("vor Ablauf abgezogen: nichts geplant", p.plug_task == nil)
    p:onCharging()
    local task = p.plug_task
    UIManager:unschedule(task)
    task()
    check("nach der Wartezeit eingeschaltet", enabled == 1)

    wifi_on = true
    p:turnOnIfWanted()
    check("schon an: nicht nochmal eingeschaltet", enabled == 1)
    wifi_on = false
    G_reader_settings:makeFalse("wifi_was_on")
    p:turnOnIfWanted()
    check("von Hand ausgeschaltet: bleibt aus", enabled == 1)
    G_reader_settings:makeTrue("wifi_was_on")
    charging = false
    p:turnOnIfWanted()
    check("ohne Kabel: nicht eingeschaltet", enabled == 1)
    charging = true

    -- Flugmodus von AirPlaneMode
    local dir = DataStorage:getDataDir()
    local backup = dir .. "/settings.reader.lua.airplane"
    local apm = dir .. "/settings/airplanemode.lua"
    local fh = io.open(apm, "w"); fh:write('return { ["airplanemode_enabled"] = true }\n'); fh:close()
    check("Flugmodus-Datei ohne Sicherung zaehlt nicht", not p.airplaneMode())
    fh = io.open(backup, "w"); fh:write("return {}\n"); fh:close()
    check("Flugmodus erkannt", p.airplaneMode())
    p:turnOnIfWanted()
    check("Flugmodus: nicht eingeschaltet", enabled == 1)
    os.remove(backup); os.remove(apm)
    p:turnOnIfWanted()
    check("Flugmodus aus: eingeschaltet", enabled == 2)

    -- Zusammen mit Story Recall: beide halten unabhaengig
    if sr and sr.processor then
        wifi_on = true
        setMode("keep")
        charging = false
        sr.processor.state = "running"
        round(40)
        check("ohne Kabel, Story Recall arbeitet: bleibt an", disabled == 3)
        sr.processor.state = "idle"
        charging = true
        round(40)
        check("am Kabel, Story Recall ruht: bleibt an", disabled == 3)
        charging = false
        round(40)
        check("ohne Kabel, Story Recall ruht: abgeschaltet", disabled == 4)
    end

    -- Menue: Eintrag direkt unter "WLAN-Verbindung bei Inaktivitaet trennen"
    local order = require("ui/elements/reader_menu_order").network
    local util = require("util")
    local a, b = util.arrayContains(order, "network_powersave"), util.arrayContains(order, "wifiwhilecharging")
    check("Menue: direkt unter Inaktivitaet trennen", a and b == a + 1)
    local items = {}
    p:addToMainMenu(items)
    local m = items.wifiwhilecharging
    setMode("on")
    log("INFO Titel:", m.text_func())
    check("Menue: drei Stufen und Anleitung zuletzt", #m.sub_item_table == 4 and m.sub_item_table[4].text:find("?", 1, true) ~= nil)

    -- Einschlafen am Kabel pausiert (sonst schaltet KOReader vorher das WLAN aus)
    local PluginShare = require("pluginshare")
    charging = true
    setMode("keep")
    p.updateAutoSuspend()
    check("am Kabel: Einschlafen pausiert", PluginShare.pause_auto_suspend == true)
    charging = false
    p:onNotCharging()
    check("abgezogen: Einschlafen wieder normal", not PluginShare.pause_auto_suspend)
    charging = true
    p:onCharging()
    check("eingesteckt: wieder pausiert", PluginShare.pause_auto_suspend == true)
    setMode("off")
    m.sub_item_table[1].callback()
    check("Stufe aus (Menue): Einschlafen normal", not PluginShare.pause_auto_suspend)
    -- Hat ein anderes Plugin pausiert, nimmt dieses es nicht zurueck
    PluginShare.pause_auto_suspend = true
    setMode("keep")
    p.updateAutoSuspend()
    charging = false
    p:onNotCharging()
    check("fremde Pause bleibt stehen", PluginShare.pause_auto_suspend == true)
    PluginShare.pause_auto_suspend = false
    if p.plug_task then UIManager:unschedule(p.plug_task); p.plug_task = nil end
  end)
  if not ok then log("ERROR", e) end
  f:close()
  UIManager:quit()
end)
