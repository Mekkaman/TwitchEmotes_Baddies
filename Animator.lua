--[[
TwitchEmotes_Baddies Animation System

A standalone animation engine for playing animated TGA sprite sheets.

============================================================================
HOW TO ADD ANIMATED EMOTES:
============================================================================

1. CREATE A TGA SPRITE SHEET
Use ffmpeg to convert a GIF to a vertical sprite sheet:

# First, check how many frames your GIF has:
ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 input.gif

# Then convert (replace <FRAMES> with frame count, <HEIGHT> with next power of 2):
# Heights: 64 (2 frames), 128 (3-4), 256 (5-8), 512 (9-16), 1024 (17-32), 2048 (33-64)
ffmpeg -i input.gif -vf "scale=32:32:flags=lanczos,tile=1x<FRAMES>,pad=32:<HEIGHT>:0:0:color=0x00000000" -c:v targa -pix_fmt bgra output.tga

Example for a 24-frame GIF (24 frames * 32px = 768px, pad to 1024):
ffmpeg -i meow.gif -vf "scale=32:32:flags=lanczos,tile=1x24,pad=32:1024:0:0:color=0x00000000" -c:v targa -pix_fmt bgra meow.tga

2. PLACE THE FILE
Copy the .tga file to: TwitchEmotes_Baddies/emotes/

3. REGISTER THE EMOTE (in Emotes.lua)

a) Add to TwitchEmotes_Baddies_Emoticons:
["mbroMeow"] = "mbroMeow",

b) Add to TwitchEmotes_Baddies_Emoticons_Pack (NO :28:28 suffix for animated!):
["mbroMeow"] = "Interface\\AddOns\\TwitchEmotes_Baddies\\emotes\\mbroMeow.tga",

c) Add to TwitchEmotes_Baddies_Animation_Metadata:
["Interface\\AddOns\\TwitchEmotes_Baddies\\emotes\\mbroMeow.tga"] = {
nFrames = 24,      -- number of frames in the sprite sheet
frameWidth = 32,   -- width of each frame in pixels
frameHeight = 32,  -- height of each frame in pixels
imageWidth = 32,   -- total image width (power of 2 >= frameWidth)
imageHeight = 1024, -- total image height (power of 2 >= nFrames * frameHeight)
framerate = 15     -- playback speed in frames per second
},

NON-SQUARE EMOTES:
For emotes with non-1:1 aspect ratios (e.g., wide emotes), frameWidth and frameHeight
can differ. The display will automatically scale to preserve aspect ratio.

Example for a 3:1 aspect ratio emote (96x32 frames):
["Interface\\AddOns\\TwitchEmotes_Baddies\\emotes\\wideEmote.tga"] = {
nFrames = 36,
frameWidth = 96,    -- wider than tall
frameHeight = 32,
imageWidth = 128,   -- next power of 2 >= 96
imageHeight = 2048, -- next power of 2 >= 36 * 32
framerate = 15
},

============================================================================
SPRITE SHEET FORMAT:
============================================================================

Frames are stacked VERTICALLY from top to bottom:

+--------+  <- y=0
| Frame 0|
+--------+  <- y=32
| Frame 1|
+--------+  <- y=64
| Frame 2|
+--------+
|  ...   |
+--------+
| Frame N|
+--------+
| Padding|  <- Empty space to reach power-of-2 height
+--------+  <- y=imageHeight (64, 128, 256, 512, 1024, or 2048)

============================================================================
]]

-- Animation timing variables
local Baddies_T = 0
local Baddies_TimeSinceLastUpdate = 0
local Baddies_UPDATE_INTERVAL = 0.033 -- ~30 FPS

-- WoW 12.0+ secret value check (prevents errors on protected UI strings)
local issecurevariable = issecurevariable or function() return false end
local issecretvalue = issecretvalue or function() return false end

-- Pattern to match Baddies emote textures in chat
local Baddies_TEXTURE_PATTERN = "(|TInterface\\AddOns\\TwitchEmotes_Baddies\\emotes\\.-|t)"
local Baddies_PATH_PATTERN = "|T(Interface\\AddOns\\TwitchEmotes_Baddies\\emotes\\.-%.tga).-|t"

--[[
Escape special pattern characters for use in gsub
@param str - The string to escape
@return The escaped string safe for pattern matching
]]
local function escapePattern(str)
return (str:gsub('%%', '%%%%')
:gsub('%^', '%%^')
:gsub('%$', '%%$')
:gsub('%(', '%%(')
:gsub('%)', '%%)')
:gsub('%.', '%%.')
:gsub('%[', '%%[')
:gsub('%]', '%%]')
:gsub('%*', '%%*')
:gsub('%+', '%%+')
:gsub('%-', '%%-')
:gsub('%?', '%%?'))
end

--[[
Calculate the current frame number based on elapsed time and framerate
@param animdata - Animation metadata table
@return Current frame number (0-indexed)
]]
function TwitchEmotes_Baddies_GetCurrentFrameNum(animdata)
if animdata.pingpong then
  -- Pingpong mode: play forward then backward
  local totalFrames = (animdata.nFrames * 2) - 1
  local virtualFrame = math.floor((Baddies_T * animdata.framerate) % totalFrames)
  if virtualFrame >= animdata.nFrames then
    return animdata.nFrames - (virtualFrame % animdata.nFrames) - 1
    end
    return virtualFrame
    end

    return math.floor((Baddies_T * animdata.framerate) % animdata.nFrames)
    end

    --[[
    Get texture coordinates for a specific frame
    @param animdata - Animation metadata table
    @param framenum - Frame number (0-indexed)
    @return left, right, top, bottom texture coordinates (0-1 range)
    ]]
    function TwitchEmotes_Baddies_GetTexCoordsForFrame(animdata, framenum)
    local right = animdata.frameWidth / animdata.imageWidth
    local top = (framenum * animdata.frameHeight) / animdata.imageHeight
    local bottom = ((framenum + 1) * animdata.frameHeight) / animdata.imageHeight
    return 0, right, top, bottom
    end

    --[[
    Build a WoW texture escape sequence string for a specific animation frame
    @param imagepath - Full path to the TGA file
    @param animdata - Animation metadata table
    @param framenum - Frame number (0-indexed)
    @param width - Display width (optional, defaults to frameWidth)
    @param height - Display height (optional, defaults to frameHeight)
    @return Texture escape sequence string like "|Tpath:w:h:...|t"
    ]]
    function TwitchEmotes_Baddies_BuildEmoteFrameString(imagepath, animdata, framenum, width, height)
    local top = framenum * animdata.frameHeight
    local bottom = top + animdata.frameHeight
    local displayWidth = width or animdata.frameWidth
    local displayHeight = height or animdata.frameHeight

    -- Format: |Tpath:height:width:offsetX:offsetY:texW:texH:left:right:top:bottom|t
    -- Note: WoW uses height:width order, not width:height
    return "|T" .. imagepath .. ":" .. displayHeight .. ":" .. displayWidth
    .. ":0:0:" .. animdata.imageWidth .. ":" .. animdata.imageHeight
    .. ":0:" .. animdata.frameWidth .. ":" .. top .. ":" .. bottom .. "|t"
    end

    --[[
    Update animated emotes within a font string (chat message line)
    Finds all Baddies emote textures and updates their texture coordinates
    to display the current animation frame.

    @param fontstring - The font string widget to update
    @param widthOverride - Display width for emotes
    @param heightOverride - Display height for emotes
    ]]
    function TwitchEmotes_Baddies_UpdateEmoteInFontString(fontstring, widthOverride, heightOverride)
    local txt = fontstring:GetText()
    if not txt then return end

      -- WoW 12.0+: Skip secret/protected values to avoid taint errors
      if issecretvalue(txt) == true then
        return
        end

        -- Find all Baddies emote textures in the text
        for emoteTextureString in txt:gmatch(Baddies_TEXTURE_PATTERN) do
          -- Extract the image path from the texture string
          local imagepath = emoteTextureString:match(Baddies_PATH_PATTERN)

          if imagepath then
            -- Check if this emote has animation metadata
            local animdata = TwitchEmotes_Baddies_Animation_Metadata and
            TwitchEmotes_Baddies_Animation_Metadata[imagepath]

            if animdata then
              -- Calculate display dimensions preserving aspect ratio
              local baseHeight = heightOverride or 28
              local displayHeight = baseHeight
              local displayWidth
              if widthOverride then
                displayWidth = widthOverride
                else
                  local aspectRatio = animdata.frameWidth / animdata.frameHeight
                  displayWidth = math.floor(baseHeight * aspectRatio)
                  end

                  -- Calculate current frame and build new texture string
                  local framenum = TwitchEmotes_Baddies_GetCurrentFrameNum(animdata)
                  local newTextureString = TwitchEmotes_Baddies_BuildEmoteFrameString(
                    imagepath, animdata, framenum, displayWidth, displayHeight
                  )

                  -- Replace the old texture string with the new one
                  local newTxt = txt:gsub(escapePattern(emoteTextureString), newTextureString)

                  -- Update the message info if this is a chat message (for proper scrolling)
                  if fontstring.messageInfo then
                    fontstring.messageInfo.message = newTxt
                    end

                    fontstring:SetText(newTxt)
                    txt = newTxt
                    end
                    end
                    end
                    end

                    --[[
                    Main animation update function, called every frame by the update handler
                    @param self - The frame receiving OnUpdate
                    @param elapsed - Time since last frame in seconds
                    ]]
                    function TwitchEmotes_Baddies_Animator_OnUpdate(self, elapsed)
                    -- Accumulate time
                    Baddies_T = Baddies_T + elapsed
                    Baddies_TimeSinceLastUpdate = Baddies_TimeSinceLastUpdate + elapsed

                    -- Only update visuals at target FPS to save performance
                    if Baddies_TimeSinceLastUpdate < Baddies_UPDATE_INTERVAL then
                      return
                      end
                      Baddies_TimeSinceLastUpdate = 0

                      -- Update animated emotes in all visible chat windows
                      if CHAT_FRAMES then
                        for _, frameName in pairs(CHAT_FRAMES) do
                          local frame = _G[frameName]
                          if frame and frame:IsShown() and frame.visibleLines then
                            for _, visibleLine in ipairs(frame.visibleLines) do
                              -- Skip lines being hovered (handled separately by parent addon if needed)
                              TwitchEmotes_Baddies_UpdateEmoteInFontString(visibleLine, nil, nil)
                              end
                              end
                              end
                              end

                              -- Update animated emotes in autocomplete suggestion list
                              if EditBoxAutoCompleteBox and EditBoxAutoCompleteBox:IsShown() and
                                EditBoxAutoCompleteBox.existingButtonCount then
                                for i = 1, EditBoxAutoCompleteBox.existingButtonCount do
                                  local btn = EditBoxAutoComplete_GetAutoCompleteButton and
                                  EditBoxAutoComplete_GetAutoCompleteButton(i)
                                  if btn and btn:IsVisible() then
                                    TwitchEmotes_Baddies_UpdateEmoteInFontString(btn, nil, 16)
                                    else
                                      break
                                      end
                                      end
                                      end
                                      end

                                      --[[
                                      Initialize the animation system
                                      Creates an update frame that drives the animation loop
                                      ]]
                                      function TwitchEmotes_Baddies_InitAnimator()
                                      -- Create a frame to receive OnUpdate events
                                      local animatorFrame = CreateFrame("Frame", "TwitchEmotes_Baddies_AnimatorFrame", UIParent)
                                      animatorFrame:SetScript("OnUpdate", TwitchEmotes_Baddies_Animator_OnUpdate)
                                      end
