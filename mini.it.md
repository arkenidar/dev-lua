# `mini.lua` — un interprete minimale a notazione prefissa

> Un interprete ricorsivo-discendente di ~60 righe per un piccolo linguaggio a
> **notazione prefissa (polacca)**, scritto in Lua. Questo documento è un riepilogo
> completo del progetto, dell'evoluzione arità-fissa→variabile, degli esempi
> svolti, delle note di robustezza, delle insidie e della discendenza
> informatico-storica che vi sta dietro.
>
> *Available in English: [mini.md](mini.md)*

---

## Indice

1. [Panoramica](#1-panoramica)
2. [Il linguaggio](#2-il-linguaggio)
3. [Glossario](#3-glossario)
4. [Implementazione attuale (Progetto B)](#4-implementazione-attuale-progetto-b)
5. [Dall'arità fissa all'arità variabile](#5-dallarit-fissa-allarit-variabile)
6. [Funzioni realmente variadiche](#6-funzioni-realmente-variadiche)
7. [Esempi svolti](#7-esempi-svolti)
8. [Analisi di robustezza](#8-analisi-di-robustezza)
9. [Insidie](#9-insidie)
10. [Discendenza informatico-storica](#10-discendenza-informatico-storica)
11. [Esecuzione](#11-esecuzione)
12. [Riferimenti](#12-riferimenti)

---

## 1. Panoramica

`mini.lua` è un **interprete minimale** per un linguaggio a notazione prefissa in cui:

- un "programma" è un array piatto di token (`valori`);
- un token è o una **parola chiave** (una funzione incorporata) o un **letterale** (numero / stringa);
- `valuta` (inglese: *"evaluate"*) percorre il flusso di token ricorsivamente;
- ogni parola chiave sa quanti argomenti consuma (la sua **arietà**), quindi il
  linguaggio non ha bisogno di **parentesi**.

Dimostra uno schema classico di interprete in pochissimo spazio. Ora ha
variabili (`metti`/`prendi`) e funzioni definite dall'utente (`funzione`), e resta
un seme naturale per un linguaggio più grande (un vero AST, array, ecc.). È già
incluso un front-end `tokenizza`: divide il testo
sorgente nell'array `valori`, così un programma si può scrivere come testo
semplice invece di un array di token costruito a mano.

## 2. Il linguaggio

| Costrutto | Esempio | Significato |
|-----------|---------|---------|
| `scrivi` | `scrivi 5` | stampa un valore (senza a capo) |
| `scrivi_rigo` | `scrivi_rigo 5` | stampa un valore + a capo |
| `somma` | `somma 5 6` | somma due valori (`+`) |
| `prodotto` | `prodotto 4 2` | moltiplica due valori (`*`) |
| `sottrai` | `sottrai 5 2` | sottrae due valori (`-`) |
| `somma_tutti` | `somma_tutti 1 2 3 4 fine` | somma **variadica**, terminata da `fine` |
| `metti` | `metti i 1` | assegna un valore a una variabile |
| `prendi` | `prendi i` | legge il valore di una variabile |
| `modulo` | `modulo 7 3` | resto (`%`) |
| `uguale` | `uguale 1 1` | test di uguaglianza (`==`) |
| `maggiore` | `maggiore 5 3` | test maggiore-di (`>`) |
| `non` | `non uguale 1 2` | negazione logica (`not`) |
| `fai` | `fai ... fine` | un blocco: sequenza di istruzioni, restituisce l'ultimo valore |
| `se` | `se cond ramo_vero ramo_falso` | se/altrimenti (lazy: solo il ramo scelto viene eseguito) |
| `mentre` | `mentre cond corpo` | ciclo while (la condizione è rivalutata a ogni iterazione) |
| `funzione` | `funzione nome x fine prodotto prendi x 2` | definisce una funzione con nome (ambito lessicale) |

Le espressioni si annidano ricorsivamente, ad es.
`scrivi_rigo somma 5 prodotto 4 2` vale `5 + (4 × 2) = 13`.

Ogni parola chiave ha un alias inglese — `somma` ≡ `sum`, `prodotto` ≡ `product`,
`scrivi_rigo` ≡ `writeline`, `somma_tutti` ≡ `sumall`, `fine` ≡ `end` — vedi
[§3.2](#32-alias-delle-parole-chiave-italiano--inglese). Il terminatore variadico
può essere sia `fine` sia `end`.

I valori possono essere salvati nelle variabili con `metti` e riletti con
`prendi`. I letterali stringa si scrivono tra virgolette corrispondenti (`'Fizz'`
o `"Fizz"`); le virgolette vengono rimosse quando il letterale è valutato.
Le sequenze di escape nei letterali (`\n`, `\t`, `\'`, `\"`, `\\`) vengono
decodificate, e `--` avvia un commento che arriva a fine riga.

Le parole di confronto (`uguale`, `maggiore`, `non`) producono valori booleani
(`true`/`false`), su cui si basano le parole di controllo di flusso (introdotte più avanti).
`fai ... fine` raggruppa più istruzioni in un singolo blocco, restituendo l'ultimo valore.
`se cond ramo_vero ramo_falso` sceglie un ramo; il ramo non scelto è analizzato ma
non eseguito, quindi i suoi effetti non avvengono mai.
`mentre cond corpo` ripete il corpo finché la condizione è vera; la condizione è
rivalutata a ogni iterazione.

`funzione nome param1 param2 ... fine corpo` definisce una funzione con nome. La
lista dei parametri termina al primo `fine`; il corpo è una singola espressione
(per più istruzioni racchiudi in `fai ... fine`) e restituisce l'ultimo valore,
esattamente come `fai`. I parametri si leggono con `prendi`, e sono **scopati
lessicalmente**: la funzione cattura l'ambito in cui è definita, quindi una
funzione definita dentro un'altra continua a vedere i suoi parametri anche dopo
che quella esterna ritorna. La ricorsione è supportata, ad es.
`funzione fatto n fine se uguale prendi n 0 1 prodotto prendi n fatto sottrai prendi n 1`.

## 3. Glossario

### 3.1 Identificatori del codice (nomi interni)

| Italiano | Inglese |
|---------|---------|
| `contesto` | context / environment (tabella delle funzioni incorporate) |
| `valuta` | evaluate |
| `valori` | values (l'array di token) |
| `indice` / `indici` | index / indices |
| `pos` | position (cursore dentro `valori`) |
| `testo` | text (la stringa sorgente, divisa in `valori` da `tokenizza`) |
| `tokenizza` | tokenize (divide `testo` nell'array di token `valori`) |
| `ambiente` | environment / scope (catena collegata di ambiti di variabili) |
| `nuovo_ambito` / `trova_ambito` | new-scope / find-scope (aiuti per l'ambito lessicale) |
| `decodifica` | decode (decodifica `\n`, `\t`, `\'`, `\"`, `\\` nei letterali stringa) |

### 3.2 Alias delle parole chiave (Italiano ↔ Inglese)

> Generato da `lessico.lua` — l'unica fonte di verità. Rigenera con
> `lua5.4 glossario.lua`. Entrambe le forme sono accettate come parole chiave.

| Italiano | Inglese |
|---------|---------|
| `fai` | `do` |
| `fine` | `end` |
| `funzione` | `function` |
| `maggiore` | `greater` |
| `mentre` | `while` |
| `metti` | `set` |
| `modulo` | `modulus` |
| `non` | `not` |
| `prendi` | `get` |
| `prodotto` | `product` |
| `scrivi` | `write` |
| `scrivi_rigo` | `writeline` |
| `se` | `if` |
| `somma` | `sum` |
| `somma_tutti` | `sumall` |
| `sottrai` | `subtract` |
| `uguale` | `equal` |

| Inglese | Italiano |
|---------|---------|
| `do` | `fai` |
| `end` | `fine` |
| `equal` | `uguale` |
| `function` | `funzione` |
| `get` | `prendi` |
| `greater` | `maggiore` |
| `if` | `se` |
| `modulus` | `modulo` |
| `not` | `non` |
| `product` | `prodotto` |
| `set` | `metti` |
| `subtract` | `sottrai` |
| `sum` | `somma` |
| `sumall` | `somma_tutti` |
| `while` | `mentre` |
| `write` | `scrivi` |
| `writeline` | `scrivi_rigo` |

---

## 4. Implementazione attuale (Progetto B)

Il sorgente completo e funzionante (stile cursore / passaggio di posizione):

```lua
local contesto={}
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
  return (tonumber(valore) or tostring(valore)), pos + 1
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
print( v )   -- "'100'" (literal)

-- EN: English aliases work too
-- IT: anche gli alias inglesi funzionano
valori = {"writeline","sum","5","product","4","2"}
valuta(1)   -- 5 + (4 * 2) = 13

valori = {"writeline","sumall","1","2","3","4","end"}
valuta(1)   -- 1 + 2 + 3 + 4 = 10
```

### Il contratto

Ogni funzione incorporata obbedisce alla stessa convenzione:

> **riceve una `pos` (cursore), restituisce `(valore, prossima_pos)`.**

- `valuta(pos)` restituisce `(valore, prossima_pos)`; per un letterale avanza di 1,
  per una parola chiave delega alla funzione incorporata e inoltra la posizione restituita.
- Una funzione incorporata chiama `valuta()` esattamente tante volte quanto la sua
  arietà e fa passare la posizione, restituendo infine l'*ultima* posizione ricevuta.

È questo che rende l'arietà "gratuita": non c'è una tabella centrale di arietà da mantenere.

---

## 5. Dall'arità fissa all'arità variabile

### 5.1 Il problema originale

La prima versione codificava rigidamente **esattamente due argomenti**:

```lua
if contesto[valore] then
  local indici = {indice+1, indice+1+1}   -- sempre 2 argomenti
  return contesto[valore]( indici )
end
```

Ciò costringeva le funzioni unarie come `scrivi` / `scrivi_rigo` a ricevere una
tabella `indici` di 2 elementi e a ignorarne semplicemente il secondo. Supportare
l'"arietà variabile" significa due cose:

1. **arietà fissa per funzione** — `scrivi` ne prende 1, `somma` 2, …
2. **realmente variadica** — una funzione che accetta un numero qualsiasi di argomenti.

### 5.2 Progetto A — tabella delle arietà (scartato)

Mantieni lo stile a tabella `indici`, ma consulta l'arietà di ogni parola chiave:

```lua
local arita = { scrivi=1, scrivi_rigo=1, somma=2, prodotto=2 }

local function valuta(indice)
  local valore = valori[indice]
  assert(type(valore)=="string")
  if contesto[valore] then
    local n = arita[valore] or 2
    local indici = {}
    for i=1,n do indici[i] = indice+i end
    return contesto[valore](indici)
  end
  return tonumber(valore) or tostring(valore)
end
```

- ✅ differenza minima; conserva le vecchie firme.
- ❌ richiede una tabella `arita` parallela mantenuta sincronizzata con `contesto`.
- ❌ non può esprimere funzioni *realmente variadiche* (l'arietà resta fissa).

> **Nota Lua:** non puoi attaccare metadati a una funzione — `f.arity = 2` lancia
> `attempt to index a function value`. Per fare un *callable con campi* useresti
> una tabella callable (`setmetatable({}, {__call = ...})`).

### 5.3 Progetto B — cursore / passaggio di posizione (scelto)

Cambia il contratto con un'unica **posizione** e restituisci `(valore, prossima_pos)`:

```lua
local function valuta(pos)
  local valore = valori[pos]
  assert(type(valore)=="string")
  if contesto[valore] then
    return contesto[valore]( pos + 1 )
  end
  return (tonumber(valore) or tostring(valore)), pos + 1
end

function contesto.somma ( pos )
  local a; a, pos = valuta(pos)
  local b; b, pos = valuta(pos)
  return a + b, pos
end
```

- ✅ arietà = "quante volte la funzione chiama `valuta()`" — 1, 2, 3 funzionano tutte.
- ✅ schema classico flusso-di-token / ricorsivo-discendente; cresce naturalmente in un parser.
- ⚠️ ogni funzione incorporata deve ricordarsi di restituire `(valore, pos)`.

---

## 6. Funzioni realmente variadiche

Due convenzioni comuni per una funzione che accetta un numero qualsiasi di argomenti:

### 6.1 Un token terminatore (usato qui)

```lua
function contesto.somma_tutti ( pos )
  local tot = 0
  local v
  while valori[pos] ~= "fine" do
    v, pos = valuta(pos)
    tot = tot + v
  end
  return tot, pos + 1
end
```

`somma_tutti 1 2 3 4 fine` → `10`. Il `pos + 1` salta lo stesso token `fine`.

### 6.2 Consuma fino alla fine del flusso

```lua
function contesto.somma_tutti ( pos )
  local tot = 0
  local v
  while pos <= #valori do
    v, pos = valuta(pos)
    tot = tot + v
  end
  return tot, pos
end
```

`somma_tutti 1 2 3 4` → `10`. Più semplice, ma usabile solo quando la chiamata
variadica è l'**ultima** cosa nel flusso (inghiotte tutto ciò che la segue).

> **Perché un terminatore?** La notazione prefissa senza parentesi ha esattamente
> tre modi per sapere dove finisce un'espressione: (a) conoscere l'arietà
> dell'operatore (`somma`), (b) racchiuderla in delimitatori (le `(...)` di Lisp),
> o (c) terminarla con una **sentinella** (`fine`). Il terminatore è l'opzione (c).

---

## 7. Esempi svolti

### 7.1 `somma 5 prodotto 4 2`

```
        somma
       /     \
      5    prodotto
            /   \
           4     2
```

`somma(5, prodotto(4,2))` = `5 + (4 × 2)` = `13`.

### 7.2 `somma prodotto 4 2 5` — stessa risposta, albero diverso

```
        somma
       /     \
  prodotto    5
   /   \
  4     2
```

`somma(prodotto(4,2), 5)` = `(4 × 2) + 5` = `13`.

Entrambi valgono **13** solo perché `+` è commutativa. Divergerebbero per un
operatore non commutativo, ad es. un ipotetico `sottrai`:

| espressione | aritmetica | valore |
|-----------|------------|-------|
| `sottrai prodotto 4 2 5` | `(4×2) − 5` | `3` |
| `sottrai 5 prodotto 4 2` | `5 − (4×2)` | `−3` |

### 7.3 Traccia del cursore per `somma prodotto 4 2 5`

| passo | `pos` | token | azione |
|------|-------|-------|--------|
| 1 | 1 | `scrivi_rigo` | chiamala, passa `pos=2` |
| 2 | 2 | `somma` | chiamala, passa `pos=3`; servono 2 arg |
| 3 | 3 | `prodotto` | chiamala, passa `pos=4`; servono 2 arg |
| 4 | 4 | `4` | letterale → `4`, prossimo `pos=5` |
| 5 | 5 | `2` | letterale → `2`, prossimo `pos=6` |
| 6 | — | — | `prodotto` = `8`, restituisce `pos=6` |
| 7 | 6 | `5` | letterale → `5`, prossimo `pos=7` |
| 8 | — | — | `somma` = `13`, restituisce `pos=7` |
| 9 | — | — | `scrivi_rigo` stampa `13` |

### 7.4 FizzBuzz (1..20)

L'intero insieme di controllo di flusso — variabili, confronti, `se`, `mentre` e
blocchi — si compone nel classico FizzBuzz:

```lua
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
```

Il `se cond ramo_vero ramo_falso` annidato forma una catena se/altrimenti: se
`i % 15 == 0` stampa `FizzBuzz`, altrimenti se `i % 3 == 0` stampa `Fizz`,
altrimenti se `i % 5 == 0` stampa `Buzz`, altrimenti stampa il numero:

```
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
16
17
Fizz
19
Buzz
```

---

## 8. Analisi di robustezza

### 8.1 Cosa la rende robusta

1. **Nessuno stato mutabile condiviso.** `valuta` restituisce `(valore, prossima_pos)`
   e ogni funzione incorporata fa passare `pos` attraverso i valori di ritorno. Un
   cursore globale/a livello di modulo verrebbe sovrascritto dalle chiamate
   annidate/ricorsive (il classico bug "chi ha spostato il mio cursore"); qui ogni
   frame di chiamata possiede la propria `pos`.
2. **L'arietà è locale.** Ogni funzione consuma esattamente tanti token quante volte
   chiama `valuta()`. Nessuna tabella centrale di arietà da tenere sincronizzata.
3. **Fallisce subito fuori dai limiti.** `assert(type(valore) == "string")` trasforma
   una lettura `nil` (andare oltre la fine) in un errore immediato.
4. **Percorso di lettura puro.** `valuta` legge solo `valori`; non muta mai il flusso
   di token, quindi la valutazione è rientrante e prevedibile.

### 8.2 Cosa è ancora fragile

1. **`somma_tutti` va in loop infinito senza il suo terminatore** — quando
   `valori[pos]` è `nil`, `nil ~= "fine"` è vero per sempre → si blocca.
2. **Il contratto `(valore, prossima_pos)` è convenzione, non imposizione** — una
   funzione incorporata che dimentica `return ..., pos` restituisce silenziosamente
   `nil` e spezza la catena senza un errore chiaro.
3. **Errori criptici** — `assert(...)` non ha messaggio, quindi un programma
   malformato riporta un nudo `assertion failed!` senza contesto di posizione/token.
4. **Nessun controllo di tipo** — `somma` su una stringa fallisce a runtime con
   `attempt to perform arithmetic on a string value`, lontano dalla causa.
5. **Nessun tokenizzatore / validazione dell'arietà** — `valori` è assemblato a
   mano; la vera stringa sorgente (`testo`) non viene mai analizzata.

### 8.3 Irrobustimento suggerito (prima le correzioni più piccole)

- Limita il ciclo variadico: `while valori[pos] and valori[pos] ~= "fine" do ... end`,
  poi verifica che il terminatore sia stato davvero trovato.
- Aggiungi un messaggio ad `assert` che riporti `pos` e il valore incriminato.
- Opzionalmente avvolgi la chiamata di livello più alto a `valuta` per catturare
  gli errori e stampare `pos`.

---

## 9. Insidie

1. **Shadowing del cursore.** Dentro un ciclo devi scrivere `v, pos = valuta(pos)`
   (riassegna il parametro), **non** `local v, pos = valuta(pos)`. La forma `local`
   dichiara una nuova `pos` con scope sul corpo del ciclo, quindi il cursore esterno
   non avanza mai — un loop infinito.
2. **`print(valuta(1))` stampa due valori.** Poiché `valuta` restituisce
   `(valore, prossima_pos)`, un `print(valuta(1))` nudo stampa entrambi (separati da tab).
   Cattura solo il primo: `local v = valuta(1); print(v)`.
3. **Verità in Lua.** Solo `nil` e `false` sono falsi, quindi `tonumber("0")` →
   `0` va bene (restituisce `0`, non `""`), e `tonumber(valore) or tostring(valore)`
   si comporta correttamente per lo zero.
4. **Le funzioni non possono portare metadati.** `f.arity = 2` lancia
   `attempt to index a function value`; usa una tabella callable per quello.

---

## 10. Discendenza informatico-storica

Non c'è un unico nome canonico per l'intera combinazione, ma è una composizione
pulita di **diverse idee classiche**, ognuna con il suo nome e la sua storia.

### 10.1 Interprete ricorsivo-discendente

`valuta` + `contesto.*` è un **parser ricorsivo-discendente scritto a mano fuso
con il suo valutatore** — ogni produzione grammaticale è una funzione che consuma
input e produce un valore. Quando parser e valutatore sono fusi, a volte si chiama
interprete a **esecuzione diretta** o **diretto dalla sintassi** (vs. la classica
pipeline "lex → parse in AST → cammina l'AST").

- **Storia:** la discesa ricorsiva risale ai **compilatori dell'era ALGOL degli
  anni '60**, resa popolare da **Niklaus Wirth** (*Algorithms + Data Structures =
  Programs*, 1976) e canonizzata nel **"Dragon Book"** (Aho, Sethi, Ullman,
  *Compilers*, 1986). La discesa ricorsiva scritta a mano guida ancora molti
  compilatori e interpreti reali.

### 10.2 State threading / combinatori di parser

La firma del valutatore a cursore è la parte con un nome:

```
s -> (a, s)                    -- prendi stato, restituisci valore + stato NUOVO
```

Questo è lo **state threading** (stile state-passing), ed è letteralmente la
funzione `run` della **State monad**:

```haskell
runState :: s -> (a, s)
```

Nel parsing, un parser è definito canonicamente come una funzione dall'input a un
valore e all'**input rimanente**:

```haskell
type Parser a = String -> (a, String)
```

È esattamente `valuta(pos) -> (valore, prossima_pos)`, con l'"input rimanente"
rappresentato come indice intero invece che come stringa tagliata.

- **Storia:** il parsing funzionale va **Burge (1975) → "How to Replace Failure by
  a List of Successes" di Philip Wadler (1985) → "Higher-Order Functions for
  Parsing" di Graham Hutton (1992)**. Le monadi furono introdotte da **Moggi
  (1989)** e rese popolari da **"Monads for Functional Programming" di Wadler
  (1992–95)**. L'idea correlata di "cursore in una struttura" fu chiamata
  indipendentemente da **"The Zipper" di Gérard Huet (1997)** (uno zipper naviga
  un albero sul posto; un cursore di parser consuma un flusso).

### 10.3 Notazione polacca

Scrivere `somma 5 prodotto 4 2` (operatore prima degli operandi) è **notazione
prefissa / polacca**, inventata dal logico **Jan Łukasiewicz** (concepita ~**1924**,
pubblicata **1929**) per scrivere la logica senza parentesi. Il suo sistema
originale funzionava conoscendo l'**arietà** di ogni operatore — esattamente il
motivo per cui qui le funzioni ad arietà fissa non hanno bisogno di parentesi.

### 10.4 Sequenze terminate da sentinella

Usare `fine` per delimitare una lista di lunghezza variabile è la classica idea di
**valore sentinella / sequenza terminata da sentinella**. L'esempio quotidiano
canonico è la **stringa terminata da NUL in C**: una sequenza senza campo di
lunghezza, conclusa da un marcatore riservato — strutturalmente identica a
`while valori[pos] ~= "fine"`.

### 10.5 Parenti più stretti

- **Lisp / S-espressioni** — John McCarthy, **1958** — notazione prefissa, ma
  risolve il problema del confine con le parentesi invece che con arietà/terminatori.
  Il tuo `contesto` (una tabella di funzioni incorporate nominate) è cugino
  dell'*oblist* di Lisp.
- **Forth** — Chuck Moore, fine **anni '60** — lo stesso spirito "tutto è una
  parola, interprete minimale", ma **postfisso/RPN** e basato su stack invece che
  prefisso/ricorsivo.

### 10.6 Linea del tempo

| Anno | Chi | Contributo |
|------|-----|--------------|
| 1924/29 | Łukasiewicz | notazione polacca (prefissa) |
| 1958 | McCarthy | Lisp / S-espressioni |
| anni '60 | comunità ALGOL | parsing ricorsivo-discendente |
| fine anni '60 | Moore | Forth |
| 1975 | Burge | primi parser a combinatori |
| 1985 | Wadler | parsing a lista di successi |
| 1989 | Moggi | monadi |
| 1992 | Hutton | `Parser a = String -> [(a, String)]` |
| 1992–95 | Wadler | monadi per la programmazione funzionale |
| 1997 | Huet | lo Zipper |

### 10.7 Riassunto in una riga

> È un **interprete ricorsivo-discendente con state threading** su token in
> **notazione polacca**, con variadiche gestite da una **sequenza terminata da
> sentinella** — quattro idee vecchie, con nomi indipendenti, collegate in circa
> 60 righe. Ecco perché sembra classico e robusto: è un piccolo sottoinsieme,
> collaudato dal tempo, di come gli interpreti sono stati scritti dagli anni '60.

---

## 11. Esecuzione

```bash
lua5.4 mini.lua        # esegui l'interprete
lua5.4 glossario.lua   # rigenera il glossario delle parole chiave (§3.2)
```

Output di `mini.lua`:

```
13
10
100
13
10
5
5
Fizz
1
true
true
true
a
b
3
vero
falso
si
1
2
3
1
2
3
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
16
17
Fizz
19
Buzz
1
2
Fizz
4
Buzz
Fizz
7
8
Fizz
Buzz
11
Fizz
13
14
FizzBuzz
16
17
Fizz
19
Buzz
13
Hello World
1
2
3
ciao
a
b
it's
10
25
ciao
14
15
120
18
```

(funzionano `lua`, `lua5.4`, `lua5.1` o `luajit`.)

---

## 12. Riferimenti

- Aho, Sethi, Ullman — *Compilers: Principles, Techniques, and Tools* (1986).
- N. Wirth — *Algorithms + Data Structures = Programs* (1976).
- J. Łukasiewicz — sulla notazione polacca (1924/1929).
- J. McCarthy — *Recursive Functions of Symbolic Expressions…* (1960).
- W. H. Burge — *Recursive Programming Techniques* (1975).
- P. Wadler — *How to Replace Failure by a List of Successes* (1985).
- G. Hutton — *Higher-Order Functions for Parsing* (1992).
- E. Moggi — *Computational Lambda-Calculus and Monads* (1989).
- P. Wadler — *Monads for Functional Programming* (1992–95).
- G. Huet — *The Zipper* (1997).
