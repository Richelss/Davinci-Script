--!strict
-- Davinci.dev • Mahanakorn AutoFarm Server-Gated Bootstrapper
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local API_BASE = "http://154.197.69.87:8090"
local DISCORD_INVITE = "https://discord.gg/Rwa2Urzcd"
local LICENSE_FILE = "MahanakornAutoFarm/license.txt"

local reqFn = (syn and syn.request) or (http and http.request) or http_request or (Fluxus and Fluxus.request) or request
if not reqFn then
    warn("[Davinci.dev] Your executor does not support HTTP requests.")
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

local function readInitialKey(): string
    for _, v in ipairs({ _G and _G.Key, _G and _G.script_key, getgenv and getgenv().Key, getgenv and getgenv().script_key }) do
        if type(v) == "string" and v:gsub("%s+", "") ~= "" then return v:gsub("%s+", "") end
    end
    local saved = ""
    pcall(function()
        if readfile and isfile and isfile(LICENSE_FILE) then
            local raw = readfile(LICENSE_FILE)
            if raw:sub(1, 3) == "\239\187\191" then raw = raw:sub(4) end
            saved = raw:gsub("%s+", "")
        end
    end)
    return saved
end

local function tryFetchPayload(keyCode: string): (boolean, string?, string?)
    keyCode = tostring(keyCode or ""):gsub("%s+", ""):upper()
    if keyCode == "" then return false, nil, "Missing key" end
    local authJson = HttpService:JSONEncode({ key = keyCode, hwid = getHwid(), ts = os.time(), nonce = HttpService:GenerateGUID(false) })
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
        local errMsg = "Auth failed"
        if sc == 530 or sc == 502 or sc == 504 then
            errMsg = "เซิร์ฟเวอร์บอทกำลังเชื่อมต่อ (" .. tostring(sc) .. ") กรุณากด Load ใหม่อีกครั้ง"
        else
            pcall(function()
                local b = HttpService:JSONDecode(tostring(resBodyRaw or "{}"))
                if b and b.status then errMsg = tostring(b.status) end
            end)
            if errMsg == "Auth failed" and sc then errMsg = "HTTP " .. tostring(sc) end
        end
        return false, nil, errMsg
    end
    local okJson, data = pcall(HttpService.JSONDecode, HttpService, tostring(resBodyRaw or "{}"))
    if not okJson or type(data) ~= "table" or not data.valid or not data.token then
        return false, nil, "Invalid auth response"
    end
    if data.expires_at then
        if _G then _G._DavinciExpiresAt = tonumber(data.expires_at) or 0 end
    end
    pcall(function()
        if makefolder and isfolder and not isfolder("MahanakornAutoFarm") then makefolder("MahanakornAutoFarm") end
        if writefile then writefile(LICENSE_FILE, keyCode) end
    end)
    local scJson = HttpService:JSONEncode({ token = data.token })
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
    return false, nil, "Failed to download protected payload"
end

local keyNow = readInitialKey()
if keyNow ~= "" then
    local ok, payload = tryFetchPayload(keyNow)
    if ok and payload then
        if _G then
            _G.Key = keyNow
            _G._DavinciVerified = true
            _G._DavinciVerifiedKey = keyNow
        end
        local fn, err = loadstring(payload)
        if fn then task.spawn(fn) else warn("[Davinci.dev] Compile error: " .. tostring(err)) end
        return
    end
end

-- Interactive Cascade UI prompt if no valid cached/global key
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
    return loadstring(src)()
end
local Cascade = loadCascade()
pcall(function()
    local ugs = require(game:GetService("ReplicatedStorage"):WaitForChild("UiGuardShared", 3))
    if ugs then
        ugs.KNOWN["Cascade"] = true
        ugs.NOT_MARKED["Cascade"] = true
        ugs.SWEEP_SKIP["Cascade"] = true
    end
end)
local AuthApp = Cascade.New({
    WindowPill = false,
    Theme = Cascade.Themes.Dark,
    Accent = Cascade.Accents.Blue,
})
local AuthWin = AuthApp:Window({
    Title = "Davinci.dev",
    Subtitle = "Script Loader",
    Size = UDim2.fromOffset(540, 320),
    Searching = false,
    Draggable = true,
    Resizable = false,
    CanExit = true,
    CanMinimize = false,
    CanZoom = false,
    UIBlur = true,
    Dropshadow = true,
})
local AuthSec = AuthWin:Section({ Title = "Loader", Disclosure = false, Expanded = true })
local Tab = AuthSec:Tab({ Title = "Key System", Icon = Cascade.Symbols.key, Selected = true })
local PageSec = Tab:PageSection({ Title = "Activate Access" })
local Form = PageSec:Form()
local statusRow = Form:Row({ SearchIndex = "Status" })
local StatusStack = statusRow:Left():TitleStack({ Title = "Status", Subtitle = "กรุณากรอก License Key เพื่อโหลดสคริปต์" })
local typed = keyNow
local keyRow = Form:Row({ SearchIndex = "Key" })
keyRow:Left():TitleStack({ Title = "License Key" })
local KeyInp = keyRow:Right():TextField({
    Placeholder = "DVNC-XXXX-XXXX-XXXX",
    Value = keyNow,
    ValueChanged = function(_self, v) typed = v or "" end
})
local busy = false
local loadRow = Form:Row({ SearchIndex = "Load" })
loadRow:Left():TitleStack({ Title = "Load Script", Subtitle = "ยืนยันคีย์และดาวน์โหลดสคริปต์เข้าสู่ระบบ" })
loadRow:Right():Button({
    State = "Primary",
    Label = "Load",
    Pushed = function()
        if busy then return end
        busy = true
        local k = typed
        pcall(function()
            if KeyInp.Structures and KeyInp.Structures.Field and type(KeyInp.Structures.Field.Text) == "string" and KeyInp.Structures.Field.Text ~= "" then
                k = KeyInp.Structures.Field.Text
            elseif type(KeyInp.Value) == "string" and KeyInp.Value ~= "" then
                k = KeyInp.Value
            end
        end)
        StatusStack.Subtitle = "กำลังตรวจสอบสิทธิ์..."
        local ok, payload, errMsg = tryFetchPayload(k)
        if ok and payload then
            if _G then
                _G.Key = tostring(k or ""):gsub("%s+", ""):upper()
                _G._DavinciVerified = true
                _G._DavinciVerifiedKey = _G.Key
            end
            StatusStack.Subtitle = "สำเร็จ! กำลังเปิดสคริปต์..."
            pcall(function()
                if AuthWin and AuthWin.__instance then AuthWin.__instance:Destroy() end
                if AuthWin and AuthWin.Structures and AuthWin.Structures.Window then AuthWin.Structures.Window:Destroy() end
                if AuthApp and AuthApp.Destroy then AuthApp:Destroy() end
                local target = (type(gethui) == "function" and gethui()) or game:GetService("CoreGui")
                for _, v in ipairs(target:GetChildren()) do
                    if v.Name == "Cascade" then v:Destroy() end
                end
            end)
            local fn, cerr = loadstring(payload)
            if fn then task.spawn(fn) else warn("[Davinci.dev] Compile error: " .. tostring(cerr)) end
        else
            StatusStack.Subtitle = "ไม่สำเร็จ: " .. tostring(errMsg)
            AuthApp:Notification({ Title = "Access Denied", Subtitle = tostring(errMsg), App = "Davinci.dev", Duration = 4 })
        end
        busy = false
    end
})
if DISCORD_INVITE ~= "" then
    local dRow = Form:Row({ SearchIndex = "Discord" })
    dRow:Left():TitleStack({ Title = "Copy Discord Invite", Subtitle = "คัดลอกลิงก์ร้านค้าเพื่อซื้อ Key หรือ Reset HWID" })
    dRow:Right():Button({
        State = "Secondary",
        Label = "Copy Link",
        Pushed = function()
            if type(setclipboard) == "function" then pcall(setclipboard, DISCORD_INVITE) end
            AuthApp:Notification({ Title = "Copied", Subtitle = DISCORD_INVITE, App = "Davinci.dev", Duration = 4 })
        end
    })
end
