using Distributed, Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
# Pkg.instantiate()
using FoodCachingModels
import FoodCachingFitting: fit, parse_args, ALLEXPERIMENTS

args = parse_args()
if (!haskey(args, :joint) || args[:joint] == false) && length(args[:experiments]) > 1
    if haskey(args, :procs)
        N = args[:procs] ÷ length(args[:experiments])
    else
        N = 0
    end
    chprocs = []
    for e in args[:experiments]
        cmdargs = [ARGS; "experiments=[:$e]"; "procs=$N"]
        if haskey(args, :population_file)
            population_file = replace(args[:population_file], "EXPERIMENT" => e)
            push!(cmdargs, "population_file=\"$population_file\"")
        end
        chp = run(`$(Base.julia_cmd()) fit.jl $cmdargs`,
                  stdin, stdout, stderr,
                  wait = false)
        push!(chprocs, chp)
    end
    all(success.(chprocs))
else
    if haskey(args, :procs)
        N = args[:procs]
        addprocs(N, exeflags = "--project=$(joinpath(@__DIR__, ".."))")
        @everywhere using FoodCachingModels, FoodCachingFitting
    end
    fit(; args...)
end
