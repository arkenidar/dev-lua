local contesto={}
local testo='scrivi_rigo somma 5 prodotto 4 2'
local valori={"scrivi_rigo","somma","5","prodotto","4","2"}
valori={"'100'","somma","5","6"}

local function valuta(indice)
  local valore = valori[indice]
  assert( type(valore) == "string" )
  if contesto[valore] then
    local indici = {indice+1,indice+1+1}
    return contesto[valore]( indici )
  end
  return tonumber(valore) or tostring(valore)
end

function contesto.scrivi ( indici )
  io.write( valuta(indici[1]) )  
end
function contesto.scrivi_rigo ( indici )
  io.write( valuta(indici[1]) .. "\n")  
end
function contesto.somma ( indici )
  return valuta(indici[1]) + valuta(indici[2])
end
function contesto.prodotto ( indici )
  return valuta(indici[1]) * valuta(indici[2])
end

contesto.scrivi_rigo({1})
print( contesto.somma({3,4}) )
print( valuta(2) )
print( valuta(1) )

-- 'scrivi_rigo somma 5 prodotto 4 2'
valori={"scrivi_rigo","somma","5","prodotto","4","2"}
valuta(1)