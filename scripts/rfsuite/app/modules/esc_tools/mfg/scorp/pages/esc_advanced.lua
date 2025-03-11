

local folder = "scorp"

local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_SCORPION",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.soft_start_time"),     mspapi=1, apikey="soft_start_time"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.runup_time"),          mspapi=1, apikey="runup_time"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.bailout"),             mspapi=1, apikey="bailout"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.gov_proportional"),    mspapi=1, apikey="gov_proportional"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.gov_integral"),        mspapi=1, apikey="gov_integral"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.motor_startup_sound"), mspapi=1, apikey="motor_startup_sound", type = 1, },
        }
    }                 
}


local foundEsc = false
local foundEscDone = false

function postLoad()
    rfsuite.app.triggers.closeProgressLoader = true
end

local function onNavMenu(self)
    rfsuite.app.triggers.escToolEnableButtons = true
    rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
end

local function event(widget, category, value, x, y)
    
    if category == 5 or value == 35 then
        rfsuite.app.ui.openPage(pidx, folder, "esc_tools/esc_tool.lua")
        return true
    end

    return false
end

return {
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    preSavePayload = function(payload)
        payload[2] = 0
        return payload
    end,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.advanced"),
    headerLine = rfsuite.escHeaderLineText,
    extraMsgOnSave = rfsuite.i18n.get("app.modules.esc_tools.mfg.scorp.extra_msg_save"), 
}
