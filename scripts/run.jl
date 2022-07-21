using Distributed, Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FoodCachingModels, DataFrames, Distances, Statistics
import FoodCachingExperiments: bsave, target
import FoodCachingFitting: run_experiments, ALLEXPERIMENTS, DATADIR, _logp_hat,
                           simname, parse_args

args = parse_args()

if haskey(args, :procs)
    nprocs = args[:procs]
    addprocs(nprocs, exeflags = "--project=$(joinpath(@__DIR__, ".."))")
    @everywhere using FoodCachingExperiments, FoodCachingFitting, DataFrames, Distances, Statistics
end

function bootstrap(f, x; N = 100)
    result = [f(x[rand(1:length(x), length(x))]) for _ in 1:N]
    std(result)
end
results = DataFrame(model = [], experiment = [], logp_hat = [],
                    logp_hat_std = [], id = [],
                    avg = [], best = [], best_seed = [])
rev = args[:rev]
label = haskey(args, :label) ? args[:label] : time_ns()
N = haskey(args, :N) ? args[:N] : 20_000
for model in args[:models]
    for e in args[:experiments]
        for id in args[:ids]
            println("Running $model, $e, $id.")
            tmp = run_experiments(simname(model, [e], id, rev), [e], N)
            metric = Distances.Euclidean()
            x = target(e)
            d = metric.(Ref(x), tmp.results)
            s = sortperm(d)
            d = d[s]
            f = d -> _logp_hat(d, x, 5, metric)
            l = f(d)
            st = bootstrap(f, d)
            push!(results, [Symbol(model), e, l, st, id, mean(tmp.results),
                            tmp.results[s[1]], tmp.seed[s[1]]])
        end
    end
end
bsave(joinpath(DATADIR, "run_$(label)_$rev"), Dict(:results => results))
