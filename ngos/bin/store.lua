local w, h = term.getSize()
local DATABASE_FILE = "/etc/installed.json"
local CATALOG_URL = "https://raw.githubusercontent.com/NeuGoga/cc-tweaked-ngos-apps/main/apps.json"

-- Colors
local C_BG = colors.black
local C_TAB_OFF = colors.gray
local C_TAB_ON = colors.cyan
local C_TEXT = colors.white
local C_ACCENT = colors.lime
local C_ERROR = colors.red

-- State
local currentTab = "install" 
local localData = {}  
local remoteData = {} 
local selectedApp = nil
local showModal = nil 

-- ==========================================
-- Data Management
-- ==========================================

local function loadLocalDB()
    if fs.exists(DATABASE_FILE) then
        local f = fs.open(DATABASE_FILE, "r")
        local data = f.readAll()
        f.close()
        localData = textutils.unserializeJSON(data) or {}
    else
        localData = {}
    end
end

local function saveLocalDB()
    local f = fs.open(DATABASE_FILE, "w")
    f.write(textutils.serializeJSON(localData))
    f.close()
end

local function fetchCatalog()
    term.setCursorPos(1, h)
    term.setBackgroundColor(colors.blue)
    term.clearLine()
    term.write(" Connecting to repository...")
    
    local response = http.get(CATALOG_URL)
    if response then
        local content = response.readAll()
        response.close()
        remoteData = textutils.unserializeJSON(content) or {}
    else
        remoteData = {}
    end
end

-- ==========================================
-- Installation / Removal Logic
-- ==========================================

local function performInstall(appEntry)
    term.setBackgroundColor(C_BG)
    term.clear()
    term.setCursorPos(1,1)
    print("Fetching manifest for " .. appEntry.name .. "...")
    
    local resp = http.get(appEntry.manifest)
    if not resp then 
        print("Error: Could not get manifest.")
        sleep(2)
        return 
    end
    
    local manifest = textutils.unserializeJSON(resp.readAll())
    resp.close()
    
    if not manifest or not manifest.files then
        print("Error: Invalid manifest format.")
        sleep(2)
        return
    end
    
    local installDir = "/apps/" .. appEntry.id
    if not fs.exists(installDir) then fs.makeDir(installDir) end
    
    print("Downloading files...")
    for localName, remoteUrl in pairs(manifest.files) do
        term.write(" - " .. localName .. " ")
        
        local fileResp = http.get(remoteUrl)
        if fileResp then
            local targetPath = fs.combine(installDir, localName)
            local parentDir = fs.getDir(targetPath)
            if not fs.exists(parentDir) then fs.makeDir(parentDir) end
            
            local f = fs.open(targetPath, "w")
            f.write(fileResp.readAll())
            f.close()
            fileResp.close()
            print("OK")
        else
            print("FAIL")
        end
    end
    
    -- Update Local DB
    localData[appEntry.id] = {
        name = appEntry.name,
        version = manifest.version,
        manifestUrl = appEntry.manifest
    }
    saveLocalDB()
    
    print("\nSuccess! App installed.")
    sleep(1)
end

local function performUninstall(appId)
    local dir = "/apps/" .. appId
    if fs.exists(dir) then
        fs.delete(dir)
    end
    localData[appId] = nil
    saveLocalDB()
end

-- ==========================================
-- UI Rendering
-- ==========================================

local function drawHeader()
    local leftBg = (currentTab == "install") and C_TAB_ON or C_TAB_OFF
    paintutils.drawFilledBox(1, 1, w/2, 3, leftBg)
    
    local rightBg = (currentTab == "installed") and C_TAB_ON or C_TAB_OFF
    paintutils.drawFilledBox((w/2)+1, 1, w, 3, rightBg)
    
    term.setCursorPos(math.floor(w/4)-4, 2)
    term.setBackgroundColor(leftBg)
    term.setTextColor(C_BG)
    term.write("Available")
    
    term.setCursorPos(math.floor(w*0.75)-4, 2)
    term.setBackgroundColor(rightBg)
    term.setTextColor(C_BG)
    term.write("Installed")
end

local function drawList()
    term.setBackgroundColor(C_BG)
    paintutils.drawFilledBox(1, 4, w, h, C_BG)
    
    local y = 5
    local listToDraw = {}
    
    if currentTab == "install" then
        for _, app in ipairs(remoteData) do
            if not localData[app.id] then
                table.insert(listToDraw, app)
            end
        end
    else
        for id, info in pairs(localData) do
            table.insert(listToDraw, {id=id, name=info.name, desc="v"..(info.version or "?")})
        end
    end
    
    if #listToDraw == 0 then
        term.setCursorPos(3, 6)
        term.setTextColor(colors.gray)
        if currentTab == "install" then
            term.write("No new apps found.")
        else
            term.write("No apps installed.")
        end
    end

    for i, app in ipairs(listToDraw) do
        term.setCursorPos(2, y)
        term.setBackgroundColor(C_BG)
        
        if selectedApp and selectedApp.id == app.id then
            term.setTextColor(C_ACCENT)
            term.write("> " .. app.name)
        else
            term.setTextColor(C_TEXT)
            term.write("  " .. app.name)
        end
        
        local btnText = ""
        if currentTab == "install" then
            btnText = "[ Install ]"
        else
            btnText = "[ Uninstall ]"
        end
        
        term.setCursorPos(w - #btnText - 1, y)
        term.setTextColor(currentTab == "install" and colors.blue or colors.red)
        term.write(btnText)
        
        app.btnX = w - #btnText - 1
        app.y = y
        y = y + 2
    end
    return listToDraw
end

local function drawModal()
    if not showModal then return end
    
    local bw, bh = 26, 8
    local bx, by = math.floor((w-bw)/2), math.floor((h-bh)/2)
    
    paintutils.drawFilledBox(bx, by, bx+bw, by+bh, colors.lightGray)
    
    term.setCursorPos(bx+2, by+2)
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    term.write(showModal.text)
    
    term.setCursorPos(bx+3, by+6)
    term.setBackgroundColor(colors.green)
    term.setTextColor(colors.white)
    term.write(" YES ")
    
    term.setCursorPos(bx+bw-8, by+6)
    term.setBackgroundColor(colors.red)
    term.write(" NO ")
end

-- ==========================================
-- Main Loop
-- ==========================================

loadLocalDB()
fetchCatalog()

while true do
    drawHeader()
    local visibleList = drawList()
    drawModal()
    
    local event, p1, p2, p3 = os.pullEvent()
    
    if event == "mouse_click" then
        local btn, x, y = p1, p2, p3
        
        if showModal then
            local bw, bh = 26, 8
            local bx, by = math.floor((w-bw)/2), math.floor((h-bh)/2)
            
            -- Modal Interaction
            if y == by+6 then
                if x >= bx+3 and x <= bx+7 then
                    showModal.onYes()
                    showModal = nil
                    -- Refresh Data
                    loadLocalDB()
                    selectedApp = nil
                elseif x >= bx+bw-8 and x <= bx+bw-4 then
                    showModal = nil
                end
            end
            
        elseif y <= 3 then
            -- Tab Interaction
            if x < w/2 then currentTab = "install" 
            else currentTab = "installed" end
            selectedApp = nil
            
        else
            for _, app in ipairs(visibleList) do
                if y == app.y then
                    selectedApp = app
                    
                    if x >= app.btnX then
                        if currentTab == "install" then
                            showModal = {
                                text = "Install " .. app.name .. "?",
                                onYes = function() performInstall(app) end
                            }
                        else
                            showModal = {
                                text = "Uninstall " .. app.name .. "?",
                                onYes = function() performUninstall(app.id) end
                            }
                        end
                    end
                end
            end
        end
    elseif event == "key" then
        -- Future update
    end
end