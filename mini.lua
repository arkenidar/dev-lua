local contesto={}
-- EN: mutable variable store (metti / prendi read and write here)
-- IT: archivio delle variabili mutabili (metti / prendi leggono e scrivono qui)
local variabili={}
-- EN: skip flag: when true, side-effecting builtins (scrivi, scrivi_rigo, metti)
-- EN: do nothing. Used to skip an un-taken branch without executing it.
-- IT: flag "salta": quando è true, le funzioni con effetti (scrivi, scrivi_rigo,
-- IT: metti) non fanno nulla. Serve a saltare un ramo non scelto senza eseguirlo.
local salta = false
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

-- EN: salta_espr(pos) parses (consumes) one expression WITHOUT executing its
-- EN: side effects, and returns the position just past it.
-- IT: salta_espr(pos) analizza (consuma) un'espressione SENZA eseguirne gli
-- IT: effetti e restituisce la posizione appena oltre essa.
local function salta_espr(pos)
  local prima = salta
  salta = true
  local _, dopo = valuta(pos)
  salta = prima
  return dopo
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
  if not salta then io.write( v ) end
  return nil, pos
end
function contesto.scrivi_rigo ( pos )
  local v; v, pos = valuta(pos)
  if not salta then io.write( tostring(v) .. "\n" ) end
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
  if not salta then variabili[nome] = v end
  return v, pos
end
-- EN: prendi <name> : read a variable's value.
-- IT: prendi <nome> : legge il valore di una variabile.
function contesto.prendi ( pos )
  local nome = valori[pos]
  return variabili[nome], pos + 1
end

-- EN: modulo <dividend> <divisor> : remainder (a % b)
-- IT: modulo <dividendo> <divisore> : resto (a % b)
function contesto.modulo ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a % b, pos
end
-- EN: uguale <a> <b> : equality (a == b)
-- IT: uguale <a> <b> : uguaglianza (a == b)
function contesto.uguale ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a == b, pos
end
-- EN: maggiore <a> <b> : greater-than (a > b)
-- IT: maggiore <a> <b> : maggiore-di (a > b)
function contesto.maggiore ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a > b, pos
end
-- EN: non <a> : logical negation (not a)
-- IT: non <a> : negazione logica (not a)
function contesto.non ( pos )
  local a; a, pos = valuta(pos)
  return not a, pos
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

-- EN: fai ... fine : a block/sequence. Evaluates statements until the terminator
-- EN: (fine / end) and returns the last value.
-- IT: fai ... fine : un blocco/sequenza. Valuta le istruzioni fino al terminatore
-- IT: (fine / end) e restituisce l'ultimo valore.
function contesto.fai ( pos )
  local v
  while valori[pos] and not terminatore[valori[pos]] do
    v, pos = valuta(pos)
  end
  return v, pos + 1
end

-- EN: se <condition> <then> <else> : if the condition is truthy, evaluate and
-- EN: return the then-expression, otherwise the else-expression. The un-taken
-- EN: branch is skipped (parsed but not executed).
-- IT: se <condizione> <allora> <altrimenti> : se la condizione è vera, valuta e
-- IT: restituisce l'espressione-allora, altrimenti l'espressione-altrimenti. Il
-- IT: ramo non scelto viene saltato (analizzato ma non eseguito).
function contesto.se ( pos )
  local cond; cond, pos = valuta(pos)
  local v
  if cond then
    v, pos = valuta(pos)    -- then-branch (executed)
    pos = salta_espr(pos)   -- skip else-branch
  else
    pos = salta_espr(pos)   -- skip then-branch
    v, pos = valuta(pos)    -- else-branch (executed)
  end
  return v, pos
end

-- EN: mentre <condition> <body> : evaluate the body repeatedly while the
-- EN: condition is truthy; the condition is re-evaluated each iteration.
-- IT: mentre <condizione> <corpo> : valuta il corpo ripetutamente finché la
-- IT: condizione è vera; la condizione viene rivalutata a ogni iterazione.
function contesto.mentre ( pos )
  local inizio = pos
  local cond
  cond, pos = valuta(inizio)     -- condition; pos -> body start
  local corpo = pos
  local dopo = salta_espr(corpo) -- body extent (parsed, never executed here)
  if not salta then
    while cond do
      valuta(corpo)              -- execute the body
      cond = valuta(inizio)      -- re-evaluate the condition
    end
  end
  return nil, dopo
end

-- EN: register English aliases for every built-in keyword
-- IT: registra gli alias inglesi per ogni parola chiave incorporata
for it, en in pairs(lessico.it) do
  if contesto[it] then contesto[en] = contesto[it] end
end

-- EN: tokenizza (tokenize) splits a source string into a flat token array.
-- EN: Whitespace separates tokens; a quoted literal ( '...' or "..." ) may
-- EN: contain spaces and stays a single token. Quotes are kept so that valuta
-- EN: strips them, exactly as with the hand-written arrays below.
-- IT: tokenizza divide una stringa sorgente in un array piatto di token.
-- IT: Gli spazi separano i token; un letterale tra virgolette ( '...' o "..." )
-- IT: può contenere spazi e resta un singolo token. Le virgolette restano,
-- IT: così valuta le rimuove, come negli array scritti a mano qui sotto.
local function tokenizza(testo)
  local token = {}
  local i, n = 1, #testo
  while i <= n do
    local c = testo:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == "'" or c == '"' then
      local j = testo:find(c, i + 1, true) or (n + 1)
      token[#token + 1] = testo:sub(i, j)
      i = j + 1
    else
      local j = testo:find("%s", i) or (n + 1)
      token[#token + 1] = testo:sub(i, j - 1)
      i = j
    end
  end
  return token
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

-- EN: arithmetic and comparison words
-- IT: parole aritmetiche e di confronto
valori = {"scrivi_rigo","modulo","7","3"}
valuta(1)   -- 7 % 3 = 1

valori = {"scrivi_rigo","uguale","0","modulo","15","3"}
valuta(1)   -- 0 == (15 % 3) -> true

valori = {"scrivi_rigo","maggiore","5","3"}
valuta(1)   -- 5 > 3 -> true

valori = {"scrivi_rigo","non","uguale","1","2"}
valuta(1)   -- not (1 == 2) -> true

-- EN: fai (block): a sequence of statements, returning the last value
-- IT: fai (blocco): una sequenza di istruzioni, restituisce l'ultimo valore
valori = {"fai","scrivi_rigo","'a'","scrivi_rigo","'b'","fine"}
valuta(1)   -- prints a then b

valori = {"scrivi_rigo","fai","somma","1","2","fine"}
valuta(1)   -- block returns 3

-- EN: se (if/else): lazy evaluation, the un-taken branch is skipped
-- IT: se (se/altrimenti): valutazione lazy, il ramo non scelto è saltato
valori = {"scrivi_rigo","se","uguale","1","1","'vero'","'falso'"}
valuta(1)   -- condition true -> prints vero

valori = {"scrivi_rigo","se","uguale","1","2","'vero'","'falso'"}
valuta(1)   -- condition false -> prints falso

-- EN: the un-taken branch must NOT run
-- IT: il ramo non scelto NON deve essere eseguito
valori = {"se","uguale","1","1","scrivi_rigo","'si'","scrivi_rigo","'no'"}
valuta(1)   -- prints si only

-- EN: mentre (while): loop while the condition is true
-- IT: mentre (while): ciclo finché la condizione è vera
valori = {"fai","metti","i","1","mentre","non","maggiore","prendi","i","3","fai","scrivi_rigo","prendi","i","metti","i","somma","prendi","i","1","fine","fine"}
valuta(1)   -- prints 1, 2, 3

-- EN: the new words also work in English
-- IT: le nuove parole funzionano anche in inglese
valori = {"do","set","i","1","while","not","greater","get","i","3","do","writeline","get","i","set","i","sum","get","i","1","end","end"}
valuta(1)   -- prints 1, 2, 3

-- EN: FizzBuzz (Italian, 1..20): Fizz/Buzz/FizzBuzz or the number
-- IT: FizzBuzz (italiano, 1..20): Fizz/Buzz/FizzBuzz oppure il numero
valori = {
  "fai","metti","i","1",
  "mentre","non","maggiore","prendi","i","20","fai",
    "se","uguale","0","modulo","prendi","i","15","scrivi_rigo","'FizzBuzz'",
    "se","uguale","0","modulo","prendi","i","3","scrivi_rigo","'Fizz'",
    "se","uguale","0","modulo","prendi","i","5","scrivi_rigo","'Buzz'","scrivi_rigo","prendi","i",
    "metti","i","somma","prendi","i","1",
  "fine","fine"
}
valuta(1)

-- EN: FizzBuzz (English, 1..20)
-- IT: FizzBuzz (inglese, 1..20)
valori = {
  "do","set","i","1",
  "while","not","greater","get","i","20","do",
    "if","equal","0","modulus","get","i","15","writeline","'FizzBuzz'",
    "if","equal","0","modulus","get","i","3","writeline","'Fizz'",
    "if","equal","0","modulus","get","i","5","writeline","'Buzz'","writeline","get","i",
    "set","i","sum","get","i","1",
  "end","end"
}
valuta(1)

-- EN: tokenizer demo: feed real source text through tokenizza instead of a
-- EN: hand-written token array. Output matches the equivalent arrays above.
-- IT: demo del tokenizzatore: passa vero testo sorgente a tokenizza invece di
-- IT: un array di token scritto a mano. L'output corrisponde agli array sopra.
testo = 'scrivi_rigo somma 5 prodotto 4 2'
valori = tokenizza(testo)
valuta(1)   -- 13

testo = [[scrivi_rigo 'Hello World']]   -- quotes keep the inner space as one token
valori = tokenizza(testo)
valuta(1)   -- Hello World

testo = [[
  do set i 1
  while not greater get i 3 do
    writeline get i
    set i sum get i 1
  end end
]]
valori = tokenizza(testo)
valuta(1)   -- 1 2 3
