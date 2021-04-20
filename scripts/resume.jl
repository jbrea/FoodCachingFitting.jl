using Distributed, Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
if haskey(ENV, "FOOD_CACHING_PARALLEL")
    nprocs() < Sys.CPU_THREADS && addprocs(20,
                                           exeflags = "--project",
                                           dir = joinpath(@__DIR__, ".."))
end
using FoodCachingModels
import FoodCachingFitting: resume_fit

resume_fit(ARGS[1])
