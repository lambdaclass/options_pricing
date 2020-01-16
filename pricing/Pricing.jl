module Pricing

export call_price_gen, put_price_gen

function call_price_gen(C_1::Float64, K_1::Float64, S_0::Float64, α::Float64)
    return K_2::Float64->((K_2 - S_0) / (K_1 - S_0))^(1 - α) * C_1
end

function put_price_gen(P_1::Float64, K_1::Float64, S_0::Float64, α::Float64)
    return K_2::Float64->(((-1 + 0im)^(1 - α) * S_0^(-α) * ((α - 1) * K_2 + S_0) -
                            (K_2 - S_0 + 0im)^(1 - α)) /
                           ((-1 + 0im)^(1 - α) * S_0^(-α) * ((α - 1) * K_1 + S_0) -
                            (K_1 - S_0 + 0im)^(1 - α)) * P_1).re
end

end