module FoodCachingFitting

using Distributed, CMAEvolutionStrategy, SpecialFunctions, Serialization, LibGit2, Unitful
@everywhere using FoodCachingExperiments, FoodCachingModels, Distances,
                  Random, DataFrames
import FoodCachingModels: Population, setparameters!
import FoodCachingExperiments: EXPERIMENTS, CLAYTON0103_EXPERIMENTS
import CMAEvolutionStrategy: NoiseHandling, population_mean, Optimizer

export simulate, logp_hat, fit, run_experiments, resume_fit

function simulate(population, experiments; N = 500, rng = Random.GLOBAL_RNG)
    seeds = rand(rng, 0:typemax(UInt), N)
    setup = shuffle!(rng, collect(Iterators.product(seeds, experiments)))
    @distributed (vcat) for (seed, e) in setup
        Random.seed!(seed)
        ms = rand(population, nbirds(e))
        data = run!(e, ms)
        res = results(e, data)
        DataFrame(seed = [seed], experiment = [e], results = [res])
    end
end

function logp_hat(population, experiments;
                  N = 500, k = 5, metric = Distances.Euclidean(),
                  rng = Random.GLOBAL_RNG)
    samples = simulate(population, experiments; N, rng)
    sum(combine(groupby(samples, :experiment),
                df -> DataFrame(ll = _logp_hat(target(df.experiment[1]),
                                               df.results, k; metric))).ll)
end
logvol(::Distances.Euclidean, n, ::Any) = log(π)*(n/2) - lgamma(n/2 + 1)
function logvol(m::Distances.WeightedEuclidean, n, x)
    logvol(Distances.Euclidean(), n, x) - sum(log.(sqrt.(m.weights)))
end
function _logp_hat(x, samples, k; metric = Distances.Euclidean())
    n = length(x)
    M = length(samples)
    d = metric.(Ref(x), samples)
    sort!(d)
    log(k/M) - logvol(metric, n, x) - log(d[k]) * n
end

init(p::Population{<:AbstractVector}) = [fill(0., length(p.m));
                                         fill(-4., p.s === nothing ? 0 : length(p.s))]

function noisehandler(n, N; minN = 20, maxN = 500, alphaN = 1.05)
    cb = minN == maxN ?
         s -> s > 0 :
         s -> begin
            if s > 0
                if N[] < maxN
                    N[] = min(maxN, round(Int, N[] * alphaN))
                    @show N[]
                end
                return true
            else
                if N[] > minN
                    N[] = max(minN, round(Int, N[] / alphaN^.25))
                    @show N[]
                end
                return false
            end
        end
    NoiseHandling(n, callback = cb)
end

function checkpoint_saver(population, simname, f, flog;
                          saveevery = 3600,
                          data_dir = DATADIR, t = time())
    (o, _...) -> begin
        if time() - t > saveevery
            setparameters!(population, population_mean(o))
            dict = Dict{Symbol, Any}(:rev => __REV__)
            save(joinpath(DATADIR, simname), population, dict)
            serialize(joinpath(DATADIR, "o_$simname.dat"),
                      Dict(:optimizer => o, :func => f, :rev => __REV__))
            flush(flog[])
            t = time()
        end
    end
end

function simname(model, experiments, id)
    e = experiments == ALLEXPERIMENTS ? "all" : join(string.(experiments), "_")
    "$(model)_$(e)_$(id)_$__REV__"
end

function optimizer(; model,
                   N0 = 20,
                   id = "0",
                   experiments = ALLEXPERIMENTS,
                   saveevery = 3600,
                   sigma0 = .1,
                   x0 = nothing,
                   seed = time_ns(),
                   kwargs...)
    name = simname(model, experiments, id)
    population = model(; experiments, kwargs...)
    x0 = x0 === nothing ? init(population) : x0
    flog = open(joinpath(DATADIR, "log", "$name.log"), "a+")
    redirect_stdout(flog)
    println(join(ARGS, " "))
    flush(flog)
    N = Ref(N0)
    rng = MersenneTwister(seed)
    f = x -> -logp_hat(setparameters!(population, x), experiments;
                       N = N[], rng = rng)
    callback = checkpoint_saver(population, name, f, Ref(flog); saveevery)
    noise_handling = noisehandler(length(x0), N)
    (o = Optimizer(x0, sigma0; noise_handling, callback, seed), f = f)
end

function fit(; kwargs...)
    o, f = optimizer(; kwargs...)
    CMAEvolutionStrategy.run!(o, f)
end

function resume_fit(simname)
    flog = open(joinpath(DATADIR, "log", "$simname.log"), "a+")
    redirect_stdout(flog)
    sim = deserialize(joinpath(DATADIR, "o_$simname.dat"))
    o = sim[:optimizer]
    f = sim[:func]
    f.population.constructor = FoodCachingModels.init(f.population.p)
    o.logger.callback.flog[] = flog
    CMAEvolutionStrategy.run!(o, f)
end

function run_experiments(simname, experiments, N; seed = time_ns())
    population = load(joinpath(DATADIR, simname))
    simulate(population, experiments, N = N, rng = MersenneTwister(seed))
end
function run_experiments(; models, experiments, id, N, seed = time_ns())
    vcat([begin
              res = run_experiments(simname(model, exs, id), exs, N; seed)
              res.model = fill(Symbol(model), length(res.results))
              res
          end
          for (model, exs) in Iterators.product(models, experiments)]...)
end

function parse_args()
    kwargs = Dict{Symbol, Any}()
    for arg in ARGS
        eq = findfirst(isequal('='), arg)
        kwargs[Symbol(arg[1:eq-1])] = eval(Meta.parse(arg[eq+1:end]))
    end
    kwargs
end

__REV__ = ""
const DATADIR = joinpath(@__DIR__, "..", "data")
const ALLEXPERIMENTS = setdiff(keys(EXPERIMENTS), CLAYTON0103_EXPERIMENTS)

function __init__()
    dir = joinpath(@__DIR__, "..")
    LibGit2.isdirty(GitRepo(dir)) && @warn "git repo is dirty."
    global __REV__ = LibGit2.head(dir)[1:7]
end
end
