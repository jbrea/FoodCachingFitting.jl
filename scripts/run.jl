using Distributed, Pkg
Pkg.activate(joinpath(@__DIR__, ".."))
using FoodCachingModels, DataFrames, Distances, Statistics
import FoodCachingExperiments: bsave, target
import FoodCachingFitting: run_experiments, ALLEXPERIMENTS, DATADIR, _logp_hat,
                           simname, parse_args, __REV__

args = parse_args()

if haskey(args, :procs)
    nprocs = args[:procs]
    addprocs(nprocs, exeflags = "--project=$(joinpath(@__DIR__, ".."))")
    @everywhere using FoodCachingExperiments, FoodCachingFitting, DataFrames, Distances, Statistics
    pop!(args, :procs)
end

function run(; rev = __REV__, ids = 1:4,
               savename = join(string.(Char.(rand(97:122, 10))), ""),
               models = [Baseline, MotivationalControl, EpisodicLikeMemory,
                         PlasticCaching, ReplayAndPlan],
               N = 10^4, k = 5, rep = 10,
               etest = ALLEXPERIMENTS, etrain = etest,)
    results = DataFrame(model = [], experiment = [], logp_hat = [],
                        logp_hat_std = [], id = [],
                        avg = [], best = [], best_seed = [],
                        N = [], rep = [], k = [])
    for model in models
        for e in etest
            for id in ids
                name = simname(model, etrain == :indi ? [e] : etrain, id, rev)
                isfile(joinpath(DATADIR, "$name.bson.zstd")) || continue
                println("Running $e with $name.")
                tmp = run_experiments(name, [e], rep*N)
                metric = Distances.Euclidean()
                x = target(e)
                d = metric.(Ref(x), tmp.results)
                s = sortperm(d)
                ls = [_logp_hat(sort(d[N*i + 1:N*(i+1)]), x, k, metric)
                      for i in 0:rep-1]
                push!(results, [Symbol(model), e, mean(ls), std(ls), id,
                                mean(tmp.results),
                                tmp.results[s[1]], tmp.seed[s[1]], N, rep, k])
            end
        end
    end
    bsave(joinpath(DATADIR, "run_$savename"), Dict(:results => results))
end

run(; args...)
