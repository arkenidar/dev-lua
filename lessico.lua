-- EN: lessico.lua — single source of truth for the bilingual (IT <-> EN) keywords.
-- EN: Italian names are canonical (they match the implementation in mini.lua);
-- EN: English names are aliases derived from this table, so the two can't drift.
-- IT: lessico.lua — unica fonte di verità per le parole chiave bilingui (IT <-> EN).
-- IT: i nomi italiani sono canonici (coincidono con l'implementazione in mini.lua);
-- IT: i nomi inglesi sono alias derivati da questa tabella, così i due non possono divergere.

local it = {
  scrivi      = "write",
  scrivi_rigo = "writeline",
  somma       = "sum",
  prodotto    = "product",
  somma_tutti = "sumall",
  modulo      = "modulus",
  uguale      = "equal",
  maggiore    = "greater",
  non         = "not",
  metti       = "set",
  prendi      = "get",
  fai         = "do",
  se          = "if",
  fine        = "end",
}

-- EN: reverse map EN -> IT (the "vice versa" direction)
-- IT: mappa inversa EN -> IT (la direzione "vice versa")
local en = {}
for k, v in pairs(it) do en[v] = k end

return { it = it, en = en }
