using Distributed, Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
if haskey(ENV, "FOOD_CACHING_PARALLEL")
    nprocs() < Sys.CPU_THREADS && addprocs(Sys.CPU_THREADS - nprocs(),
                                           exeflags = "--project",
                                           dir = joinpath(@__DIR__, ".."))
end
using FoodCachingModels, DataFrames, Distances, Statistics
import FoodCachingExperiments: bsave, target
import FoodCachingFitting: run_experiments, ALLEXPERIMENTS, DATADIR, _logp_hat, simname

function bootstrap(f, x; N = 100)
    result = [f(x[rand(1:length(x), length(x))]) for _ in 1:N]
    std(result)
end
results = DataFrame(model = [], experiment = [], logp_hat = [],
                    logp_hat_std = [], id = [],
                    avg = [], best = [], best_seed = [])
rev = "b15ffc2"
for model in [Baseline, MotivationalControl, EpisodicLikeMemory,
              PlasticCaching, ReplayAndPlan]
    for e in ALLEXPERIMENTS
        for id in 1:4
            println("Running $model, $e, $id.")
            tmp = run_experiments(simname(model, [e], id, rev), [e], 20000)
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
bsave(joinpath(DATADIR, "run_indi_$rev"), Dict(:results => results))
