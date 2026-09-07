local contesto = {}
local valori = {}

-- local testo='scrivi_rigo#1 somma#2 5 prodotto#2 4 2'
-- valori={"scrivi_rigo#1","somma#2","5","prodotto#2","4","2"}

local function split_int(text)
    assert(type(text) == "string")
    local found = text:find("#")
    if found == nil then
        return nil
    end
    local suffix = text:sub(found + 1)
    if not suffix:match("^%d+$") then
        return nil
    end
    local uint = tonumber(suffix)
    local prefix = text:sub(1, found - 1)
    return uint, prefix
end

local function appendice(testo)
    return split_int(testo)
end

local function misura(indice)
    local valore = valori[indice]
    assert(type(valore) == "string")
    if valore == "do" then
        local cursore = indice
        cursore = cursore + 1
        while valori[cursore] ~= "end" do
            cursore = cursore + misura(cursore)
        end
        return cursore - indice + 1
    end
    local numero, prefisso = appendice(valore)
    if numero ~= nil and contesto[prefisso] ~= nil then
        local funzione = contesto[prefisso]
        local indici = {}
        local cursore = indice
        cursore = cursore + 1
        for variabile = 1, numero do
            indici[#indici + 1] = cursore
            cursore = cursore + misura(cursore)
        end
        return cursore - indice
    end
    if tonumber(valore) or tostring(valore) then
        return 1
    end
end

local fai

local function valuta(indice)
    local valore = valori[indice]
    assert(type(valore) == "string")
    if valore == "do" then
        return fai(indice)
    end
    local numero, prefisso = appendice(valore)
    if numero ~= nil and contesto[prefisso] ~= nil then
        local funzione = contesto[prefisso]
        local indici = {}
        local cursore = indice
        cursore = cursore + 1
        for variabile = 1, numero do
            indici[#indici + 1] = cursore
            cursore = cursore + misura(cursore)
        end
        return funzione(indici)
    end
    return tonumber(valore) or tostring(valore)
end

fai = function(indice)
    local valore = valori[indice]
    assert(type(valore) == "string")
    assert(valore == "do")
    local restituito = nil
    local cursore = indice
    cursore = cursore + 1
    while valori[cursore] ~= "end" do
        restituito = valuta(cursore)
        cursore = cursore + misura(cursore)
    end
    return restituito
end

local function sequenza(indice)
    local valore = valori[indice]
    assert(type(valore) == "string")
    local restituito = nil
    local cursore = indice
    while cursore <= #valori do
        restituito = valuta(cursore)
        cursore = cursore + misura(cursore)
    end
    return restituito
end

function contesto.scrivi(indici)
    io.write(valuta(indici[1]))
end
function contesto.scrivi_rigo(indici)
    io.write(valuta(indici[1]) .. "\n")
end
function contesto.somma(indici)
    return valuta(indici[1]) + valuta(indici[2])
end
function contesto.prodotto(indici)
    return valuta(indici[1]) * valuta(indici[2])
end
function contesto.se(indici)
    if valuta(indici[1]) then
        return valuta(indici[2])
    else
        return valuta(indici[3])
    end
end
function contesto.vero(indici)
    return true
end
function contesto.falso(indici)
    return false
end

valori = {"'100'", "somma#2", "5", "6"}
contesto.scrivi_rigo({1}) -- => '100'
print(contesto.somma({3, 4})) -- => 11
print(valuta(2)) -- => 11
print(valuta(1)) -- => '100'

-- 'scrivi_rigo#1 somma#2 5 prodotto#2 4 2'
valori = {"scrivi_rigo#1", "somma#2", "5", "prodotto#2", "4", "2"} -- => 13
valuta(1)

valori = {"scrivi_rigo#1", "somma#2", "prodotto#2", "4", "2", "5"} -- => 13
valuta(1)

valori = {"scrivi_rigo#1", "se#3", "vero#0", "1", "2"} -- => 1
valuta(1)

valori = {"do", "scrivi_rigo#1", "111", "scrivi_rigo#1", "222", "end", "scrivi_rigo#1", "333"}
print(misura(1)) -- => 6
sequenza(1) -- => 111 222 333

valori = {"se#3", "falso#0", "do", "scrivi_rigo#1", "111", "scrivi_rigo#1", "222", "end", "scrivi_rigo#1", "333"}
sequenza(1) -- => 111 and 222 (if true) , or just 333 (if false)
