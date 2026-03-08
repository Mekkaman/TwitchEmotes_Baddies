--Credit: https://github.com/Pewtro/TwitchEmotes_Solaris

---@diagnostic disable: deprecated
TwitchEmotes_Baddies = LibStub("AceAddon-3.0"):NewAddon("TwitchEmotes_Baddies", "AceConsole-3.0", "AceEvent-3.0")

--Init
function TwitchEmotes_Baddies:OnInitialize()

    TwitchEmotes_Baddies:SetAutoComplete(true)

    -- Initialize the animation system for animated emotes ()
    TwitchEmotes_Baddies_InitAnimator()

end
