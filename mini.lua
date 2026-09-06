local contesto={}
-- EN: mutable variable store (metti / prendi read and write here)
-- IT: archivio delle variabili mutabili (metti / prendi leggono e scrivono qui)
local variabili={}
local testo='scrivi_rigo somma 5 prodotto 4 2'
local valori={"scrivi_rigo","somma","5","prodotto","4","2"}

-- EN: bilingual keyword dictionary (single source of truth)
-- IT: dizionario bilingue delle parole chiave (unica fonte di verità)
local lessico = dofile("lessico.lua")

-- EN: valuta(pos) evaluates the token at position pos and returns
-- EN: (value, next_pos), where next_pos points just past everything consumed.
-- EN: A keyword consumes itself plus its arguments (recursively).
-- IT: valuta(pos) valuta il token alla posizione pos e restituisce
-- IT: (valore, prossima_pos), dove prossima_pos punta appena oltre ciò che è stato consumato.
-- IT: Una parola chiave consuma se stessa più i suoi argomenti (ricorsivamente).
local function valuta(pos)
  local valore = valori[pos]
  assert( type(valore) == "string" )
  if contesto[valore] then
    return contesto[valore]( pos + 1 )
  end
  local numero = tonumber(valore)
  if numero then
    return numero, pos + 1
  end
  -- EN: string literal: strip the matching quotes ( '...' or "..." )
  -- IT: letterale stringa: rimuovi le virgolette corrispondenti ( '...' o "..." )
  local apice = valore:sub(1,1)
  if #valore >= 2 and (apice == "'" or apice == "\"") and valore:sub(-1) == apice then
    return valore:sub(2, -2), pos + 1
  end
  return valore, pos + 1
end

-- EN: Every builtin receives a position and returns (value, next_pos).
-- EN: Arity is implicit: a function consumes as many tokens as it calls valuta().
-- EN: NOTE: reassign the `pos` parameter (v, pos = valuta(pos)); never declare a
-- EN: `local pos`, or the cursor silently stops advancing inside loops.
-- IT: Ogni funzione incorporata riceve una posizione e restituisce (valore, prossima_pos).
-- IT: L'arietà è implicita: una funzione consuma tanti token quante volte chiama valuta().
-- IT: NOTA: riassegna il parametro `pos` (v, pos = valuta(pos)); non dichiarare mai una
-- IT: `local pos`, altrimenti il cursore smette silenziosamente di avanzare nei cicli.

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

-- EN: metti <name> <value> : assign a value to a variable. The name is read as a
-- EN: raw token (not evaluated); the value is evaluated.
-- IT: metti <nome> <valore> : assegna un valore a una variabile. Il nome è letto come
-- IT: token grezzo (non valutato); il valore viene valutato.
function contesto.metti ( pos )
  local nome = valori[pos]
  local v; v, pos = valuta(pos + 1)
  variabili[nome] = v
  return v, pos
end
-- EN: prendi <name> : read a variable's value.
-- IT: prendi <nome> : legge il valore di una variabile.
function contesto.prendi ( pos )
  local nome = valori[pos]
  return variabili[nome], pos + 1
end

-- EN: variadic sum: consumes arguments until the terminator ("fine" / "end")
-- EN: both languages are accepted as the terminator
-- IT: somma variadica: consuma gli argomenti fino al terminatore ("fine" / "end")
-- IT: entrambe le lingue sono accettate come terminatore
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

-- EN: register English aliases for every built-in keyword
-- IT: registra gli alias inglesi per ogni parola chiave incorporata
for it, en in pairs(lessico.it) do
  if contesto[it] then contesto[en] = contesto[it] end
end

-- EN: driver / tests
-- IT: driver / test
valori = {"scrivi_rigo","somma","5","prodotto","4","2"}
valuta(1)   -- scrivi_rigo somma 5 prodotto 4 2  ->  5 + (4 * 2) = 13

valori = {"scrivi_rigo","somma_tutti","1","2","3","4","fine"}
valuta(1)   -- 1 + 2 + 3 + 4 = 10

valori = {"'100'","somma","5","6"}
local v = valuta(1)
print( v )   -- "100" (string literal, quotes stripped)

-- EN: English aliases work too
-- IT: anche gli alias inglesi funzionano
valori = {"writeline","sum","5","product","4","2"}
valuta(1)   -- 5 + (4 * 2) = 13

valori = {"writeline","sumall","1","2","3","4","end"}
valuta(1)   -- 1 + 2 + 3 + 4 = 10

-- EN: variables: metti (set) returns the stored value; prendi (get) reads it back
-- IT: variabili: metti restituisce il valore salvato; prendi lo rilegge
valori = {"scrivi_rigo","metti","i","somma","2","3"}
valuta(1)   -- sets i = 2 + 3 = 5, prints 5

valori = {"scrivi_rigo","prendi","i"}
valuta(1)   -- reads i back, prints 5

-- EN: string literal quotes are stripped
-- IT: le virgolette dei letterali stringa vengono rimosse
valori = {"scrivi_rigo","'Fizz'"}
valuta(1)   -- prints Fizz
