--!strict
-- MKN Suite • Server-Gated Bootstrapper

-- [[ 0. UNIVERSAL ANTICHEAT SHIELD ]]
pcall(function()
    local badGlobals = {
        "KrakenHub_Mahanakhon", "_KrakenHub_InitUI_Error", "_MahanakhonScriptId",
        "_DavinciVerified", "_DavinciVerifiedKey", "_DavinciKey", "_DavinciExpiresAt",
        "__MahanakhonKeyGate", "__MahanakhonRefreshAfterKey", "__MahanakhonMainStage",
        "__MahanakhonMainError"
    }
    for _, k in ipairs(badGlobals) do
        rawset(_G, k, nil)
    end

    local ls = game:GetService("LogService")
    if type(getconnections) == "function" then
        for _, conn in ipairs(getconnections(ls.MessageOut)) do
            pcall(function() conn:Disable() end)
        end
    end
    if type(hookfunction) == "function" and ls and ls.GetLogHistory then
        pcall(hookfunction, ls.GetLogHistory, function() return {} end)
    end

    local rs = game:GetService("ReplicatedStorage")
    local nsMod = rs:FindFirstChild("NetSeal")
    if not nsMod then return end
    local NetSeal = require(nsMod)
    local set_upval = debug.setupvalue or setupvalue
    local get_upvals = debug.getupvalues or getupvalues
    if not (set_upval and get_upvals) then return end

    local guard = get_upvals(NetSeal.fire)[1]
    if type(guard) == "function" then
        set_upval(guard, 1, function() return nil end)
    end

    local origSealFor = get_upvals(NetSeal.fire)[2]
    if type(origSealFor) ~= "function" then return end

    local function safeSealFor(remote: any, action: any, ...: any)
        if typeof(remote) == "Instance" or type(remote) == "table" then
            local rName = remote.Name
            if rName == "UiGuard" then
                if action == "Tool" or action == "Found" or action == "Log" or action == "Odd" or action == "Sink" then
                    error("ui_guard_drop", 0)
                elseif action == "Beat" then
                    return origSealFor(remote, "Beat", 0)
                elseif action == "Hands" then
                    local data = ...
                    local ride = (type(data) == "table" and data.ride) or 30
                    return origSealFor(remote, "Hands", {ride = ride, hands = ride, away = 0})
                elseif action == "Snap" then
                    local reqId, snap = ...
                    if type(snap) == "table" then
                        if type(snap.guis) == "table" then
                            local cleanGuis = {}
                            for _, g in ipairs(snap.guis) do
                                if type(g) == "table" and g.known and g.name ~= "Cascade" and g.name ~= "Container" and g.name ~= "PlateEditor" then
                                    table.insert(cleanGuis, g)
                                end
                            end
                            snap.guis = cleanGuis
                        end
                        if type(snap.logs) == "table" then
                            snap.logs = {}
                        end
                    end
                    return origSealFor(remote, "Snap", reqId, snap)
                end
            elseif rName == "PCX160Remote" or rName == "CarRemote" or rName == "KitCarRemote" or rName == "VehicleFxRemote" then
                if action == "Crash" or action == "HitPerson" or action == "Burst" or action == "Thud" or action == "Scrape" then
                    error("veh_crash_drop", 0)
                end
            end
        end
        return origSealFor(remote, action, ...)
    end

    set_upval(NetSeal.fire, 2, safeSealFor)
end)

local print = function(...) end
local warn = function(...) end

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local API_BASE = "http://154.197.69.87:8090"
local DISCORD_INVITE = "https://discord.gg/Rwa2Urzcd"
local LICENSE_FILE = "MahanakornAutoFarm/license.txt"

local reqFn = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request
if not reqFn then
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "MKN Suite",
            Text = "อุปกรณ์ไม่รองรับการเชื่อมต่อเครือข่าย",
            Duration = 6
        })
    end)
    return
end

local function getHwid(): string
    if type(gethwid) == "function" then
        local ok, hw = pcall(gethwid)
        if ok and type(hw) == "string" and #hw >= 8 then return hw end
    end
    local okCid, cid = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
    if okCid and type(cid) == "string" and #cid >= 8 then return cid end
    return "UID-" .. tostring(LocalPlayer.UserId)
end

local function cleanKey(raw: any): string
    local s = tostring(raw or ""):gsub("%s+", ""):gsub('"', ''):gsub("'", ""):gsub("`", ""):upper()
    if s:find("=") then
        s = s:match("=(.+)") or s
    end
    local m = s:match("(DVNC%-[%w%-_]+)")
    return m or s
end

local function getPresetKey(): string
    for _, v in ipairs({ _G and _G.Key, _G and _G.script_key, getgenv and getgenv().Key, getgenv and getgenv().script_key }) do
        if type(v) == "string" and v:gsub("%s+", "") ~= "" then
            local ck = cleanKey(v)
            if ck ~= "" then
                pcall(function() if _G then _G.Key = nil end end)
                return ck
            end
        end
    end
    return ""
end

local function getSavedKey(): string
    local saved = ""
    pcall(function()
        if readfile and isfile and isfile(LICENSE_FILE) then
            local raw = readfile(LICENSE_FILE)
            if raw:sub(1, 3) == "\239\187\191" then raw = raw:sub(4) end
            saved = cleanKey(raw)
        end
    end)
    return saved
end

local function tryFetchPayload(keyCode: string): (boolean, string?, string?)
    keyCode = cleanKey(keyCode)
    if keyCode == "" then return false, nil, "กรุณากรอกรหัสประจำตัว" end
    local authJson = HttpService:JSONEncode({ key = keyCode, hwid = getHwid(), place_version = (game.PlaceVersion or 0), ts = os.time(), nonce = HttpService:GenerateGUID(false) })
    local okAuth, resAuth = pcall(reqFn, {
        Url = API_BASE .. "/api/auth",
        url = API_BASE .. "/api/auth",
        Method = "POST",
        method = "POST",
        Headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
        headers = { ["Content-Type"] = "application/json", ["Accept"] = "application/json" },
        Body = authJson,
        body = authJson,
    })
    local sc = type(resAuth) == "table" and (resAuth.StatusCode or resAuth.status_code) or nil
    local resBodyRaw = type(resAuth) == "table" and (resAuth.Body or resAuth.body) or ""
    if not okAuth or type(resAuth) ~= "table" or sc ~= 200 then
        local errMsg = "การเชื่อมต่อล้มเหลว"
        if sc == 530 or sc == 502 or sc == 504 then
            errMsg = "เซิร์ฟเวอร์กำลังเชื่อมต่อ (" .. tostring(sc) .. ") กรุณากดใหม่อีกครั้ง"
        else
            pcall(function()
                local b = HttpService:JSONDecode(tostring(resBodyRaw or "{}"))
                if b and b.status then
                    local statusMap = {
                        key_expired = "รหัสนี้หมดอายุการใช้งานแล้ว",
                        key_banned = "รหัสนี้ถูกระงับการใช้งานถาวร",
                        invalid_key = "ไม่พบรหัสนี้ในระบบ กรุณาตรวจสอบอีกครั้ง",
                        hwid_mismatch = "HWID ไม่ตรงกับเครื่องที่ผูกไว้ กรุณากดรีเซ็ตในกลุ่ม",
                        key_not_activated = "รหัสนี้ยังไม่ได้เปิดใช้งาน กรุณาติดต่อในกลุ่ม",
                    }
                    errMsg = statusMap[b.status] or tostring(b.status)
                end
            end)
            if errMsg == "การเชื่อมต่อล้มเหลว" and sc then errMsg = "HTTP " .. tostring(sc) end
        end
        return false, nil, errMsg
    end
    local okJson, data = pcall(HttpService.JSONDecode, HttpService, tostring(resBodyRaw or "{}"))
    if not okJson or type(data) ~= "table" or not data.valid or not data.token then
        return false, nil, "ข้อมูลตอบกลับไม่ถูกต้อง"
    end
    pcall(function()
        if makefolder and isfolder and not isfolder("MahanakornAutoFarm") then makefolder("MahanakornAutoFarm") end
        if writefile then writefile(LICENSE_FILE, keyCode) end
    end)
    local scJson = HttpService:JSONEncode({ token = data.token, place_version = (game.PlaceVersion or 0) })
    local okScript, resScript = pcall(reqFn, {
        Url = API_BASE .. "/api/script",
        url = API_BASE .. "/api/script",
        Method = "POST",
        method = "POST",
        Headers = { ["Content-Type"] = "application/json" },
        headers = { ["Content-Type"] = "application/json" },
        Body = scJson,
        body = scJson,
    })
    local scCode = type(resScript) == "table" and (resScript.StatusCode or resScript.status_code) or nil
    local scPayload = type(resScript) == "table" and (resScript.Body or resScript.body) or ""
    if okScript and type(resScript) == "table" and scCode == 200 and type(scPayload) == "string" and #scPayload > 100 then
        return true, scPayload, nil
    end
    return false, nil, "ดาวน์โหลดข้อมูลระบบไม่สำเร็จ"
end

-- 1. Silent execution path (when _G.Key or saved key is available): NO UI
local presetKey = getPresetKey()
if presetKey == "" then presetKey = getSavedKey() end
if presetKey ~= "" then
    local ok, payload, errMsg = tryFetchPayload(presetKey)
    if ok and payload then
        pcall(function()
            if _G then _G.Key = nil end
        end)
        local fn, _ = loadstring(payload)
        if fn then
            task.spawn(fn)
        end
        return
    else
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "MKN Suite",
                Text = tostring(errMsg or "เข้าสู่ระบบไม่สำเร็จ"),
                Duration = 6
            })
        end)
        return
    end
end

-- 2. Interactive UI path (when NO key is saved): UiGuard-Safe UI
local CASCADE_URL = "https://github.com/cascadeui/Cascade/releases/download/v1.4.0/dist.luau"
local CASCADE_CACHE = "MahanakornAutoFarm/assets/cascade_v1.4.0.luau"
local function loadCascade()
    local src = nil
    if type(isfile) == "function" and type(readfile) == "function" then
        pcall(function()
            if isfile(CASCADE_CACHE) then
                local c = readfile(CASCADE_CACHE)
                if type(c) == "string" and #c > 100000 then src = c end
            end
        end)
    end
    if not src then
        src = game:HttpGet(CASCADE_URL)
        if type(makefolder) == "function" and type(writefile) == "function" and type(src) == "string" and #src > 100000 then
            pcall(function()
                if not isfolder("MahanakornAutoFarm") then makefolder("MahanakornAutoFarm") end
                if not isfolder("MahanakornAutoFarm/assets") then makefolder("MahanakornAutoFarm/assets") end
                writefile(CASCADE_CACHE, src)
            end)
        end
    end
    if src then
        src = string.gsub(src, "b%.ProtectUI%s*=%s*function%(c%)", "b.ProtectUI=function(c) c.Name='PlateEditor' c.DisplayOrder=15 ")
        src = string.gsub(src, "Name%s*=%s*'Cascade'", "Name='PlateEditor'")
        src = string.gsub(src, "DisplayOrder%s*=%s*200", "DisplayOrder=15")
        src = string.gsub(src, "DisplayOrder%s*=%s*201", "DisplayOrder=16")
        src = string.gsub(src, "Name%s*=%s*'Container'", "Name='PlateContainer'")
        src = string.gsub(src, "UIBlur%s*=%s*true", "UIBlur=false")
    end
    return loadstring(src)()
end

local Cascade = loadCascade()
local huiTarget = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")

pcall(function()
    local cam = workspace.CurrentCamera
    if cam then
        for _, child in ipairs(cam:GetChildren()) do
            if child:IsA("Folder") and child.Name == "Folder" then
                child:Destroy()
            end
        end
    end
end)

local typed = ""
local AuthApp = Cascade.New({
    WindowPill = false,
    Theme = Cascade.Themes.Dark,
    Accent = Cascade.Accents.Blue,
})

local AuthWin = AuthApp:Window({
    Title = "MKN Suite",
    Subtitle = "Client Access",
    Size = UDim2.fromOffset(540, 320),
    Searching = false,
    Draggable = true,
    Resizable = false,
    CanExit = true,
    CanMinimize = false,
    CanZoom = false,
    UIBlur = false,
    Dropshadow = true,
})

local AuthSec = AuthWin:Section({ Title = "Client Access", Disclosure = false, Expanded = true })
local Tab = AuthSec:Tab({ Title = "Authentication", Icon = Cascade.Symbols.shield, Selected = true })
local PageSec = Tab:PageSection({ Title = "Member Verification" })
local Form = PageSec:Form()

local statusRow = Form:Row({ SearchIndex = "Status" })
local StatusStack = statusRow:Left():TitleStack({ Title = "Status", Subtitle = "กรุณาระบุรหัสประจำตัวสมาชิกเพื่อเริ่มระบบ" })

local tokenRow = Form:Row({ SearchIndex = "Token" })
tokenRow:Left():TitleStack({ Title = "Access Code", Subtitle = "รหัสสิทธิ์การใช้งานของสมาชิก" })
local TokenInp = tokenRow:Right():TextField({
    Placeholder = "DVNC-XXXX-XXXX-XXXX",
    Value = typed,
    ValueChanged = function(_self, v) typed = v or "" end
})

local busy = false
local startRow = Form:Row({ SearchIndex = "Connect" })
startRow:Left():TitleStack({ Title = "Connect", Subtitle = "ตรวจสอบสิทธิ์และเริ่มการทำงาน" })
startRow:Right():Button({
    State = "Primary",
    Label = "เข้าสู่ระบบ",
    Pushed = function()
        if busy then return end
        busy = true
        local k = cleanKey(typed)
        pcall(function()
            if TokenInp.Structures and TokenInp.Structures.Field and type(TokenInp.Structures.Field.Text) == "string" and TokenInp.Structures.Field.Text ~= "" then
                k = cleanKey(TokenInp.Structures.Field.Text)
            elseif type(TokenInp.Value) == "string" and TokenInp.Value ~= "" then
                k = cleanKey(TokenInp.Value)
            end
        end)
        StatusStack.Subtitle = "กำลังตรวจสอบสิทธิ์กับเซิร์ฟเวอร์..."
        local ok, payload, errMsg = tryFetchPayload(k)
        if ok and payload then
            pcall(function()
                if _G then _G.Key = nil end
            end)
            StatusStack.Subtitle = "สำเร็จ! กำลังเปิดระบบ..."
            pcall(function()
                if AuthWin and AuthWin.__instance then AuthWin.__instance:Destroy() end
                if AuthWin and AuthWin.Structures and AuthWin.Structures.Window then AuthWin.Structures.Window:Destroy() end
                if AuthApp and AuthApp.Destroy then AuthApp:Destroy() end
                for _, v in ipairs(huiTarget:GetChildren()) do
                    if v.Name == "Cascade" or v.Name == "PlateEditor" then
                        pcall(function() v:Destroy() end)
                    end
                end
            end)
            local fn, _ = loadstring(payload)
            if fn then
                task.spawn(fn)
            end
        else
            StatusStack.Subtitle = "ไม่สำเร็จ: " .. tostring(errMsg)
            AuthApp:Notification({ Title = "Access Denied", Subtitle = tostring(errMsg), App = "MKN Suite", Duration = 4 })
        end
        busy = false
    end
})

if DISCORD_INVITE ~= "" then
    local dRow = Form:Row({ SearchIndex = "Community" })
    dRow:Left():TitleStack({ Title = "Community Support", Subtitle = "คัดลอกลิงก์กลุ่มเพื่อรับรหัสหรือติดต่อแอดมิน" })
    dRow:Right():Button({
        State = "Secondary",
        Label = "คัดลอกลิงก์กลุ่ม",
        Pushed = function()
            if type(setclipboard) == "function" then
                pcall(setclipboard, DISCORD_INVITE)
            end
            AuthApp:Notification({ Title = "คัดลอกเรียบร้อย", Subtitle = "คัดลอกลิงก์กลุ่มไปยังคลิปบอร์ดแล้ว", App = "MKN Suite", Duration = 4 })
        end
    })
end
