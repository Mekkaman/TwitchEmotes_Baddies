-- Lightweight animator that updates guildie emotes using TwitchEmotes helpers.
-- Relies on TwitchEmotes_Update frame and TwitchEmotesAnimator_OnUpdate already running.

local function isBaddiesPath(p)
  return p and (p:find("Interface\\AddOns\\TwitchEmotes_Baddies\\emotes") ~= nil)
end

-- Hook into TwitchEmotes' OnUpdate to ensure our emotes animate if present.
-- Most of the work is handled by TwitchEmotesAnimator_UpdateEmoteInFontString which already
-- scans for Interface\\AddOns\\TwitchEmotes\\Emotes paths. We extend it to also consider
-- our addon path by a tiny shim.

-- Save reference
local _orig_UpdateEmoteInFontString = TwitchEmotesAnimator_UpdateEmoteInFontString

if _orig_UpdateEmoteInFontString then
  TwitchEmotesAnimator_UpdateEmoteInFontString = function(fontstring, widthOverride, heightOverride)
    local txt = fontstring:GetText()
    if txt then
      -- First, run the original for TwitchEmotes paths
      _orig_UpdateEmoteInFontString(fontstring, widthOverride, heightOverride)

      -- Now, update Baddies paths if any
      for emoteTextureString in txt:gmatch("(|TInterface\\AddOns\\TwitchEmotes_Baddies\\emotes.-|t)") do
        local imagepath = emoteTextureString:match("|T(Interface\\AddOns\\TwitchEmotes_Baddies\\emotes.-%.tga).-|t")
        local animdata = TwitchEmotes_animation_metadata and TwitchEmotes_animation_metadata[imagepath]
        if animdata then
          local framenum = TwitchEmotes_GetCurrentFrameNum(animdata)
          -- Escape Lua pattern magic in the matched texture string so we can replace it literally
          local safePattern = emoteTextureString:gsub("([%^%$%(%)%%%._%[%]%*%+%-%?])", "%%%1")
          local replacement
          if widthOverride or heightOverride then
            replacement = TwitchEmotes_BuildEmoteFrameStringWithDimensions(imagepath, animdata, framenum, widthOverride or animdata.frameWidth, heightOverride or animdata.frameHeight)
          else
            replacement = TwitchEmotes_BuildEmoteFrameString(imagepath, animdata, framenum)
          end
          -- Replace only this occurrence to avoid reprocessing already-updated segments
          local nTxt = txt:gsub(safePattern, replacement, 1)
          if fontstring.messageInfo then
            fontstring.messageInfo.message = nTxt
          end
          fontstring:SetText(nTxt)
          txt = nTxt
        end
      end
    end
  end
end
