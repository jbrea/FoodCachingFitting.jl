# FoodCachingFitting

The code in this repository defines some methods to fit models of food caching behaviour (like the ones in [FoodCachingModels](https://github.com/jbrea/FoodCachingModels.jl) ) to experimental data (like the one in [FoodCachingExperiments](https://github.com/jbrea/FoodCachingExperiments.jl) ). This repository is a submodule of [FoodCaching](https://github.com/jbrea/FoodCaching).

See [scripts](scripts) for examples.

To run the code in this repository, download [julia 1.6](https://julialang.org/downloads/)
and activate and instantiate this project. This can be done in a julia REPL with the
following lines of code:
```julia
using Pkg
# download code
Pkg.develop(url = "https://github.com/jbrea/FoodCachingFitting.jl")
# activate project
cd(joinpath(Pkg.devdir(), "FoodCachingFitting"))
Pkg.activate(".")
# install dependencies
Pkg.instantiate()
```

