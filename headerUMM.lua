---@diagnostic disable: lowercase-global, unused-local


----------------------------------------------------------------------------------
    	-- Callbacks --
----------------------------------------------------------------------------------

--[[
    opponentNoteMiss(id: number, noteData: number, noteType: string, isSustainNote: boolean)
    onTaunt(number: 1|2|3|4, character: "boyfriend" | "dad")
    onReceive(message: string, side: "left" | "right")
    onGameSet(winner: string, forfeit: boolean)
    onResultScreen()
    onResultsQuit()
    onResultStats(name: table, accuracy: table, misses: table, score: table, average: table)
        [1] - Left Player
        [2] - Right Player
--]]

----------------------------------------------------------------------------------
    	-- Variables --
----------------------------------------------------------------------------------

---True if you are hosting in online\
---multiplayer, and false otherwise.
---@type boolean
Hosting = nil;

---True if you are the opponent,\
---and false otherwise.
---@type boolean
leftSide = nil;

---True if you are in local multiplayer,\
---and false otherwise.
---@type boolean
localPlay = nil;

---True if you are in online multiplayer,\
---and false otherwise.
---@type boolean
onlinePlay = nil;

--- The version of the Unnamed Multiplayer,\
--- Mod, which is being used.
---@type number
UMMversion = nil;

----------------------------------------------------------------------------------
    	-- Functions --
----------------------------------------------------------------------------------

---Sends `message` to the other connected\
---player in online multiplayer.
---@param message string A message string to send
function send(message) end

---Sets `character`'s scale to `size`.
---@param character "boyfriend" | "dad" The character to resize
---@param size number The new size for the character
function characterRezise(character, size) end

---Flips `character` horizontally while making\
---sure all animations are offsetted correctly.\
---(Only works on custom characters due to the\
---use of left and right .json files)
---@param character "boyfriend" | "dad" The character to flip
function characterFlip(character) end