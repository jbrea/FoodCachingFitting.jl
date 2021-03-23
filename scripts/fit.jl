using Distributed, Pkg, Unitful, FoodCachingModels
Pkg.activate(joinpath(@__DIR__, ".."))
if haskey(ENV, "FOOD_CACHING_PARALLEL")
    nprocs() < Sys.CPU_THREADS && addprocs(Sys.CPU_THREADS - nprocs(),
                                           exeflags = "--project",
                                           dir = joinpath(@__DIR__, ".."))
end
using FoodCachingModels
import FoodCachingFitting: fit, parse_args

fit(; parse_args()...)
