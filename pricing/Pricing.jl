module Pricing

export call_price_gen,
       put_price_gen,
       calls_otm,
       contracts_per_dte,
       plot_call_prediction,
       plot_put_prediction,
       plot_call_predictions,
       plot_put_predictions,
       puts_otm

using DataFrames, Dates, Plots, VegaLite

function call_price_gen(C_1::Float64, K_1::Float64, S_0::Float64, α::Float64)
    return K_2::Float64 -> ((K_2 - S_0) / (K_1 - S_0))^(1 - α) * C_1
end

function put_price_gen(P_1::Float64, K_1::Float64, S_0::Float64, α::Float64)
    return K_2::Float64 -> (((-1 + 0im)^(1 - α) * S_0^(-α) * ((α - 1) * K_2 + S_0) -
                             (K_2 - S_0 + 0im)^(1 - α)) /
                            ((-1 + 0im)^(1 - α) * S_0^(-α) * ((α - 1) * K_1 + S_0) -
                             (K_1 - S_0 + 0im)^(1 - α)) * P_1).re
end

function calls_otm(df::DataFrame, otm_pct::Int64, day::Date)
    calls = filter(
        x -> (x.underlying == "SPX") & (x.type == "call") &
             ((1 + otm_pct / 100) * x.underlying_last < x.strike) & (x.quotedate == day),
        df,
    )
    calls[!, :K] = calls.strike ./ calls.underlying_last * 100
    return calls
end

function puts_otm(df::DataFrame, otm_pct::Int64, day::Date)
    puts = filter(
        x -> (x.underlying == "SPX") & (x.type == "put") &
             ((1 - otm_pct / 100) * x.underlying_last > x.strike) & (x.quotedate == day),
        df,
    )
    puts[!, :K] = puts.strike ./ puts.underlying_last * 100
    return puts
end

function contracts_per_dte(df::DataFrame)
    by(df, :dte, N = :dte => length) |> d -> sort(d, :N, rev = true)
end

function plot_call_prediction(df::DataFrame, anchor::DataFrameRow, α::Float64)
    plot_prediction(df, anchor, α, call_price_gen)
end

function plot_put_prediction(df::DataFrame, anchor::DataFrameRow, α::Float64)
    plot_prediction(df, anchor, α, put_price_gen)
end

function plot_call_predictions(
    df::DataFrame,
    dtes::Array{Day,1},
    α_range,
    anchor_pick::Function,
)
    plot_predictions(df, dtes, α_range, anchor_pick, call_price_gen)
end

function plot_put_predictions(
    df::DataFrame,
    dtes::Array{Day,1},
    α_range,
    anchor_pick::Function,
)
    plot_predictions(df, dtes, α_range, anchor_pick, put_price_gen)
end

function plot_prediction(
    df::DataFrame,
    anchor::DataFrameRow,
    α::Float64,
    gen_function::Function,
)
    subset = filter(x -> x.dte == anchor.dte, df)
    dte = anchor.dte
    S_0 = 100.0
    K_1 = anchor.K
    C_1 = anchor.ask
    price_call = gen_function(C_1, K_1, S_0, α)
    market_prices = subset[!, :ask]
    market_strikes = subset[!, :K]
    model_strikes = range(
        minimum(market_strikes),
        stop = maximum(market_strikes),
        length = 150,
    )
    model_prices = price_call.(model_strikes)
    plot(
        [model_strikes, market_strikes],
        [model_prices, market_prices],
        lab = ["Model" "Market"],
        title = "fix K = $(round(K_1)), alpha = $α, dte = $dte",
        titlefontsize = 10,
    )
end

function plot_predictions(
    df::DataFrame,
    dtes::Array{Day,1},
    α_range,
    anchor_pick::Function,
    gen_function::Function,
)
    options_df = DataFrame()
    for dte in dtes
        for a in α_range
            α = round(a, digits = 2)
            subset = filter(x -> x.dte == dte, df)
            anchor = anchor_pick(subset)
            C_1 = anchor.ask
            K_1 = anchor.K
            S_0 = 100.0
            price = gen_function(C_1, K_1, S_0, α)
            subset[!, :alpha] .= α
            subset[!, :model_price] = price.(subset.K)
            options_df = vcat(options_df, subset)
        end
    end

    rename!(options_df, :ask => :market_price)
    options_df.dte = map(d -> d.value, options_df.dte) # Needed for VegaLite
    options_df |> @vlplot(
        :line,
        x = :K,
        y = {"value:Q", title = "price"},
        transform = [{fold = [:market_price, :model_price]}],
        color = {"key:O", title = "", scale = {scheme = "category10"}},
        row = {"alpha:O"},
        column = "dte:O",
        resolve = {scale = {y = "independent"}, axis = {x = "independent"}},
        width = 300,
        height = 300,
    )
end

end
