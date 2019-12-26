-- From https://rosettacode.org/wiki/Least_common_multiple
function gcd(m, n)
    while n ~= 0 do
        local q = m
        m = n
        n = q % n
    end
    return m
end

-- From https://rosettacode.org/wiki/Least_common_multiple
function lcm(m, n)
    return (m ~= 0 and n ~= 0) and m * n / gcd(m, n) or 0
end

function log_mod(string)
    log("Barrel-Recipes: " .. string)
end
