local lexer = {}

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

local Buffer = {}

function Buffer.new(str)
    local t = {str = str, pos = 1, c = str:sub(1, 1), line = 1, cpos = 1}
    setmetatable(t, {__index = Buffer})
    if t.c == "\n" then
        t.line = t.line + 1
        t.cpos = 0
    end

    return t
end

function Buffer:peek(n)
    n = n or 1
    return self.str:sub(self.pos + n, self.pos + n)
end

function Buffer:next()
    self.pos = self.pos + 1
    self.cpos = self.cpos + 1
    self.c = self.str:sub(self.pos, self.pos)
    if self.c == "\n" then
        self.line = self.line + 1
        self.cpos = 0
    end
    return self.c
end

function Buffer:skip(n)
    for i = 1, n do
        self:next()
    end
end

local keywords = {
    ["var"] = true,
    ["for"] = true,
    ["while"] = true,
    ["do"] = true,
    ["if"] = true,
    ["else"] = true
}
local function tokenizeKeyword(buffer, tokenList)
    for word, _ in pairs(keywords) do
        local currentChunk = ""
        for _ = #currentChunk + 1, #word do
            if currentChunk == word then
                tokenList[#tokenList + 1] = {currentChunk, "KEYWORD"}
                for _ = 1, #currentChunk do buffer:next() end
                return false
            end

            currentChunk = currentChunk .. buffer:peek(#currentChunk)

            if currentChunk == word then
                tokenList[#tokenList + 1] = {currentChunk, "KEYWORD"}
                for _ = 1, #currentChunk do buffer:next() end
                return false
            end
        end
    end
    return true
end

local function tokenizeIndentifier(buffer, tokenList)
    if buffer.c:match("[a-zA-Z]") then
        local strB = buffer.c
        while buffer:peek():match("[a-zA-Z0-9]") do
            strB = strB .. buffer:next()
        end
        buffer:next()
        tokenList[#tokenList + 1] = {strB, "IDENT"}
        return false
    end
    return true
end

local function tokenizeDelimiter(buffer, tokenList)
    if buffer.c:match("[%;%,%.]") then
        tokenList[#tokenList + 1] = {buffer.c, "DELIM"}
        buffer:next()
        return false
    elseif buffer.c:match("[%(%)]") then
        tokenList[#tokenList + 1] = {buffer.c, "PAREN"}
        buffer:next()
        return false
    elseif buffer.c:match("[%{%}]") then
        tokenList[#tokenList + 1] = {buffer.c, "BRACE"}
        buffer:next()
        return false
    end
    return true
end

-- TODO: Implement decimal numbers as they are
-- currently lexed as two numbers seperated by delim
local function tokenizeNumber(buffer, tokenList)
    local nmatch = buffer.str:match("^-?%d*%.?%d+", buffer.pos)

    if nmatch then
        buffer:skip(#nmatch)
        tokenList[#tokenList + 1] = {nmatch, "NUMBER"}
        return false
    end
    return true
end

local function tokenizeAssignment(buffer, tokenList)
    if buffer.c == "=" then
        tokenList[#tokenList + 1] = {buffer.c, "ASSIGN"}
        buffer:next()
        return false
    end
    return true
end

local function tokenizeComparison(buffer, tokenList)
    if buffer.c == "=" or buffer.c == "!" then
        if buffer:peek() == "=" then
            tokenList[#tokenList + 1] = {buffer.c .. "=", "COMPARE"}
            buffer:skip(2)
            return false
        end
        return true
    elseif buffer.c:match("[%<%>]") then
        local strB = buffer.c
        if buffer:peek() == "=" then
            strB = strB .. buffer:next()
        end
        tokenList[#tokenList + 1] = {strB, "COMPARE"}
        buffer:next()
        return false
    end
    return true
end

local function tokenizeArithmetic(buffer, tokenList)
    if buffer.c == "+" then
        local strB = buffer.c
        if buffer:peek() == "+" then
            strB = strB .. buffer:next()
            tokenList[#tokenList + 1] = {strB, "INCREMENT"}
            buffer:next()
            return false
        end
        tokenList[#tokenList + 1] = {strB, "PLUS"}
        buffer:next()
        return false
    elseif buffer.c == "-" then
        local strB = buffer.c
        if buffer:peek() == "-" then
            strB = strB .. buffer:next()
            tokenList[#tokenList + 1] = {strB, "DECREMENT"}
            buffer:next()
            return false
        end
        tokenList[#tokenList + 1] = {strB, "MINUS"}
        buffer:next()
        return false
    end
    return true
end

local function consumeComment(buffer, _)
    if buffer.c == "/" and buffer:peek() == "/" then
        while buffer.c ~= "\n" do
            buffer:next()
        end
        buffer:next()
        return false
    end
    return true
end

local function consumeWhitespace(buffer)
    while buffer.c:match("%s") do
        buffer:next()
    end
end

function lexer.lex(str, flags)
    flags = flags or 0

    local tokenList = {}
    local buffer = Buffer.new(str)

    local exitCode = 0
    local exitMessage
    while buffer.pos <= #str do
        consumeWhitespace(buffer)
        local BRK = true
        if BRK then BRK = consumeComment(buffer, tokenList) end
        if BRK then BRK = tokenizeKeyword(buffer, tokenList) end
        if BRK then BRK = tokenizeIndentifier(buffer, tokenList) end
        if BRK then BRK = tokenizeDelimiter(buffer, tokenList) end
        if BRK then BRK = tokenizeNumber(buffer, tokenList) end
        if BRK then BRK = tokenizeComparison(buffer, tokenList) end
        if BRK then BRK = tokenizeAssignment(buffer, tokenList) end
        if BRK then BRK = tokenizeArithmetic(buffer, tokenList) end

        if BRK then
            exitCode = 1
            exitMessage = c(colors.red, colors.black, "FATAL:", true) .. c(nil, colors.red, " Unexpected symbol near `"
                .. buffer.c .. "' at ln " .. buffer.line .. " col ".. buffer.cpos, true)
            break
        end
    end

    if bit32.band(flags, 1) > 0 then
        print(c(colors.magenta, colors.blue, "DEBUG LEXER DUMP", true))
        for i=1, #tokenList do
            print(tokenList[i][1] .. (" "):rep(20 - #tokenList[i][1]), c(nil, colors.green, tokenList[i][2], true))
        end
    end

    if exitCode ~= 0 then
        print(c(nil, colors.red, "Lexer exited with error code "..exitCode.." with the following message:"))
        print(exitMessage)
    end

    return tokenList
end

return lexer