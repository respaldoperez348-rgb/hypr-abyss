-- ==============================================================================
-- Aura Music Auto-Advance Hook for MPV
-- Dispatched immediately by MPV when a track finishes naturally (EOF or error)
-- ==============================================================================
local mp = require 'mp'

mp.register_event("end-file", function(event)
    -- eof: track reached the end
    -- error: track unplayable or network failed
    if event.reason == "eof" or event.reason == "error" then
        mp.msg.info("[Aura Music] Track finished with reason: " .. tostring(event.reason) .. ". Calling Quickshell next song...")
        os.execute("quickshell ipc call musicplayer autoNext &")
    end
end)
