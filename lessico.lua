-- lessico.lua — single source of truth for the bilingual (IT <-> EN) keywords.
-- Italian names are canonical (they match the implementation in mini.lua);
-- English names are aliases derived from this table, so the two can't drift.

local it = {
  scrivi      = "write",
  scrivi_rigo = "writeline",
  somma       = "sum",
  prodotto    = "product",
  somma_tutti = "sumall",
  fine        = "end",
}

-- reverse map EN -> IT (the "vice versa" direction)
local en = {}
for k, v in pairs(it) do en[v] = k end

return { it = it, en = en }
