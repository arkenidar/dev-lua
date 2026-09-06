-- glossario.lua — generates the Markdown glossary tables from lessico.lua.
-- Run with:  lua5.4 glossario.lua

local lessico = dofile("lessico.lua")

local function ordina(t)
  local chiavi = {}
  for k in pairs(t) do chiavi[#chiavi + 1] = k end
  table.sort(chiavi)
  return chiavi
end

local function riga(a, b)
  return "| `" .. a .. "` | `" .. b .. "` |"
end

print("### Italian → English")
print()
print("| Italian | English |")
print("|---------|---------|")
for _, it in ipairs(ordina(lessico.it)) do
  print(riga(it, lessico.it[it]))
end

print()
print("### English → Italian")
print()
print("| English | Italian |")
print("|---------|---------|")
for _, en in ipairs(ordina(lessico.en)) do
  print(riga(en, lessico.en[en]))
end
