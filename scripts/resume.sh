#!/bin/bash

for f in $@; do
    julia resume.jl $f &
done
