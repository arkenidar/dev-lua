// mini_copy.cpp — a faithful C++ port of "mini copy.lua"
//
// The original is a minimal prefix (Polish-notation) interpreter whose
// "program" is a flat array of tokens (`valori`) and whose built-ins live in
// a table named `contesto`. `misura` (measure) computes how many tokens an
// expression consumes; `valuta` (evaluate) walks the token stream recursively;
// `fai` (do) evaluates a `do ... end` block; `sequenza` (sequence) evaluates
// every expression in the array.
//
// Indexing: Lua arrays are 1-based, C++ containers are 0-based. Every
// *internal* offset is base-invariant ("next token" is `+1`, token counts are
// differences), so those lines are kept identical to the Lua source. Only the
// *entry points* in the test section are converted to 0-based, and
// `sequenza`'s bound `cursore <= #valori` becomes `cursore < valori.size()`.
//
// Build & run:
//   g++ -std=c++17 -Wall -Wextra -o mini_copy mini_copy.cpp && ./mini_copy

#include <algorithm>
#include <cassert>
#include <cctype>
#include <cmath>
#include <cstddef>
#include <cstdlib>
#include <functional>
#include <iomanip>
#include <iostream>
#include <map>
#include <optional>
#include <sstream>
#include <string>
#include <utility>
#include <variant>
#include <vector>

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

// A list of token indices, passed to the built-ins (Lua: `indici = {...}`).
using Indici = std::vector<std::size_t>;

// A dynamically-typed value: nil / boolean / number / string.
// Lua has a single "nil" so std::nullptr_t is used as its sentinel.
using Valore = std::variant<std::nullptr_t, bool, double, std::string>;

// A built-in function: takes the argument indices, returns a value.
using Funzione = std::function<Valore(const Indici&)>;

// ---------------------------------------------------------------------------
// Global state (mirrors the Lua top-level locals)
// ---------------------------------------------------------------------------

std::vector<std::string> valori;             // Lua: local valori = {}
std::map<std::string, Funzione> contesto;    // Lua: local contesto = {}

// Forward declarations (Lua: `local fai`; mutual recursion).
std::size_t misura(std::size_t indice);
Valore valuta(std::size_t indice);
Valore fai(std::size_t indice);
Valore sequenza(std::size_t indice);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Lua `tostring(v)`: render a value the way io.write/print would.
std::string tostringa(const Valore& v) {
    if (std::holds_alternative<std::nullptr_t>(v)) return "nil";
    if (std::holds_alternative<bool>(v)) return std::get<bool>(v) ? "true" : "false";
    if (std::holds_alternative<double>(v)) {
        double d = std::get<double>(v);
        std::ostringstream oss;
        if (d == std::floor(d) && std::abs(d) < 1e15) {
            // Whole numbers print without a trailing ".0" (11, 13, 1, ...).
            oss << std::fixed << std::setprecision(0) << d;
        } else {
            oss << d;
        }
        return oss.str();
    }
    return std::get<std::string>(v);
}

// Lua truthiness: anything but `nil` and `false` is true.
bool truthy(const Valore& v) {
    if (std::holds_alternative<std::nullptr_t>(v)) return false;
    if (std::holds_alternative<bool>(v)) return std::get<bool>(v);
    return true;
}

// Lua `tonumber(s)`: parse a number, or nil if the whole string isn't one.
std::optional<double> tonumber_lua(const std::string& s) {
    if (s.empty()) return std::nullopt;
    char* fine = nullptr;
    double d = std::strtod(s.c_str(), &fine);
    if (fine == s.c_str() || *fine != '\0') return std::nullopt; // no / partial conversion
    return d;
}

// Lua `split_int(text)`: for a token like "somma#2", return (2, "somma");
// otherwise nil. (Mirrors `local found = text:find("#")`, `%d+` suffix, etc.)
std::optional<std::pair<double, std::string>> split_int(const std::string& text) {
    // assert(type(text) == "string")  -- always true: parameter is std::string.
    std::size_t found = text.find('#');
    if (found == std::string::npos) return std::nullopt;

    std::string suffix = text.substr(found + 1);
    // suffix must match ^%d+$
    bool solo_cifre = !suffix.empty() &&
        std::all_of(suffix.begin(), suffix.end(),
                    [](unsigned char c) { return std::isdigit(c) != 0; });
    if (!solo_cifre) return std::nullopt;

    double uint = std::stod(suffix);
    std::string prefix = text.substr(0, found);
    return std::make_pair(uint, prefix);
}

// Lua `appendice(testo)` just forwards to split_int.
std::optional<std::pair<double, std::string>> appendice(const std::string& testo) {
    return split_int(testo);
}

// ---------------------------------------------------------------------------
// Core walkers
// ---------------------------------------------------------------------------

// Lua `misura(indice)`: number of tokens consumed by the expression at indice.
std::size_t misura(std::size_t indice) {
    const std::string& valore = valori.at(indice); // assert(type(valore) == "string")
    if (valore == "do") {
        std::size_t cursore = indice;
        cursore = cursore + 1;
        while (valori.at(cursore) != "end") {
            cursore = cursore + misura(cursore);
        }
        return cursore - indice + 1;
    }
    auto numero_prefisso = appendice(valore);
    if (numero_prefisso && contesto.count(numero_prefisso->second)) {
        // (Lua also fetches `funzione = contesto[prefisso]` here but never uses it.)
        double numero = numero_prefisso->first;
        Indici indici;
        std::size_t cursore = indice;
        cursore = cursore + 1;
        for (int variabile = 1; variabile <= static_cast<int>(numero); ++variabile) {
            indici.push_back(cursore);
            cursore = cursore + misura(cursore);
        }
        return cursore - indice;
    }
    // if tonumber(valore) or tostring(valore) then return 1  -- always true
    return 1;
}

// Lua `valuta(indice)`: evaluate the expression at indice.
Valore valuta(std::size_t indice) {
    const std::string& valore = valori.at(indice); // assert(type(valore) == "string")
    if (valore == "do") {
        return fai(indice);
    }
    auto numero_prefisso = appendice(valore);
    if (numero_prefisso && contesto.count(numero_prefisso->second)) {
        double numero = numero_prefisso->first;
        Indici indici;
        std::size_t cursore = indice;
        cursore = cursore + 1;
        for (int variabile = 1; variabile <= static_cast<int>(numero); ++variabile) {
            indici.push_back(cursore);
            cursore = cursore + misura(cursore);
        }
        return contesto.at(numero_prefisso->second)(indici);
    }
    // return tonumber(valore) or tostring(valore)
    auto numero = tonumber_lua(valore);
    if (numero) return *numero;
    return valore; // tostring(valore) == valore
}

// Lua `fai(indice)`: evaluate a `do ... end` block, return the last value.
Valore fai(std::size_t indice) {
    assert(valori.at(indice) == "do"); // assert(valore == "do")
    Valore restituito = nullptr;       // local restituito = nil
    std::size_t cursore = indice;
    cursore = cursore + 1;
    while (valori.at(cursore) != "end") {
        restituito = valuta(cursore);
        cursore = cursore + misura(cursore);
    }
    return restituito;
}

// Lua `sequenza(indice)`: evaluate every expression to the end of the array.
Valore sequenza(std::size_t indice) {
    (void)valori.at(indice); // assert(type(valore) == "string") -- bounds check
    Valore restituito = nullptr;
    std::size_t cursore = indice;
    // Lua: while cursore <= #valori  ->  0-based: cursore < valori.size()
    while (cursore < valori.size()) {
        restituito = valuta(cursore);
        cursore = cursore + misura(cursore);
    }
    return restituito;
}

// ---------------------------------------------------------------------------
// Built-ins (Lua: `function contesto.scrivi(indici) ... end`, etc.)
// ---------------------------------------------------------------------------

// contesto.scrivi: io.write(valuta(indici[1]))
Valore scrivi(const Indici& indici) {
    std::cout << tostringa(valuta(indici[0]));
    return nullptr;
}

// contesto.scrivi_rigo: io.write(valuta(indici[1]) .. "\n")
Valore scrivi_rigo(const Indici& indici) {
    std::cout << tostringa(valuta(indici[0])) << "\n";
    return nullptr;
}

// contesto.somma: valuta(indici[1]) + valuta(indici[2])
Valore somma(const Indici& indici) {
    return std::get<double>(valuta(indici[0])) + std::get<double>(valuta(indici[1]));
}

// contesto.prodotto: valuta(indici[1]) * valuta(indici[2])
Valore prodotto(const Indici& indici) {
    return std::get<double>(valuta(indici[0])) * std::get<double>(valuta(indici[1]));
}

// contesto.se: if valuta(indici[1]) then valuta(indici[2]) else valuta(indici[3])
Valore se(const Indici& indici) {
    if (truthy(valuta(indici[0])))
        return valuta(indici[1]);
    else
        return valuta(indici[2]);
}

// contesto.vero / contesto.falso
Valore vero(const Indici&) { return true; }
Valore falso(const Indici&) { return false; }

// Lua `print(...)`: value + newline.
void stampa(const Valore& v) {
    std::cout << tostringa(v) << "\n";
}
// print(...) of a number (e.g. print(misura(1))).
void stampa(double v) {
    stampa(Valore{v});
}

// ---------------------------------------------------------------------------
// Test section (translated from the bottom of "mini copy.lua", 0-based)
// ---------------------------------------------------------------------------

int main() {
    // contesto (setup) — mirrors the top-level `function contesto.x(indici)` defs.
    contesto["scrivi"]      = scrivi;
    contesto["scrivi_rigo"] = scrivi_rigo;
    contesto["somma"]       = somma;
    contesto["prodotto"]    = prodotto;
    contesto["se"]          = se;
    contesto["vero"]        = vero;
    contesto["falso"]       = falso;

    valori = {"'100'", "somma#2", "5", "6"};
    contesto.at("scrivi_rigo")({0});        // => '100'
    stampa(contesto.at("somma")({2, 3}));   // => 11
    stampa(valuta(1));                      // => 11
    stampa(valuta(0));                      // => '100'

    // 'scrivi_rigo#1 somma#2 5 prodotto#2 4 2'
    valori = {"scrivi_rigo#1", "somma#2", "5", "prodotto#2", "4", "2"}; // => 13
    valuta(0);

    valori = {"scrivi_rigo#1", "somma#2", "prodotto#2", "4", "2", "5"}; // => 13
    valuta(0);

    valori = {"scrivi_rigo#1", "se#3", "vero#0", "1", "2"}; // => 1
    valuta(0);

    valori = {"do", "scrivi_rigo#1", "111", "scrivi_rigo#1", "222", "end", "scrivi_rigo#1", "333"};
    stampa(misura(0)); // => 6
    sequenza(0);       // => 111 222 333

    valori = {"se#3", "falso#0", "do", "scrivi_rigo#1", "111", "scrivi_rigo#1", "222", "end", "scrivi_rigo#1", "333"};
    sequenza(0);       // => 111 and 222 (if true), or just 333 (if false)

    return 0;
}


