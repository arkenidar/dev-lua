local contesto={}
local testo='scrivi_rigo somma 5 prodotto 4 2'
local valori={"scrivi_rigo","somma","5","prodotto","4","2"}

-- bilingual keyword dictionary (single source of truth)
local lessico = dofile("lessico.lua")

-- valuta(pos) evaluates the token at position pos and returns
-- (value, next_pos), where next_pos points just past everything consumed.
-- A keyword consumes itself plus its arguments (recursively).
local function valuta(pos)
  local valore = valori[pos]
  assert( type(valore) == "string" )
  if contesto[valore] then
    return contesto[valore]( pos + 1 )
  end
  return (tonumber(valore) or tostring(valore)), pos + 1
end

-- Every builtin receives a position and returns (value, next_pos).
-- Arity is implicit: a function consumes as many tokens as it calls valuta().
-- NOTE: reassign the `pos` parameter (v, pos = valuta(pos)); never declare a
-- `local pos`, or the cursor silently stops advancing inside loops.

function contesto.scrivi ( pos )
  local v; v, pos = valuta(pos)
  io.write( v )
  return nil, pos
end
function contesto.scrivi_rigo ( pos )
  local v; v, pos = valuta(pos)
  io.write( v .. "\n" )
  return nil, pos
end
function contesto.somma ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a + b, pos
end
function contesto.prodotto ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a * b, pos
end

-- variadic sum: consumes arguments until the terminator ("fine" / "end")
-- both languages are accepted as the terminator
local terminatore = { [lessico.it.fine] = true, [lessico.en[lessico.it.fine]] = true }

function contesto.somma_tutti ( pos )
  local tot = 0
  local v
  while valori[pos] and not terminatore[valori[pos]] do
    v, pos = valuta(pos)
    tot = tot + v
  end
  return tot, pos + 1
end

-- register English aliases for every built-in keyword
for it, en in pairs(lessico.it) do
  if contesto[it] then contesto[en] = contesto[it] end
end

-- driver / tests
valori = {"scrivi_rigo","somma","5","prodotto","4","2"}
valuta(1)   -- scrivi_rigo somma 5 prodotto 4 2  ->  5 + (4 * 2) = 13

valori = {"scrivi_rigo","somma_tutti","1","2","3","4","fine"}
valuta(1)   -- 1 + 2 + 3 + 4 = 10

valori = {"'100'","somma","5","6"}
local v = valuta(1)
print( v )   -- "'100'" (literal)

-- English aliases work too
valori = {"writeline","sum","5","product","4","2"}
valuta(1)   -- 5 + (4 * 2) = 13

valori = {"writeline","sumall","1","2","3","4","end"}
valuta(1)   -- 1 + 2 + 3 + 4 = 10