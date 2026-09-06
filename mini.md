# `mini.lua` — a minimal prefix-notation interpreter

> A ~60-line recursive-descent interpreter for a tiny **prefix (Polish-notation)**
> language, written in Lua. This document is a full recap of the design, the
> fixed→variable-arity evolution, worked examples, robustness notes, gotchas, and
> the computer-science lineage behind it.
>
> *Disponibile anche in italiano: [`mini.it.md`](mini.it.md)*

---

## Table of contents

1. [Overview](#1-overview)
2. [The language](#2-the-language)
3. [Glossary](#3-glossary)
4. [Current implementation (Design B)](#4-current-implementation-design-b)
5. [From fixed arity to variable arity](#5-from-fixed-arity-to-variable-arity)
6. [Truly variadic functions](#6-truly-variadic-functions)
7. [Worked examples](#7-worked-examples)
8. [Robustness analysis](#8-robustness-analysis)
9. [Gotchas](#9-gotchas)
10. [Computer-science lineage](#10-computer-science-lineage)
11. [Running it](#11-running-it)
12. [References](#12-references)

---

## 1. Overview

`mini.lua` is a **minimal interpreter** for a prefix-notation language where:

- a "program" is a flat array of tokens (`valori`);
- a token is either a **keyword** (a built-in function) or a **literal** (number / string);
- `valuta` (Italian: *"evaluate"*) walks the token stream recursively;
- each keyword knows how many arguments it consumes (its **arity**), so the
  language needs **no parentheses**.

It demonstrates a classic interpreter pattern in a very small space. It now has
variables (`metti`/`prendi`) and user-defined functions (`funzione`), and remains
a natural seed for a larger language (a real AST, arrays, etc.). A `tokenizza`
(tokenize) front-end is already included: it
splits a source string into the flat `valori` array, so a program can be typed
as plain text instead of a hand-written token array.

## 2. The language

| Construct | Example | Meaning |
|-----------|---------|---------|
| `scrivi` | `scrivi 5` | print a value (no newline) |
| `scrivi_rigo` | `scrivi_rigo 5` | print a value + newline |
| `somma` | `somma 5 6` | add two values (`+`) |
| `prodotto` | `prodotto 4 2` | multiply two values (`*`) |
| `sottrai` | `sottrai 5 2` | subtract two values (`-`) |
| `somma_tutti` | `somma_tutti 1 2 3 4 fine` | **variadic** sum, terminated by `fine` |
| `metti` | `metti i 1` | assign a value to a variable |
| `prendi` | `prendi i` | read a variable's value |
| `modulo` | `modulo 7 3` | remainder (`%`) |
| `uguale` | `uguale 1 1` | equality test (`==`) |
| `maggiore` | `maggiore 5 3` | greater-than test (`>`) |
| `non` | `non uguale 1 2` | logical negation (`not`) |
| `fai` | `fai ... fine` | a block: sequence of statements, returns the last value |
| `se` | `se cond ramo_vero ramo_falso` | if/else (lazy: only the taken branch runs) |
| `mentre` | `mentre cond corpo` | while-loop (condition re-evaluated each iteration) |
| `funzione` | `funzione nome x fine prodotto prendi x 2` | define a named function (lexical scope) |
| `lambda` | `lambda x fine prodotto prendi x 2` | an anonymous function **value** (first-class) |
| `chiama` | `chiama prendi f 5 fine` | call a function value (args terminated by `fine`) |

Expressions nest recursively, e.g.
`scrivi_rigo somma 5 prodotto 4 2` evaluates to `5 + (4 × 2) = 13`.

Every keyword has an English alias — `somma` ≡ `sum`, `prodotto` ≡ `product`,
`scrivi_rigo` ≡ `writeline`, `somma_tutti` ≡ `sumall`, `fine` ≡ `end` — see
[§3.2](#32-keyword-aliases-italian--english). The variadic terminator may be
either `fine` or `end`.

Values can be stored in variables with `metti` (assign) and read back with
`prendi` (get). String literals are written between matching quotes (`'Fizz'` or
`"Fizz"`); the quotes are stripped when the literal is evaluated. Escapes inside
literals (`\n`, `\t`, `\'`, `\"`, `\\`) are decoded, and `--` starts a comment
that runs to the end of the line.

Comparison words (`uguale`, `maggiore`, `non`) produce boolean values
(`true`/`false`), which the control-flow words (introduced later) rely on.
`fai ... fine` groups several statements into a single block, returning the last value.
`se cond ramo_vero ramo_falso` picks one branch; the un-taken branch is parsed but
not executed, so its side effects never happen.
`mentre cond corpo` repeats the body while the condition is true; the condition is
re-evaluated each iteration.

`funzione nome param1 param2 ... fine corpo` defines a named function. The
parameter list ends at the first `fine`; the body is a single expression (wrap
several statements in `fai ... fine`) and returns its last value, exactly like
`fai`. Parameters are read with `prendi`, and are **lexically scoped**: the
function captures the scope in which it is defined, so a function defined inside
another keeps seeing its parameters even after the outer one returns. Recursion
is supported, e.g.
`funzione fatto n fine se uguale prendi n 0 1 prodotto prendi n fatto sottrai prendi n 1`.

`lambda parametri... fine corpo` creates an **anonymous function value** — the same
closure as `funzione`, but returned instead of registered. Because functions are
now first-class values, they can be stored in variables (`metti`), passed as
arguments, and returned from other functions (higher-order functions). `chiama f
arg... fine` calls a function value `f`; its arguments end at the `fine`/`end`
terminator. For example, `chiama prendi f 5 fine` calls the function held in
variable `f` with `5`.

## 3. Glossary

### 3.1 Code identifiers (internal names)

| Italian | English |
|---------|---------|
| `contesto` | context / environment (table of built-ins) |
| `valuta` | evaluate |
| `valori` | values (the token array) |
| `indice` / `indici` | index / indices |
| `pos` | position (cursor into `valori`) |
| `testo` | text (the source string, split into `valori` by `tokenizza`) |
| `tokenizza` | tokenize (splits `testo` into the `valori` token array) |
| `ambiente` | environment / scope (linked chain of variable scopes) |
| `nuovo_ambito` / `trova_ambito` | new-scope / find-scope (lexical-scope helpers) |
| `decodifica` | decode (decodes `\n`, `\t`, `\'`, `\"`, `\\` in string literals) |

### 3.2 Keyword aliases (Italian ↔ English)

> Generated from `lessico.lua` — the single source of truth. Regenerate with
> `lua5.4 glossario.lua`. Both forms are accepted as keywords.

| Italian | English |
|---------|---------|
| `chiama` | `call` |
| `fai` | `do` |
| `fine` | `end` |
| `funzione` | `function` |
| `lambda` | `lambda` |
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

| English | Italian |
|---------|---------|
| `call` | `chiama` |
| `do` | `fai` |
| `end` | `fine` |
| `equal` | `uguale` |
| `function` | `funzione` |
| `get` | `prendi` |
| `greater` | `maggiore` |
| `if` | `se` |
| `lambda` | `lambda` |
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

## 4. Current implementation (Design B)

The complete, working source (cursor / position-passing style):

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

### The contract

Every built-in obeys the same convention:

> **takes a `pos` (cursor), returns `(value, next_pos)`.**

- `valuta(pos)` returns `(value, next_pos)`; for a literal it advances by 1,
  for a keyword it delegates to the built-in and forwards its returned position.
- A built-in calls `valuta()` exactly as many times as its arity and threads the
  position through, finally returning the *last* position it received.

This is what makes arity "free": there is no central arity table to maintain.

---

## 5. From fixed arity to variable arity

### 5.1 The original problem

The first version hard-coded **exactly two arguments**:

```lua
if contesto[valore] then
  local indici = {indice+1, indice+1+1}   -- always 2 args
  return contesto[valore]( indici )
end
```

That forced unary functions like `scrivi` / `scrivi_rigo` to receive a
2-element `indici` table and simply ignore the second element. Supporting
"variable arity" means two things:

1. **per-function fixed arity** — `scrivi` takes 1, `somma` takes 2, …
2. **truly variadic** — one function accepting any number of arguments.

### 5.2 Design A — arity table (rejected)

Keep the `indici`-table style, but look up each keyword's arity:

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

- ✅ minimal diff; preserves the old signatures.
- ❌ needs a parallel `arita` table kept in sync with `contesto`.
- ❌ cannot express *truly variadic* functions (arity is still fixed).

> **Lua note:** you cannot attach metadata to a function — `f.arity = 2` throws
> `attempt to index a function value`. To make a *callable with fields* you'd use
> a callable table (`setmetatable({}, {__call = ...})`).

### 5.3 Design B — cursor / position passing (chosen)

Change the contract to a single **position** and return `(value, next_pos)`:

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

- ✅ arity = "how many times the function calls `valuta()`" — 1, 2, 3 all work.
- ✅ classic token-stream / recursive-descent pattern; grows naturally into a parser.
- ⚠️ every built-in must remember to return `(value, pos)`.

---

## 6. Truly variadic functions

Two common conventions for a function that takes any number of arguments:

### 6.1 A terminator token (used here)

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

`somma_tutti 1 2 3 4 fine` → `10`. The `pos + 1` skips the `fine` token itself.

### 6.2 Consume to end of stream

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

`somma_tutti 1 2 3 4` → `10`. Simpler, but only usable when the variadic call
is the **last** thing in the stream (it swallows everything after it).

> **Why a terminator at all?** Prefix notation without parentheses has exactly
> three ways to know where an expression ends: (a) know the operator's arity
> (`somma`), (b) wrap it in delimiters (Lisp's `(...)`), or (c) end it with a
> **sentinel** (`fine`). The terminator is option (c).

---

## 7. Worked examples

### 7.1 `somma 5 prodotto 4 2`

```
        somma
       /     \
      5    prodotto
            /   \
           4     2
```

`somma(5, prodotto(4,2))` = `5 + (4 × 2)` = `13`.

### 7.2 `somma prodotto 4 2 5` — same answer, different tree

```
        somma
       /     \
  prodotto    5
   /   \
  4     2
```

`somma(prodotto(4,2), 5)` = `(4 × 2) + 5` = `13`.

Both evaluate to **13** only because `+` is commutative. They would diverge for a
non-commutative operator, e.g. a hypothetical `sottrai` (subtract):

| expression | arithmetic | value |
|-----------|------------|-------|
| `sottrai prodotto 4 2 5` | `(4×2) − 5` | `3` |
| `sottrai 5 prodotto 4 2` | `5 − (4×2)` | `−3` |

### 7.3 Cursor trace for `somma prodotto 4 2 5`

| step | `pos` | token | action |
|------|-------|-------|--------|
| 1 | 1 | `scrivi_rigo` | call it, pass `pos=2` |
| 2 | 2 | `somma` | call it, pass `pos=3`; needs 2 args |
| 3 | 3 | `prodotto` | call it, pass `pos=4`; needs 2 args |
| 4 | 4 | `4` | literal → `4`, next `pos=5` |
| 5 | 5 | `2` | literal → `2`, next `pos=6` |
| 6 | — | — | `prodotto` = `8`, returns `pos=6` |
| 7 | 6 | `5` | literal → `5`, next `pos=7` |
| 8 | — | — | `somma` = `13`, returns `pos=7` |
| 9 | — | — | `scrivi_rigo` prints `13` |

### 7.4 FizzBuzz (1..20)

The full control-flow set — variables, comparisons, `se`, `mentre`, and blocks —
composes into the classic FizzBuzz:

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

The nested `se cond ramo_vero ramo_falso` forms an if/else-if chain: if
`i % 15 == 0` print `FizzBuzz`, else if `i % 3 == 0` print `Fizz`, else if
`i % 5 == 0` print `Buzz`, otherwise print the number:

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

### 7.5 Higher-order functions (functions as values)

`lambda` builds a function value, `chiama` calls one. A named `funzione` can
return a function (a closure factory) and accept one as a parameter:

```lua
-- a function that RETURNS a function (captures k)
funzione crea_moltiplicatore k fine lambda x fine prodotto prendi x prendi k
metti per_3 crea_moltiplicatore 3
scrivi_rigo chiama prendi per_3 7 fine        -- 21

-- a function that ACCEPTS a function
funzione applica_due f fine chiama prendi f 2 fine
scrivi_rigo applica_due lambda x fine prodotto prendi x 2   -- 4
```

---

## 8. Robustness analysis

### 8.1 What makes it robust

1. **No shared mutable state.** `valuta` returns `(value, next_pos)` and each
   built-in threads `pos` through return values. A global/module-level cursor
   would be clobbered by nested/recursive calls (the classic "who moved my
   cursor" bug); here each call frame owns its `pos`.
2. **Arity is local.** Each function consumes exactly as many tokens as it calls
   `valuta()`. No central arity table to keep in sync.
3. **Fails fast on out-of-bounds.** `assert(type(valore) == "string")` turns a
   `nil` read (walking past the end) into an immediate error.
4. **Pure read path.** `valuta` only reads `valori`; it never mutates the token
   stream, so evaluation is re-entrant and predictable.

### 8.2 What's still fragile

1. **`somma_tutti` infinite-loops without its terminator** — when `valori[pos]`
   is `nil`, `nil ~= "fine"` is forever true → hangs.
2. **The `(value, next_pos)` contract is convention, not enforcement** — a
   built-in that forgets `return ..., pos` silently returns `nil` and breaks the
   chain with no clear error.
3. **Cryptic errors** — `assert(...)` has no message, so a malformed program
   reports a bare `assertion failed!` with no position/token context.
4. **No type checking** — `somma` on a string fails at runtime with
   `attempt to perform arithmetic on a string value`, far from the cause.
5. **No tokenizer / arity validation** — `valori` is hand-assembled; the real
   source string (`testo`) is never parsed.

### 8.3 Suggested hardening (smallest fixes first)

- Bound the variadic loop: `while valori[pos] and valori[pos] ~= "fine" do ... end`,
  then assert the terminator was actually found.
- Add a message to `assert` reporting `pos` and the offending value.
- Optionally wrap the top-level `valuta` call to catch errors and print `pos`.

---

## 9. Gotchas

1. **Cursor shadowing.** Inside a loop you must write `v, pos = valuta(pos)`
   (reassign the parameter), **not** `local v, pos = valuta(pos)`. The `local`
   form declares a brand-new `pos` scoped to the loop body, so the outer cursor
   never advances — an infinite loop.
2. **`print(valuta(1))` prints two values.** Since `valuta` returns
   `(value, next_pos)`, a bare `print(valuta(1))` prints both (tab-separated).
   Capture only the first: `local v = valuta(1); print(v)`.
3. **Lua truthiness.** Only `nil` and `false` are falsy, so `tonumber("0")` →
   `0` is fine (returns `0`, not `""`), and `tonumber(valore) or tostring(valore)`
   behaves correctly for zero.
4. **Functions can't carry metadata.** `f.arity = 2` raises
   `attempt to index a function value`; use a callable table for that.

---

## 10. Computer-science lineage

There is no single canonical name for the whole combination, but it is a clean
composition of **several classic ideas**, each with its own name and history.

### 10.1 Recursive-descent interpreter

`valuta` + `contesto.*` is a hand-written **recursive-descent parser fused with
its evaluator** — each grammar production is a function that consumes input and
produces a value. When parser and evaluator are merged, it's sometimes called a
**direct-execution** or **syntax-directed** interpreter (vs. the classic
"lex → parse to AST → walk AST" pipeline).

- **History:** recursive descent dates to the **ALGOL-era compilers of the 1960s**,
  popularized by **Niklaus Wirth** (*Algorithms + Data Structures = Programs*, 1976)
  and canonized in the **"Dragon Book"** (Aho, Sethi, Ullman, *Compilers*, 1986).
  Hand-written recursive descent still drives many real compilers and interpreters.

### 10.2 State threading / parser combinators

The signature of the cursor evaluator is the named part:

```
s -> (a, s)                    -- take state, return value + NEW state
```

This is **state threading** (state-passing style), and is literally the `run`
function of the **State monad**:

```haskell
runState :: s -> (a, s)
```

In parsing, a parser is canonically defined as a function from input to a value
and the **remaining input**:

```haskell
type Parser a = String -> (a, String)
```

That is exactly `valuta(pos) -> (value, next_pos)`, with "remaining input"
represented as an integer index instead of a sliced string.

- **History:** functional parsing runs **Burge (1975) → Philip Wadler's "How to
  Replace Failure by a List of Successes" (1985) → Graham Hutton's "Higher-Order
  Functions for Parsing" (1992)**. Monads were introduced by **Moggi (1989)** and
  popularized by **Wadler's "Monads for Functional Programming" (1992–95)**. The
  related "cursor into a structure" idea was independently named by **Gérard
  Huet's "The Zipper" (1997)** (a zipper navigates a tree in place; a parser
  cursor consumes a stream).

### 10.3 Polish notation

Writing `somma 5 prodotto 4 2` (operator before operands) is **prefix / Polish
notation**, invented by logician **Jan Łukasiewicz** (conceived ~**1924**,
published **1929**) to write logic without parentheses. His original system
worked by knowing each operator's **arity** — exactly why fixed-arity functions
here need no parentheses.

### 10.4 Sentinel-terminated sequences

Using `fine` to delimit a variable-length list is the classic **sentinel value /
sentinel-terminated sequence** idea. The canonical everyday example is the
**NUL-terminated string in C**: a sequence with no length field, ended by a
reserved marker — structurally identical to `while valori[pos] ~= "fine"`.

### 10.5 Closest relatives

- **Lisp / S-expressions** — John McCarthy, **1958** — prefix notation, but solves
  the boundary problem with parentheses instead of arity/terminators. Your
  `contesto` (a table of named built-ins) is a cousin of Lisp's *oblist*.
- **Forth** — Chuck Moore, late **1960s** — the same "everything is a word,
  minimal interpreter" spirit, but **postfix/RPN** and stack-based rather than
  prefix/recursive.

### 10.6 Timeline

| Year | Who | Contribution |
|------|-----|--------------|
| 1924/29 | Łukasiewicz | Polish (prefix) notation |
| 1958 | McCarthy | Lisp / S-expressions |
| 1960s | ALGOL community | recursive-descent parsing |
| late 1960s | Moore | Forth |
| 1975 | Burge | early combinator parsing |
| 1985 | Wadler | list-of-successes parsing |
| 1989 | Moggi | monads |
| 1992 | Hutton | `Parser a = String -> [(a, String)]` |
| 1992–95 | Wadler | monads for functional programming |
| 1997 | Huet | the Zipper |

### 10.7 One-line summary

> It's a **state-threaded recursive-descent interpreter** over **Polish-notation**
> tokens, with variadics handled by a **sentinel-terminated sequence** — four old,
> independently-named ideas wired together in about 60 lines. That is why it feels
> classic and robust: it's a small, time-tested subset of how interpreters have
> been written since the 1960s.

---

## 11. Running it

```bash
lua5.4 mini.lua        # run the interpreter
lua5.4 glossario.lua   # regenerate the keyword glossary (§3.2)
```

Output of `mini.lua`:

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

(`lua`, `lua5.4`, `lua5.1`, or `luajit` all work.)

---

## 12. References

- Aho, Sethi, Ullman — *Compilers: Principles, Techniques, and Tools* (1986).
- N. Wirth — *Algorithms + Data Structures = Programs* (1976).
- J. Łukasiewicz — on Polish notation (1924/1929).
- J. McCarthy — *Recursive Functions of Symbolic Expressions…* (1960).
- W. H. Burge — *Recursive Programming Techniques* (1975).
- P. Wadler — *How to Replace Failure by a List of Successes* (1985).
- G. Hutton — *Higher-Order Functions for Parsing* (1992).
- E. Moggi — *Computational Lambda-Calculus and Monads* (1989).
- P. Wadler — *Monads for Functional Programming* (1992–95).
- G. Huet — *The Zipper* (1997).



