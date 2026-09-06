local contesto={}
-- EN: variable environment: a linked chain of scopes (prototype chain).
-- EN: prendi reads through the chain; metti updates the nearest binding.
-- EN: functions capture this chain lexically (see funzione below).
-- IT: ambiente delle variabili: una catena collegata di ambiti (catena di prototipi).
-- IT: prendi legge attraverso la catena; metti aggiorna il legame più vicino.
-- IT: le funzioni catturano questa catena lessicalmente (vedi funzione sotto).
local ambiente = {}
-- EN: nuovo_ambito(genitore) creates a child scope that inherits from its parent.
-- IT: nuovo_ambito(genitore) crea un ambito figlio che eredita dal genitore.
local function nuovo_ambito(genitore)
  return setmetatable({}, { __index = genitore })
end
-- EN: trova_ambito(nome) returns the scope that owns `nome`, walking outward
-- EN: (nil if the name is unbound anywhere).
-- IT: trova_ambito(nome) restituisce l'ambito che possiede `nome`, risalendo
-- IT: (nil se il nome non è legato da nessuna parte).
local function trova_ambito(nome)
  local amb = ambiente
  while amb do
    if rawget(amb, nome) ~= nil then return amb end
    amb = getmetatable(amb) and getmetatable(amb).__index
  end
  return nil
end
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

-- EN: decodifica(s) decodes escape sequences in a string literal:
-- EN: \n newline, \t tab, \' \" quote, \\ backslash; any other \x -> x.
-- IT: decodifica(s) decodifica le sequenze di escape in un letterale stringa:
-- IT: \n a capo, \t tabulazione, \' \" virgolette, \\ backslash; ogni \x -> x.
local function decodifica(s)
  return (s:gsub("\\(.)", function(c)
    if c == "n" then return "\n"
    elseif c == "t" then return "\t" end
    return c
  end))
end

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
    return decodifica(valore:sub(2, -2)), pos + 1
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
  if salta then return 0, pos end
  return a + b, pos
end
function contesto.prodotto ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  if salta then return 0, pos end
  return a * b, pos
end
-- EN: sottrai <a> <b> : subtraction (a - b)
-- IT: sottrai <a> <b> : sottrazione (a - b)
function contesto.sottrai ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  if salta then return 0, pos end
  return a - b, pos
end

-- EN: metti <name> <value> : assign a value to a variable. The name is read as a
-- EN: raw token (not evaluated); the value is evaluated.
-- IT: metti <nome> <valore> : assegna un valore a una variabile. Il nome è letto come
-- IT: token grezzo (non valutato); il valore viene valutato.
function contesto.metti ( pos )
  local nome = valori[pos]
  local v; v, pos = valuta(pos + 1)
  if not salta then
    local amb = trova_ambito(nome) or ambiente
    amb[nome] = v
  end
  return v, pos
end
-- EN: prendi <name> : read a variable's value through the scope chain.
-- IT: prendi <nome> : legge il valore di una variabile attraverso la catena.
function contesto.prendi ( pos )
  local nome = valori[pos]
  return ambiente[nome], pos + 1
end

-- EN: modulo <dividend> <divisor> : remainder (a % b)
-- IT: modulo <dividendo> <divisore> : resto (a % b)
function contesto.modulo ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  if salta then return 0, pos end
  return a % b, pos
end
-- EN: uguale <a> <b> : equality (a == b)
-- IT: uguale <a> <b> : uguaglianza (a == b)
function contesto.uguale ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  if salta then return false, pos end
  return a == b, pos
end
-- EN: maggiore <a> <b> : greater-than (a > b)
-- IT: maggiore <a> <b> : maggiore-di (a > b)
function contesto.maggiore ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  if salta then return false, pos end
  return a > b, pos
end
-- EN: non <a> : logical negation (not a)
-- IT: non <a> : negazione logica (not a)
function contesto.non ( pos )
  local a; a, pos = valuta(pos)
  if salta then return false, pos end
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
    if not salta then tot = tot + v end
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

-- EN: funzione <name> <params...> fine <body> : define a named function.
-- EN: params are bound lexically (the closure captures the defining scope); the
-- EN: body is a single expression (wrap several statements in fai ... fine) and
-- EN: returns its last value, exactly like fai. Parameters are read with prendi.
-- IT: funzione <nome> <parametri...> fine <corpo> : definisce una funzione con nome.
-- IT: i parametri sono legati lessicalmente (la chiusura cattura l'ambito di
-- IT: definizione); il corpo è una singola espressione (per più istruzioni usa
-- IT: fai ... fine) e restituisce l'ultimo valore, come fai. I parametri si
-- IT: leggono con prendi.
-- EN: crea_chiusura builds a function VALUE from a parameter list, a captured
-- EN: body (token array) and a defining scope. The returned closure takes a
-- EN: POSITIONAL argument array, binds the parameters in a fresh lexical scope,
-- EN: and returns the last value of the body. It is the shared core of both
-- EN: `funzione` (named) and `lambda` (anonymous).
-- IT: crea_chiusura costruisce un VALORE funzione da una lista di parametri, un
-- IT: corpo catturato (array di token) e un ambito di definizione. La chiusura
-- IT: restituita prende un array POSIZIONALE di argomenti, lega i parametri in un
-- IT: nuovo ambito lessicale e restituisce l'ultimo valore del corpo. È il nucleo
-- IT: condiviso da `funzione` (con nome) e `lambda` (anonima).
local function crea_chiusura(parametri, corpo_valori, ambito_def)
  return function ( argomenti )
    local amb_esterno, valori_esterni = ambiente, valori
    ambiente = nuovo_ambito(ambito_def)          -- lexical parent = defining scope
    for i, par in ipairs(parametri) do
      ambiente[par] = argomenti and argomenti[i]
    end
    valori = corpo_valori
    local risultato = valuta(1)                  -- evaluate the body
    valori = valori_esterni
    ambiente = amb_esterno
    return risultato
  end
end

function contesto.funzione ( pos )
  local nome = valori[pos]                       -- function name (raw token)
  local parametri = {}
  pos = pos + 1
  while valori[pos] and not terminatore[valori[pos]] do
    parametri[#parametri + 1] = valori[pos]
    pos = pos + 1
  end
  pos = pos + 1                                  -- skip the 'fine' terminator
  local corpo = pos

  -- EN: register a temporary placeholder (arity = #params) so that a recursive
  -- EN: reference to the function itself parses with the right arity while the
  -- EN: body extent is measured below (salta_espr runs in skip mode).
  -- IT: registra un segnaposto temporaneo (arietà = #parametri) così un
  -- IT: riferimento ricorsivo alla funzione stessa viene analizzato con la giusta
  -- IT: arietà mentre si misura l'estensione del corpo (salta_espr in modalità salta).
  local precedente = contesto[nome]
  contesto[nome] = function ( p )
    for _ = 1, #parametri do
      local v; v, p = valuta(p)
    end
    return nil, p
  end

  local dopo = salta_espr(corpo)                 -- body extent (parsed, not run)

  -- EN: capture the body tokens and the defining scope by value, so the function
  -- EN: keeps working after `valori` / `ambiente` change (lexical closure).
  -- IT: cattura i token del corpo e l'ambito di definizione per valore, così la
  -- IT: funzione continua a funzionare dopo che `valori` / `ambiente` cambiano.
  local corpo_valori = {}
  for k = corpo, dopo - 1 do
    corpo_valori[#corpo_valori + 1] = valori[k]
  end
  local ambito_def = ambiente

  if salta then
    contesto[nome] = precedente                 -- skip mode: don't define it
    return nil, dopo
  end

  local chiusura = crea_chiusura(parametri, corpo_valori, ambito_def)

  -- EN: the named function is callable as a keyword: the wrapper consumes exactly
  -- EN: #params arguments and hands them to the closure.
  -- IT: la funzione con nome è chiamabile come parola chiave: il wrapper consuma
  -- IT: esattamente #parametri argomenti e li passa alla chiusura.
  contesto[nome] = function ( p )
    local argomenti = {}
    for _ = 1, #parametri do
      local v; v, p = valuta(p)                -- evaluate args in the caller's scope
      argomenti[#argomenti + 1] = v
    end
    if salta then return nil, p end            -- skip mode: consume args only
    return chiusura(argomenti), p
  end

  -- EN: also store the value in the defining scope, so `prendi nome` returns the
  -- EN: function as a first-class value (it can be passed / returned like a lambda).
  -- IT: memorizza anche il valore nell'ambito di definizione, così `prendi nome`
  -- IT: restituisce la funzione come valore di prima classe (passabile/restituibile).
  ambito_def[nome] = chiusura

  return nil, dopo
end

-- EN: lambda <params...> fine <body> : an anonymous function VALUE. It is the
-- EN: same closure as `funzione` but returned instead of being registered.
-- IT: lambda <parametri...> fine <corpo> : un VALORE funzione anonima. È la stessa
-- IT: chiusura di `funzione` ma restituita invece di essere registrata.
function contesto.lambda ( pos )
  local parametri = {}
  while valori[pos] and not terminatore[valori[pos]] do
    parametri[#parametri + 1] = valori[pos]
    pos = pos + 1
  end
  pos = pos + 1                                  -- skip the 'fine' terminator
  local corpo = pos

  local dopo = salta_espr(corpo)                 -- body extent (parsed, not run)

  local corpo_valori = {}
  for k = corpo, dopo - 1 do
    corpo_valori[#corpo_valori + 1] = valori[k]
  end
  local ambito_def = ambiente

  if salta then return nil, dopo end
  return crea_chiusura(parametri, corpo_valori, ambito_def), dopo
end

-- EN: chiama <func> <args...> fine : call a function VALUE. The function
-- EN: expression is evaluated first; then the arguments are consumed until the
-- EN: `fine`/`end` terminator (so the extent is known even at parse time) and
-- EN: handed to the closure as a positional list.
-- IT: chiama <funzione> <argomenti...> fine : chiama un VALORE funzione. Prima si
-- IT: valuta l'espressione funzione; poi gli argomenti vengono consumati fino al
-- IT: terminatore `fine`/`end` (così l'estensione è nota anche in fase di analisi)
-- IT: e passati alla chiusura come lista posizionale.
function contesto.chiama ( pos )
  local f; f, pos = valuta(pos)                  -- the function value
  local argomenti = {}
  while valori[pos] and not terminatore[valori[pos]] do
    local v; v, pos = valuta(pos)
    argomenti[#argomenti + 1] = v
  end
  pos = pos + 1                                  -- skip the 'fine' terminator
  if salta then return nil, pos end              -- skip mode: don't actually call
  return f(argomenti), pos
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
-- EN: A "--" starts a comment that runs to the end of the line. Inside a
-- EN: quoted literal a backslash escapes the next character (so \' and \"
-- EN: don't close the string); decoding happens later in valuta (decodifica).
-- IT: tokenizza divide una stringa sorgente in un array piatto di token.
-- IT: Gli spazi separano i token; un letterale tra virgolette ( '...' o "..." )
-- IT: può contenere spazi e resta un singolo token. Le virgolette restano,
-- IT: così valuta le rimuove, come negli array scritti a mano qui sotto.
-- IT: Un "--" avvia un commento che arriva a fine riga. Dentro un letterale
-- IT: un backslash esclude il carattere successivo (così \' e \" non chiudono
-- IT: la stringa); la decodifica avviene dopo in valuta (decodifica).
local function tokenizza(testo)
  local token = {}
  local i, n = 1, #testo
  while i <= n do
    local c = testo:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c == "-" and testo:sub(i + 1, i + 1) == "-" then
      i = (testo:find("\n", i) or n) + 1
    elseif c == "'" or c == '"' then
      local j = i + 1
      while j <= n and testo:sub(j, j) ~= c do
        if testo:sub(j, j) == "\\" then j = j + 1 end
        j = j + 1
      end
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

-- EN: comments: -- to end of line is ignored by the tokenizer
-- IT: commenti: -- fino a fine riga viene ignorato dal tokenizzatore
testo = [[scrivi_rigo 'ciao' -- greets]]
valori = tokenizza(testo)
valuta(1)   -- ciao

-- EN: escapes: \n newline, \' escaped quote inside a literal
-- IT: escape: \n a capo, \' virgoletta esclusa dentro un letterale
testo = [[scrivi_rigo 'a\nb']]
valori = tokenizza(testo)
valuta(1)   -- a then b (two lines)

testo = [[scrivi_rigo 'it\'s']]
valori = tokenizza(testo)
valuta(1)   -- it's

-- ============================================================
-- EN: user-defined functions (funzione ... fine), lexical scope
-- IT: funzioni definite dall'utente (funzione ... fine), ambito lessicale
-- ============================================================

-- EN: a one-expression function; its parameter is read back with prendi
-- IT: una funzione con una sola espressione; il parametro si rilegge con prendi
testo = [[funzione doppio x fine prodotto prendi x 2]]
valori = tokenizza(testo)
valuta(1)                          -- defines doppio
testo = [[scrivi_rigo doppio 5]]
valori = tokenizza(testo)
valuta(1)                          -- 10

-- EN: two parameters, single-expression body
-- IT: due parametri, corpo a singola espressione
testo = [[funzione somma_quadrati a b fine somma prodotto prendi a prendi a prodotto prendi b prendi b]]
valori = tokenizza(testo)
valuta(1)                          -- defines somma_quadrati
testo = [[scrivi_rigo somma_quadrati 3 4]]
valori = tokenizza(testo)
valuta(1)                          -- 9 + 16 = 25

-- EN: multi-statement body via fai ... fine; returns the last value
-- IT: corpo a più istruzioni via fai ... fine; restituisce l'ultimo valore
testo = [[funzione saluta_e_doppia n fine fai scrivi_rigo 'ciao' prodotto prendi n 2 fine]]
valori = tokenizza(testo)
valuta(1)                          -- defines saluta_e_doppia
testo = [[scrivi_rigo saluta_e_doppia 7]]
valori = tokenizza(testo)
valuta(1)                          -- prints ciao then 14

-- EN: lexical closure: interno remembers `a` even after esterno returns
-- IT: chiusura lessicale: interno ricorda `a` anche dopo che esterno ritorna
testo = [[funzione esterno a fine funzione interno b fine somma prendi a prendi b]]
valori = tokenizza(testo)
valuta(1)                          -- defines esterno
testo = [[esterno 10]]
valori = tokenizza(testo)
valuta(1)                          -- defines interno capturing a = 10
testo = [[scrivi_rigo interno 5]]
valori = tokenizza(testo)
valuta(1)                          -- 15 (lexical: interno still sees a = 10)

-- EN: recursion (needs sottrai); factorial of 5
-- IT: ricorsione (richiede sottrai); fattoriale di 5
testo = [[funzione fatto n fine se uguale prendi n 0 1 prodotto prendi n fatto sottrai prendi n 1]]
valori = tokenizza(testo)
valuta(1)                          -- defines fatto
testo = [[scrivi_rigo fatto 5]]
valori = tokenizza(testo)
valuta(1)                          -- 120

-- EN: user-defined words also work through the English alias of the keyword
-- IT: le parole definite dall'utente funzionano anche con l'alias inglese
testo = [[function double x end product get x 2]]
valori = tokenizza(testo)
valuta(1)                          -- defines double
testo = [[writeline double 9]]
valori = tokenizza(testo)
valuta(1)                          -- 18


-- ============================================================
-- EN: higher-order functions: functions as values (lambda / chiama)
-- IT: funzioni di ordine superiore: funzioni come valori (lambda / chiama)
-- ============================================================

-- EN: an anonymous function value: store it in a variable, then call it
-- IT: un valore funzione anonimo: salvalo in una variabile, poi chiamalo
testo = [[metti doppio lambda x fine prodotto prendi x 2]]
valori = tokenizza(testo)
valuta(1)                          -- stores doppio (a function value)
testo = [[scrivi_rigo chiama prendi doppio 5 fine]]
valori = tokenizza(testo)
valuta(1)                          -- 10

-- EN: a function that RETURNS a function (closure factory, captures k)
-- IT: una funzione che RESTITUISCE una funzione (fabbrica di chiusure, cattura k)
testo = [[funzione crea_moltiplicatore k fine lambda x fine prodotto prendi x prendi k]]
valori = tokenizza(testo)
valuta(1)                          -- defines crea_moltiplicatore
testo = [[metti per_3 crea_moltiplicatore 3]]
valori = tokenizza(testo)
valuta(1)                          -- stores a closure capturing k = 3
testo = [[scrivi_rigo chiama prendi per_3 7 fine]]
valori = tokenizza(testo)
valuta(1)                          -- 21

-- EN: a function that ACCEPTS a function (higher-order): applies it to 2
-- IT: una funzione che ACCETTA una funzione (ordine superiore): la applica a 2
testo = [[funzione applica_due f fine chiama prendi f 2 fine]]
valori = tokenizza(testo)
valuta(1)                          -- defines applica_due
testo = [[scrivi_rigo applica_due lambda x fine prodotto prendi x 2]]
valori = tokenizza(testo)
valuta(1)                          -- 4

-- EN: English aliases for the new words (lambda / call)
-- IT: alias inglesi per le nuove parole (lambda / call)
testo = [[set d lambda x end product get x 2]]
valori = tokenizza(testo)
valuta(1)                          -- stores d (a function value)
testo = [[writeline call get d 5 end]]
valori = tokenizza(testo)
valuta(1)                          -- 10

