local args = {...}

local argparse = require("argparse")
local lexer = require("lexer")
local parser = require("parser")

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

if #args == 0 then
    print(c(nil, colors.blue, "Basic C", true))
    print(c(nil, colors.red, "Usage: ", true) .. "basicc [options] <targetFile>")
    print("Use " .. c(nil, colors.green, "basicc --help") .. " for more information")
    return
end

local argKey = {
    o = {
        longname = "out",
        accept = 1
    },
    d = {
        longname = "ldump",
        accept = 1
    },
    long = {
        help = {
            desc = "Display this information"
        },
        out = {
            shortname = "o",
            desc = "Change the output file",
            extraSyntax = "<file>"
        },
        ldump = {
            shortname = "d",
            desc = "Output the lex dump",
            extraSyntax = "[outFile]"
        }
    }
}

local outArgs, warn = argparse.parse(args, argKey)
if #warn > 0 then
    print(warn)
end

if outArgs.help then
    print(c(nil, colors.blue, "Basic C", true))
    print(c(nil, colors.red, "Usage: ", true) .. "basicc [options] <targetFile>\n")
    argparse.printOp(argKey)
    return
end

if not outArgs.tla[1] then
    print(c(colors.red, colors.black, "FATAL:", true) .. c(nil, colors.red, " No input file", true))
    return
end

local fn = outArgs.tla[1]
local handle = io.open(fn, "r")
local data
if handle then
    data = handle:read("*a")
    handle:close()
else
    print(c(colors.red, colors.black, "FATAL:", true) .. c(nil, colors.red, " Input file does not exist, or is unaccessible", true))
    return
end

local flags = outArgs.d and 1 or 0
lexer.lex(data, flags)
parser.parse(data, flags)