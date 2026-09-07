local function split_int(text)
    assert( type(text) == "string" )
    local found = text:find("#")
    if found == nil then return nil end
    local suffix = text:sub(found + 1)
    if not suffix:match("^%d+$") then return nil end
    local uint = tonumber(suffix)
    local prefix = text:sub(1, found - 1)
    return uint, prefix
end

local uint, prefix

uint, prefix = split_int("text")
assert( uint == nil and prefix == nil )

uint, prefix = split_int("text#4")
assert( uint == 4 and prefix == "text" )

uint, prefix = split_int("text#-7")
assert( uint == nil and prefix == nil )

uint, prefix = split_int("123#456")
assert( uint == 456 and prefix == "123" )

uint, prefix = split_int("text#")
assert( uint == nil and prefix == nil )

uint, prefix = split_int("'text#3'")
assert( uint == nil and prefix == nil )