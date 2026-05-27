--[[
    ╔══════════════════════════════════════════════════════╗
    ║         SYY  —  Remote Spy Loader  v1.0             ║
    ║  Carga SyyRemoteSpy.lua directamente desde GitHub   ║
    ╠══════════════════════════════════════════════════════╣
    ║  USO EN EJECUTOR:                                    ║
    ║                                                      ║
    ║    loadstring(game:HttpGet(                          ║
    ║      "https://raw.githubusercontent.com/             ║
    ║       itzstxx/NexusSpy/main/SyySpyLoader.lua"        ║
    ║    ))()                                              ║
    ╚══════════════════════════════════════════════════════╝
]]

local RAW_URL = "https://raw.githubusercontent.com/itzstxx/NexusSpy/main/SyyRemoteSpy.lua"

local source do
    local ok, result = pcall(function()
        return game:HttpGet(RAW_URL, true)
    end)
    if not ok or type(result) ~= "string" or #result < 10 then
        error("[SYY Spy Loader] No se pudo descargar SyyRemoteSpy.\n"..
              "  → URL: "..RAW_URL.."\n"..
              "  → Error: "..tostring(result), 2)
        return
    end
    source = result
end

local fn, compileErr = loadstring(source, "SyyRemoteSpy")
if not fn then
    error("[SYY Spy Loader] Error al compilar:\n  "..tostring(compileErr), 2)
    return
end

local ok2, runtimeErr = pcall(fn)
if not ok2 then
    error("[SYY Spy Loader] Error al ejecutar:\n  "..tostring(runtimeErr), 2)
    return
end

print("[SYY Spy Loader] RemoteSpy cargado — "..game.Players.LocalPlayer.Name)