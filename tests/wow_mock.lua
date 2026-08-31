-- A deliberately small WoW API surface: just enough for the addon's Lua
-- files to load and run outside the game client. Extend as new files need
-- more of the API, the same way Larias' own wow_mock.lua grew.
local Harness = { now = 1000 }

local Frame = {}
Frame.__index = function(_, key)
    local method = Frame[key]
    if method then return method end
    -- Any WoW frame/widget method we haven't bothered to model: record the
    -- call and return self, so chained calls on unmocked API don't error.
    return function(frameObj, ...)
        frameObj.calls[key] = { ... }
        return frameObj
    end
end

function Frame:SetScript(name, callback) self.scripts[name] = callback end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:HookScript(name, callback)
    local previous = self.scripts[name]
    self.scripts[name] = function(...)
        if previous then previous(...) end
        callback(...)
    end
end
function Frame:RegisterEvent(name) self.events[name] = true end
function Frame:UnregisterEvent(name) self.events[name] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(name) return self.events[name] == true end
function Frame:Show() self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end
function Frame:Hide() self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end
function Frame:IsShown() return self.shown == true end
function Frame:SetShown(value) if value then self:Show() else self:Hide() end end
function Frame:SetPoint(...) self.points = { ... } end
function Frame:GetPoint() return unpack(self.points or {}) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetAllPoints() self.points = { "ALL" } end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width or 100 end
function Frame:GetHeight() return self.height or 100 end
function Frame:GetLeft() return self.left or 0 end
function Frame:GetRight() return self.right or ((self.left or 0) + self:GetWidth()) end
function Frame:GetTop() return self.top or self:GetHeight() end
function Frame:GetBottom() return self.bottom or 0 end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetScale() return rawget(self, "scale") or 1 end
function Frame:GetEffectiveScale() return rawget(self, "scale") or 1 end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:GetAlpha() return rawget(self, "alpha") or 1 end
function Frame:SetText(text) self.text = text end
function Frame:SetFormattedText(fmt, ...) self.text = string.format(fmt, ...) end
function Frame:GetText() return self.text or "" end
function Frame:SetTextColor(r, g, b, a) self.textColor = { r, g, b, a } end
function Frame:SetColorTexture(r, g, b, a) self.color = { r, g, b, a } end
function Frame:SetVertexColor(r, g, b, a) self.color = { r, g, b, a } end
function Frame:GetThumbTexture() return self end
function Frame:SetMovable(value) self.movable = value end
function Frame:EnableMouse(value) self.mouseEnabled = value end
function Frame:SetMinMaxValues(minV, maxV) self.minValue, self.maxValue = minV, maxV end
function Frame:SetValueStep(step) self.step = step end
function Frame:SetValue(value)
    self.value = value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Frame:GetValue() return self.value end
function Frame:SetChecked(value) self.checked = value and true or false end
function Frame:GetChecked() return self.checked end
function Frame:RegisterForDrag() end
function Frame:RegisterForClicks() end
function Frame:StartMoving() self.moving = true end
function Frame:StopMovingOrSizing() self.moving = false end
function Frame:CreateTexture() return Harness.newFrame(self) end
function Frame:CreateFontString() return Harness.newFrame(self) end
function Frame:GetParent() return self.parent end
function Frame:GetObjectType() return self.objectType or "Frame" end
function Frame:Click(button)
    if self.scripts.OnClick then self.scripts.OnClick(self, button or "LeftButton") end
end
-- Fires a registered event straight through OnEvent, the same way the real
-- client would - use this in tests instead of poking internals directly.
function Frame:Fire(event, ...)
    if self.scripts.OnEvent then self.scripts.OnEvent(self, event, ...) end
end

function Harness.newFrame(parent, objectType)
    return setmetatable({
        [0] = true, -- LibWindow-1.1:Embed() only checks this is non-nil.
        objectType = objectType,
        parent = parent,
        shown = false,
        scripts = {},
        events = {},
        calls = {},
        points = {},
    }, Frame)
end

function Harness.installGlobals()
    Harness.frames = {}
    Harness.timers = {}
    Harness.chatMessages = {}
    Harness.unitClassToken = "EVOKER"
    Harness.specIndex = 1
    Harness.specID = 1468 -- Preservation
    Harness.inCombat = false
    Harness.inRaid = false

    _G.wipe = function(tbl) for key in pairs(tbl) do tbl[key] = nil end return tbl end
    _G.CreateFrame = function(objectType, name, parent)
        local frame = Harness.newFrame(parent, objectType)
        Harness.frames[#Harness.frames + 1] = frame
        if name then _G[name] = frame end
        return frame
    end
    _G.UIParent = Harness.newFrame(nil, "Frame")
    _G.UIParent.shown = true
    _G.UIParent:SetSize(1920, 1080)
    _G.GameTooltip = Harness.newFrame(_G.UIParent, "GameTooltip")
    _G.GetScreenWidth = function() return 1920 end
    _G.GetScreenHeight = function() return 1080 end
    _G.IsAltKeyDown = function() return false end
    _G.ChatFrame1 = { AddMessage = function() end }
    _G.SlashCmdList = {}
    _G.SOUNDKIT = {}
    _G.PlaySound = function() end

    _G.GetTime = function() return Harness.now end
    _G.time = function() return math.floor(Harness.now) end
    _G.date = function() return "2026-01-01" end

    _G.C_Timer = {
        After = function(delay, callback)
            Harness.timers[#Harness.timers + 1] = { delay = delay, callback = callback }
        end,
    }

    _G.UnitClass = function(unit)
        if unit == "player" then return "Evoker", Harness.unitClassToken end
        return nil
    end
    _G.GetSpecialization = function() return Harness.specIndex end
    _G.GetSpecializationInfo = function() return Harness.specID end
    _G.InCombatLockdown = function() return Harness.inCombat end
    _G.IsInRaid = function() return Harness.inRaid end

    _G.GetLocale = function() return "enUS" end
end

-- Runs queued C_Timer.After callbacks in FIFO order (delay is ignored - the
-- timer's own reschedule logic, not wall-clock time, is what's under test).
function Harness.fireNextTimer()
    if #Harness.timers == 0 then return false end
    local timer = table.remove(Harness.timers, 1)
    timer.callback()
    return true
end

function Harness.runTimers(limit)
    local count = 0
    while #Harness.timers > 0 do
        count = count + 1
        if limit and count > limit then error("timer limit exceeded") end
        Harness.fireNextTimer()
    end
end

function Harness.advanceTime(seconds)
    Harness.now = Harness.now + seconds
end

-- Finds the (anonymous, module-local) frame that registered a given event -
-- feature files keep their event frame in a file-local variable, so tests
-- reach it through the mock's frame registry instead.
function Harness.findFrameWithEvent(eventName)
    for _, frame in ipairs(Harness.frames) do
        if frame.events[eventName] then return frame end
    end
    return nil
end

-- Loads a single addon .lua file as if it were a TOC entry: `...` becomes
-- addonName, exactly like in the real client.
function Harness.load(addonName, path)
    local chunk, loadError = loadfile(path)
    if not chunk then error(loadError) end
    chunk(addonName)
end

return Harness
