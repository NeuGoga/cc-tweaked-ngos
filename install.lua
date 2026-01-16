local REPO_BASE = "https://raw.githubusercontent.com/NeuGoga/cc-tweaked-ngos/main/"
local MANIFEST_URL = REPO_BASE .. "os_manifest.json"

term.setBackgroundColor(colors.black)
term.setTextColor(colors.cyan)
term.clear()
term.setCursorPos(1, 1)
print("Installing NgOS...")
print("==================")

local dirs = {
    "/ngos/system",
    "/ngos/bin",
    "/ngos/lib",
    "/apps",
    "/apps/Store",
    "/apps/Settings",
    "/etc",
    "/media"
}

for _, d in ipairs(dirs) do
    if not fs.exists(d) then fs.makeDir(d) end
end

term.setTextColor(colors.gray)
write("Fetching file list... ")
local resp = http.get(MANIFEST_URL)
if not resp then
    term.setTextColor(colors.red)
    print("FAILED")
    print("Check internet connection.")
    return
end

local manifest = textutils.unserializeJSON(resp.readAll())
resp.close()
term.setTextColor(colors.lime)
print("OK")

print("Downloading System Files:")
for localPath, remoteUrl in pairs(manifest.files) do
    term.setTextColor(colors.white)
    write(" > " .. fs.getName(localPath) .. " ")
    
    local d = http.get(remoteUrl)
    if d then
        local f = fs.open(localPath, "w")
        f.write(d.readAll())
        f.close()
        d.close()
        term.setTextColor(colors.lime)
        print("OK")
    else
        term.setTextColor(colors.red)
        print("ERR")
    end
end

term.setTextColor(colors.gray)
print("Configuring System...")

local info = {
    name = "NgOS",
    version = manifest.version,
    channel = "Stable",
    installDate = os.time("utc")
}
local f = fs.open("/etc/os.info", "w")
f.write(textutils.serializeJSON(info))
f.close()

local f = fs.open("/apps/Store/app.lua", "w")
f.write('dofile("/ngos/bin/store.lua")')
f.close()

local f = fs.open("/apps/Settings/app.lua", "w")
f.write('dofile("/ngos/bin/settings.lua")')
f.close()

if fs.exists("install.lua") then fs.delete("install.lua") end

term.setTextColor(colors.cyan)
print("\nInstallation Complete!")
print("Rebooting in 3 seconds...")
sleep(3)
os.reboot()