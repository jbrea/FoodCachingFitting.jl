using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FoodCachingExperiments, FoodCachingModels, FoodCachingFitting
using BSON, CodecZstd, DataFrames, Statistics
function loadresult(filename; datapath = joinpath(@__DIR__, "..", "..", "FoodCachingPlotting", "data"))
    open(joinpath(datapath, filename)) do f
        s = ZstdDecompressorStream(f)
        res = BSON.load(s)[:results]
        close(s)
        res
    end
end
REV1 = "be96fd7" # new results
REV2 = "f5ec1d5" # with maxN = 2000
REV3 = "01135d8" # new CacheModulatedCaching2
df1 = loadresult("run_HungermodulatedCaching_$REV1.bson.zstd")
df1.rev = fill(REV1, nrow(df1))
df2 = loadresult("run_HungermodulatedCaching_$REV2.bson.zstd")
df2.rev = fill(REV2, nrow(df2))
res = vcat(df1, df2)
sort!(res, :logp_hat)
best = vcat([g[end:end, :] for g in groupby(res, [:model, :experiment])]...)

function copy_to_cmc2!(cm, hm)
    n = length(hm.m)
    cm.m[1:n] .= hm.m
    cm.m[n+1:n+2] .= hm.m[end-1:end]
    cm.s[1:n] .= hm.s
    cm.s[n+1:n+2] .= hm.s[end-1:end]
    nh = FoodCachingModels.NestedStructInitialiser.free_param_length(Dict(cm.p.free...)[:nutritionvalues])
    idx = 1
    for (k, v) in cm.p.free
        k == :nutritionvalues && break
        idx += FoodCachingModels.NestedStructInitialiser.free_param_length(v)
    end
    nc = FoodCachingModels.NestedStructInitialiser.free_param_length(Dict(cm.p.free...)[:update_value])
    cm.m[end-nc+1:end-nc+nh] .= hm.m[idx:idx+nh-1]
    cm.s[end-nc+1:end-nc+nh] .= hm.s[idx:idx+nh-1]
    cm
end
newres = DataFrame(model = Symbol[], experiment = Symbol[],
                   logp_hat = Float64[],
                   logp_hat_std = Float64[])
for row in eachrow(best[best.experiment .∈ Ref([:Clayton99C_exp1,
                                                :Clayton99C_exp2,
                                                :Clayton99C_exp3,
                                                :Correia07_exp1,
                                                :Cheke11_specsat]), :])
    @show row.model row.experiment
    hm = load(joinpath("data", "$(row.model)_$(row.experiment)_$(row.id)_$(row.rev).bson.zstd"))
    cm = load(joinpath("data", "$(row.model)_$(row.experiment)_CacheModulatedCaching21_$REV3.bson.zstd"))
    copy_to_cmc2!(cm, hm)
    res = [logp_hat(cm, [row.experiment], N = 10^4, k = 5) for _ in 1:10]
    push!(newres, [row.model, row.experiment, mean(res), std(res)])
end
FoodCachingModels.bsave(joinpath(@__DIR__, "..", "..", "FoodCachingPlotting", "data", "run_CacheModulatedCaching2_COPY"),
                        Dict(:results => newres))
