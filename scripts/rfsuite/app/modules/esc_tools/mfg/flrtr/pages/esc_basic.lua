
local folder = "flrtr"
local ESC = assert(loadfile("app/modules/esc_tools/mfg/" .. folder .. "/init.lua"))()
local mspHeaderBytes = ESC.mspHeaderBytes
local mspSignature = ESC.mspSignature
local simulatorResponse = ESC.simulatorResponse


local mspapi = {
    api = {
        [1] = "ESC_PARAMETERS_FLYROTOR",
    },
    formdata = {
        labels = {
        },
        fields = {
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.cell_count"),       mspapi = 1, apikey = "cell_count"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.bec_voltage"),      mspapi = 1, apikey = "bec_voltage",    type = 1},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.motor_direction"),  mspapi = 1, apikey = "motor_direction", type = 1},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.soft_start"),       mspapi = 1, apikey = "soft_start"},
            {t = rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.fan_control"),      mspapi = 1, apikey = "fan_control", type = 1}
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
    mspapi=mspapi,
    eepromWrite = false,
    reboot = false,
    escinfo = escinfo,
    svFlags = 0,
    simulatorResponse =  simulatorResponse,
    postLoad = postLoad,
    navButtons = {menu = true, save = true, reload = true, tool = false, help = false},
    onNavMenu = onNavMenu,
    event = event,
    pageTitle = rfsuite.i18n.get("app.modules.esc_tools.name") .. " / " ..  rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.name") .. " / " .. rfsuite.i18n.get("app.modules.esc_tools.mfg.flrtr.basic"),
    headerLine = rfsuite.escHeaderLineText
}

