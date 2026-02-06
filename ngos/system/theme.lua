local CONFIG_FILE = "/etc/theme.json"

local lib = {}

local presets = {
    standard = {
        bg = colors.gray,
        text = colors.white,
        header = colors.lightGray,
        headerText = colors.black,
        accent = colors.cyan,
        warn = colors.orange,
        err = colors.red
    },
    dark = {
        bg = colors.black,
        text = colors.white,
        header = colors.gray,
        headerText = colors.white,
        accent = colors.blue,
        warn = colors.yellow,
        err = colors.red
    },
    ocean = {
        bg = colors.blue,
        text = colors.white,
        header = colors.lightBlue,
        headerText = colors.black,
        accent = colors.yellow,
        warn = colors.orange,
        err = colors.red
    },
    hacker = {
        bg = colors.black,
        text = colors.lime,
        header = colors.green,
        headerText = colors.black,
        accent = colors.lime,
        warn = colors.red,
        err = colors.red
    },
    retro = {
        bg = colors.lightGray,
        text = colors.black,
        header = colors.gray,
        headerText = colors.white,
        accent = colors.blue,
        warn = colors.red,
        err = colors.red
    }
}

lib.colors = presets.standard

function lib.load()
    if fs.exists(CONFIG_FILE) then
        local f = fs.open(CONFIG_FILE, "r")
        local data = textutils.unserializeJSON(f.readAll())
        f.close()
        if data then 
            lib.colors = data
        end
    end
end

function lib.save(data)
    lib.colors = data

    local f = fs.open(CONFIG_FILE, "w")
    f.write(textutils.serializeJSON(data))
    f.close()
end

function lib.getPreset(name)
    return presets[name] or presets.standard
end

function lib.listPresets()
    return keys(presets)
end

return lib