# Porting `mini copy.lua` → C++ (`cpp/mini_copy.cpp`)

This document records the porting of **`mini copy.lua`** to C++, from the
original request through every design decision, the implementation, the issues
hit, and the final verification. It is written so the whole journey — request →
reasoning → result — can be reconstructed from a single file.

---

## 1. The original request (verbatim)

> consider porting faithfully "mini copy.lua" into C++ files located in /cpp/
> and notice that Lua files are not 0-based-index (C++ is) but 1-based-index .
> in C++ use STL etc as convenient and to ease the porting .

Three requirements are embedded in that one sentence:

1. **Faithful** — the C++ must mirror the Lua's structure and behaviour, not a
   loose "re-implementation".
2. **1-based → 0-based** — Lua arrays are indexed from `1`, C++ from `0`; the
   port must handle that shift correctly.
3. **Use the STL** — `std::vector`, `std::map`, `std::variant`, `std::optional`,
   `std::function`, etc., to ease the translation of Lua's dynamic, table-based
   style.

---

## 2. Starting point / reconnaissance

First, the workspace was explored to locate the target and its surroundings:

- **Target:** `/home/arkenidar/code/dev-lua/mini copy.lua` — a self-contained
  ~150-line file.
- **Related files** (context only): `mini.lua` (the larger interpreter),
  `lessico.lua` (bilingual keyword dictionary), `glossario.lua` (Markdown
  generator), `mini.md` / `mini.it.md` (design docs), `.vscode/launch.json`
  (which actually launches `mini copy.lua`).

The **reference output** was captured by running the interpreter, because the
port's success criterion is to reproduce it byte-for-byte:

```text
'100'
11
11
'100'
13
13
1
6
111
222
333
333
```

Environment checks:

- `g++` (Debian 14.2.0) available — C++17 (and above) fully supported.
- `/home/arkenidar/code/dev-lua/cpp/` already existed and was **empty**.

---

## 3. What `mini copy.lua` actually is

It is a minimal **prefix (Polish-notation)** interpreter:

- A "program" is a **flat array of tokens** stored in `valori`.
- A token is either a **built-in call** (`somma#2`, `scrivi_rigo#1`, …) or a
  **literal** (`5`, `'100'`, …). The `#arity` suffix records how many arguments
  a keyword consumes, which is why the language needs **no parentheses**.
- Built-ins live in a table `contesto`.

The moving parts are:

| Lua name | Role |
|----------|------|
| `contesto` | table of built-in functions (`scrivi`, `somma`, `se`, …) |
| `valori`   | the flat token array |
| `split_int(text)` | split `word#arity` → `(arity, word)`, or `nil` |
| `appendice(testo)` | just forwards to `split_int` |
| `misura(indice)` | number of tokens consumed by the expression at `indice` |
| `valuta(indice)` | evaluate the expression at `indice` |
| `fai(indice)` | evaluate a `do … end` block |
| `sequenza(indice)` | evaluate every expression to the end of `valori` |
| `contesto.scrivi` / `scrivi_rigo` | write a value (no / with newline) |
| `contesto.somma` / `prodotto` | `+` / `*` |
| `contesto.se` | ternary if/else (lazy) |
| `contesto.vero` / `falso` | boolean constants |

The file ends with a **test section** that assigns several `valori` arrays and
calls `valuta` / `misura` / `sequenza` on them, producing the 12 lines above.

---

## 4. The plan and the key decisions

Before writing any C++, the following decisions were fixed (and stated in the
plan-mode message):

1. **Single self-contained file** — `cpp/mini_copy.cpp`, mirroring the fact
   that the Lua source is a single self-contained script.
2. **Faithful naming** — keep the Italian identifiers (`contesto`, `valori`,
   `valuta`, `misura`, `fai`, `sequenza`, `appendice`, `split_int`, `indici`,
   `cursore`, `restituito`, …) so the C++ diffs 1:1 against the Lua.
3. **STL for dynamism** — a `std::variant` value type, `std::map` for
   `contesto`, `std::optional` for `split_int`'s "two values or nil", and
   `std::function` for the built-ins.
4. **Minimal index conversion** — recognize that most of the index arithmetic
   is base-invariant (detailed in §6).

---

## 5. Construct-by-construct mapping (how & why)

### 5.1 Dynamic values → `std::variant`

Lua values in this interpreter are **dynamically typed** and can be `nil`, a
boolean, a number, or a string. The C++ equivalent is:

```cpp
using Valore = std::variant<std::nullptr_t, bool, double, std::string>;
```

- `std::nullptr_t` is the sentinel for Lua's single `nil`.
- `double` stands in for Lua's `number` (Lua numbers are doubles by default).
- `std::string` for string literals.

`valuta` returns this variant, exactly as the Lua `valuta` can return `nil`
(from `scrivi`/`scrivi_rigo`), a boolean (`vero`/`falso`), a number
(`tonumber`), or a string (`tostring`).

### 5.2 The token array and the context table → STL containers

```cpp
std::vector<std::string> valori;             // Lua: local valori = {}
std::map<std::string, Funzione> contesto;    // Lua: local contesto = {}
```

`valori` is a `std::vector<std::string>` (Lua's `{}` sequence). `contesto` is a
`std::map<std::string, Funzione>` (Lua's string-keyed table).

### 5.3 Built-in functions → `std::function`

```cpp
using Indici = std::vector<std::size_t>;     // Lua: indici = { ... }
using Funzione = std::function<Valore(const Indici&)>;
```

A Lua built-in is `function contesto.somma(indici) … end`, taking a table of
indices. The C++ analogue is a `std::function` taking `const Indici&`. The
named free functions (`scrivi`, `somma`, `se`, …) are then stored in the map:

```cpp
contesto["somma"] = somma;
```

### 5.4 `tonumber` / `tostring` → small helpers

- Lua `tonumber(s)` (nil on failure) → `std::optional<double> tonumber_lua(...)`
  using `std::strtod` with a full-consumption check.
- Lua `tostring(v)` → `std::string tostringa(const Valore&)`. It special-cases
  whole `double`s so they print without a trailing `.0` (see §7).

### 5.5 `split_int` multi-return → `std::optional<std::pair<double, std::string>>`

Lua's `split_int` returns **two values** `(uint, prefix)` or **nil**. C++ can't
return a variable number of values, so:

```cpp
std::optional<std::pair<double, std::string>> split_int(const std::string& text);
```

- No `#` → `std::nullopt` (Lua `nil`).
- Suffix not `^%d+$` → `std::nullopt`.
- Otherwise → `{ uint, prefix }`.

`appendice(testo)` is simply `return split_int(testo);`, exactly as in Lua.

### 5.6 Mutual recursion → forward declarations

In Lua, `valuta` calls `fai`, and `fai` (assigned later) calls `valuta`; the
`local fai` line declares it early. The C++ port mirrors this with forward
declarations before the definitions:

```cpp
std::size_t misura(std::size_t indice);
Valore valuta(std::size_t indice);
Valore fai(std::size_t indice);
Valore sequenza(std::size_t indice);
```

### 5.7 Bounds/type assertions

Lua's `assert(type(valore) == "string")` fails when `valori[indice]` is out of
range (reading a missing element yields `nil`). The C++ port uses
`valori.at(indice)`, which throws on out-of-range access — the same "fail fast"
behaviour. The explicit `assert(valore == "do")` in `fai` stays as a real
`assert`.

---

## 6. The 1-based → 0-based conversion (the key requirement)

This is the requirement the request explicitly called out: **Lua arrays are
1-based, C++ containers are 0-based.** The port had to handle the shift
correctly without subtly corrupting the walkers.

The key insight is that almost all of the index arithmetic in the Lua source is
**base-invariant**, i.e. it means the same thing whether indices start at 0 or
at 1:

- `cursore + 1` — "advance to the **next token**". Next position is `+1` in
  *both* bases.
- `cursore + misura(cursore)` — "skip a measured **number of tokens**".
  `misura` returns a *count*, not a position.
- `return cursore - indice` and `return cursore - indice + 1` — these compute a
  **token count** (a difference of two positions). A difference is identical
  in both bases.

Because of that, **all of `misura`, `valuta`, and `fai` were ported literally,
line for line**, with the exact same `+1` and `- indice` expressions as the Lua.

Only **two** places actually depend on the base and had to change:

1. **The entry-point indices in the test section** — the Lua literals
   `{1}`, `{3, 4}`, `valuta(2)`, `valuta(1)`, `misura(1)`, `sequenza(1)` are
   1-based and become 0-based:

   | Lua (1-based) | C++ (0-based) |
   |---------------|---------------|
   | `contesto.scrivi_rigo({1})` | `contesto.at("scrivi_rigo")({0})` |
   | `contesto.somma({3, 4})` | `contesto.at("somma")({2, 3})` |
   | `valuta(2)` | `valuta(1)` |
   | `valuta(1)` | `valuta(0)` |
   | `misura(1)` | `misura(0)` |
   | `sequenza(1)` | `sequenza(0)` |

2. **`sequenza`'s loop bound** — Lua's `while cursore <= #valori do` means
   "while `cursore` is a valid 1-based index". In C++, valid 0-based indices
   are `0 <= cursore < valori.size()`, so the condition becomes
   `while (cursore < valori.size())`.

This is documented in the source's header comment and inline where each
conversion happens, so the mapping is auditable at a glance.

---

## 7. Issues encountered & fixes

Two problems surfaced on the first compile, both mechanical:

1. **`[[nodiscard]]` warning on a bare `.at()`** — in `sequenza`, the line
   mirroring Lua's `assert(type(valore) == "string")` was written as
   `valori.at(indice);`. `std::vector::at` is marked `[[nodiscard]]`, so g++
   warned about the ignored result. Fix: cast the expression to `void`:
   `(void)valori.at(indice);`. (The call still performs the bounds check; the
   cast just tells the compiler the value is intentionally unused.)

2. **`print(misura(1))` type mismatch** — Lua's `print(misura(1))` prints the
   number `6`, but `misura` returns a `std::size_t`, while the `stampa`
   (print) helper only accepted `const Valore&`. A `std::size_t` does not
   implicitly convert to the variant. Fix: add a numeric overload
   `void stampa(double v) { stampa(Valore{v}); }`, so `stampa(misura(0))`
   works and prints `6` (a whole `double` rendered as `"6"`).

Both fixes are small and visible in `cpp/mini_copy.cpp`.

---

## 8. Verification

The port was validated two ways.

**Build (clean, with warnings-as-errors):**

```bash
cd /home/arkenidar/code/dev-lua/cpp
g++ -std=c++17 -Wall -Wextra -Werror -pedantic -o mini_copy mini_copy.cpp
```

**Output comparison (byte-for-byte):**

```bash
./mini_copy                  > /tmp/cpp_out.txt
lua5.4 "mini copy.lua"       > /tmp/lua_out.txt   # from the repo root
diff /tmp/lua_out.txt /tmp/cpp_out.txt             # -> no differences
```

The `diff` reports **no differences** — the C++ output is identical to the Lua
interpreter's, including the quoted `'100'` strings and the integer-style
numbers:

```text
'100'
11
11
'100'
13
13
1
6
111
222
333
333
```

Number formatting deserves one note: Lua's `tonumber("5")` yields the integer
`5` and prints as `"5"`. The C++ uses `double`, so `tostringa` special-cases
whole `double`s (via `std::fixed << std::setprecision(0)`) to print `11`, `13`,
`1`, `6`, `111`, `222`, `333` without a trailing `.0` — matching Lua exactly.

---

## 9. Result / files produced

- **`cpp/mini_copy.cpp`** — the single self-contained C++17 port (293 lines,
  with header and inline comments mapping each piece back to the Lua).
- **`cpp/mini_copy`** — the compiled binary (a build artefact).
- **`cpp/porting.md`** — this document.

The port is a faithful, 1:1 translation: the Italian identifiers are preserved,
the STL replaces Lua's dynamic constructs, the 1-based → 0-based shift is
confined to exactly two places, and the output is proven identical to the
original interpreter.




