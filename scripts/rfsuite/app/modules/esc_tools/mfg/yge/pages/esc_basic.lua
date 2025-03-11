
local folder = "yge"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_YGE",
    },
    formdata = {
        labels = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.esc"), label = "esc1", inline_size = 40.6},
            {t = "", label = "esc2", inline_size = 40.6},
            {t = "", label = "esc3", inline_size = 40.6},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.limits"), label = "limits1", inline_size = 40.6},
            {t = "", label = "limits2", inline_size = 40.6},
            {t = "", label = "limits3", inline_size = 40.6},
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.esc_mode"),          inline = 1, label = "esc1", type = 1, mspapi = 1, apikey="governor"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.direction"),         inline = 1, label = "esc2", type = 1, mspapi = 1, apikey="direction"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.lv_bec_voltage"),    inline = 1, label = "esc3", mspapi = 1, apikey="lv_bec_voltage"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.auto_restart_time"), inline = 1, label = "limits1", type = 1, mspapi = 1, apikey="auto_restart_time"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.cell_cutoff"),      inline = 1, label = "limits2", type = 1, mspapi = 1, apikey="cell_cutoff"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.current_limit"),     inline = 1, label = "limits3", mspapi = 1, apikey="current_limit"},
        }
    }                 
}



function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)

    -- if close event detected go to section home page
    if category == EVT_CLOSE and value == 0 or value == 35 then
        if powercycleLoader then powercycleLoader:close() end
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end


end

local foundEsc = false
local foundEscDone = false

return {
    mspapi = mspapi,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.yge.basic"),
    headerLine = rfsuite.escHeaderLineText
}

