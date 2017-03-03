local parser = {}

local colors = {
    black   = 0,
    red     = 1,
    green   = 2,
    yellow  = 3,
    blue    = 4,
    magenta = 5,
    cyan    = 6,
    white   = 7
}

local function c(bg, fg, txt, bright)
    local bgt = bg and ((40 + bg) .. ";") or ""
    local fgt = fg and ((30 + fg) .. ";") or ""
    return "\27[" .. bgt .. fgt .. (bright and "1;" or "") .. "m" .. txt .. "\27[0m"
end

--[[
    {
        m = {
            longname = "message",
            accept = 1
        },
        long = {
            message = {
                shortname = "m"
            }
        }
    }
]]
function parser.parse(args, key)
    local out = {
        tla = {}
    }
    if not key.long then key.long = {} end
    local index = "tla"
    local numToAccept = math.huge
    local outWarn = ""
    for i=1, #args do
        local str = args[i]
        if str:sub(1, 2) == "--" then
            local ind = str:sub(3)
            if not key.long[ind] then
                outWarn = outWarn .. c(nil, colors.red, "WARN") .. ": Unknown option `" .. ind .. "'\n"
            end
            local nam = (key.long[ind] and key.long[ind].shortname) or ind
            if not out[nam] then
                out[nam] = {}
            end
            index = nam
            numToAccept = (key[index] and key[index].accept) or
                (key[index] and key[index].longname and key.long[key[index].longname] and
                key.long[key[index].longname].shortname) or 0
        elseif str:sub(1, 1) == "-" then
            local pack = str:sub(2)
            for op in pack:gmatch(".") do
                if not key[op] then
                    outWarn = outWarn .. c(nil, colors.red, "WARN") .. ": Unknown option `" .. op .. "'\n"
                end
                if not out[op] then
                    out[op] = {}
                end
                index = op
            end
            numToAccept = (key[index] and key[index].accept) or
                (key[index] and key[index].longname and key.long[key[index].longname] and
                key.long[key[index].longname].shortname) or 0
        else
            if numToAccept == 0 then
                index = "tla"
            end
            out[index][#out[index] + 1] = str
            numToAccept = numToAccept - 1
        end
    end

    return out, outWarn
end

function parser.printOp(key)
    print("Options:")
    for k, v in pairs(key.long) do
        local exs = (v.extraSyntax or (v.shortname and key[v.shortname] and key[v.shortname].extraSyntax) or "")
        if #exs > 0 then exs = " " .. exs end
        print("  " .. c(nil, colors.cyan, "--" .. k .. exs, true) .. ": " .. (v.desc or (v.shortname and key[v.shortname] and key[v.shortname].desc) or "No description"))
    end
    print("")
    for k, v in pairs(key) do
        if k ~= "long" then
            local exs = (v.extraSyntax or (v.longname and key.long[v.longname] and key.long[v.longname].extraSyntax) or "")
            if #exs > 0 then exs = " " .. exs end
            print("  " .. c(nil, colors.cyan, "-" .. k .. exs, true) .. ": " .. (v.desc or (v.longname and key.long[v.longname] and key.long[v.longname].desc) or "No description"))
        end
    end
end

return parser