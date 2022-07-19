#!/bin/bash
function log {
    echo "$1"
}

# Take a list of commands to run, runs them sequentially with numberOfProcesses commands simultaneously runs
# Returns the number of non zero exit codes from commands
function ParallelExec {
    local numberOfProcesses="${1}" # Number of simultaneous commands to run
    local commandsArg="${2}" # Semi-colon separated list of commands

    local pid
    local runningPids=0
    local counter=0
    local commandsArray
    local pidsArray
    local newPidsArray
    local retval
    local retvalAll=0
    local pidState
    local commandsArrayPid

    IFS=';' read -ra commandsArray <<< "$commandsArg"
    echo $commandsArray

    log "Running ${#commandsArray[@]} commands in $numberOfProcesses simultaneous processes."

    while [ $counter -lt "${#commandsArray[@]}" ] || [ ${#pidsArray[@]} -gt 0 ]; do

        while [ $counter -lt "${#commandsArray[@]}" ] && [ ${#pidsArray[@]} -lt $numberOfProcesses ]; do
            log "Running command [${commandsArray[$counter]}]."
            eval "${commandsArray[$counter]}" &
            pid=$!
            pidsArray+=($pid)
            commandsArrayPid[$pid]="${commandsArray[$counter]}"
            counter=$((counter+1))
        done


        newPidsArray=()
        for pid in "${pidsArray[@]}"; do
            # Handle uninterruptible sleep state or zombies by ommiting them from running process array (How to kill that is already dead ? :)
            if kill -0 $pid > /dev/null 2>&1; then
                pidState=$(cat /proc/$pid/status | grep State | cut -c8 > /dev/null)
                if [ "$pidState" != "D" ] && [ "$pidState" != "Z" ]; then
                    newPidsArray+=($pid)
                fi
            else
                # pid is dead, get it's exit code from wait command
                wait $pid
                retval=$?
                if [ $retval -ne 0 ]; then
                    log "Command [${commandsArrayPid[$pid]}] failed with exit code [$retval]."
                    retvalAll=$((retvalAll+1))
                fi
            fi
        done
        pidsArray=("${newPidsArray[@]}")

        # Add a trivial sleep time so bash won't eat all CPU
        sleep 1
    done

    return $retvalAll
}

CMDS=""
for exp in {deKort07_exp3,Cheke11_specsat,deKort05,Clayton99B_exp2,Clayton05_exp3,Clayton99C_exp1,Clayton99B_exp1,Raby07_planningforbreakfast,Correia07_exp1,Clayton05_exp4,Clayton99A_exp2,deKort07_exp2,Clayton05_exp1,Clayton99C_exp3,Raby07_breakfastchoice,Cheke11_planning,deKort07_exp1,Clayton05_exp2,Clayton99C_exp2,Correia07_exp2,Clayton99A_exp1,Clayton0103,deKort07_exp4};
do
    CMDS+="julia fit.jl experiments=\"[:$exp]\" ${@:1};"
done

ParallelExec 46 "$CMDS"

