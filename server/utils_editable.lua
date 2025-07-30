function Shuffle(str)
    local tbl = {}
    for i = 1, #str do
        table.insert(tbl, str:sub(i, i))
    end
    for i = #tbl, 2, -1 do
        local j = math.random(1, i)
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return table.concat(tbl)
end

function GenerateRandomPlate()
    local plate = ''
    for i = 1, 4 do plate = plate .. string.char(math.random(65, 90)) end
    for i = 1, 4 do plate = plate .. tostring(math.random(0, 9)) end
    return Shuffle(plate)
end

function GenerateShortId()
    local plate = ''
    for i = 1, 3 do plate = plate .. string.char(math.random(65, 90)) end
    for i = 1, 4 do plate = plate .. tostring(math.random(0, 9)) end
    return plate
end

function Distance2D(v1, v2)
    local dx = v1.x - v2.x
    local dy = v1.y - v2.y
    return math.sqrt(dx * dx + dy * dy)
end

function FindRandomVec4ByDistance(vecArray, referencePoint, minDistance)
    local filteredVecs = {}
    for i, vec in ipairs(vecArray) do
        local dist = Distance2D(vec, referencePoint)
        if dist >= minDistance then
            table.insert(filteredVecs, vec)
        end
    end
    if #filteredVecs == 0 then return nil end
    local randomIndex = math.random(1, #filteredVecs)
    return filteredVecs[randomIndex]
end

