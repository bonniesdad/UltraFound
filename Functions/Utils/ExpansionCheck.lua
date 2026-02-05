function IsTBC()
  if GetExpansionLevel and GetExpansionLevel() > 0 then
    return true
  end
  return false
end

function IsClassic()
  return not IsTBC()
end
