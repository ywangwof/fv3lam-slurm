#!/usr/bin/env bash

function usage {
    echo " "
    echo "    USAGE: $0 [options] [VARDEFNS] task"
    echo " "
    echo "    PURPOSE: Run UFS SRWeather jobs based on ROCOTO workflow file: FV3LAM_wflow.xml "
    echo " "
    echo "    VARDEFNS - var_defns.sh file generated by FV3LAM regional workflow"
    echo "               default: \"../var_defns.sh\""
    echo "    task     - a task to run, one from (grid, orog, sfc, ics, lbcs, fcst, post)"
    echo " "
    echo "    OPTIONS:"
    echo "              -h              Display this message"
    echo "              -n              Show command to be run only"
    echo "              -v              Verbose mode"
    echo "              -m   odin       Machine (odin, stampede, jet or macos)"
    echo "                              default, determine automatically based on hostname."
    echo "              -a   0          Job arrays (same rule as SLURM job array option \"-a\")"
    echo "                              The last 3 digits of the EXPTDIR will the ensemble member and the array task id."
    echo " "
    echo "                                     -- By Y. Wang (2020.10.21)"
    echo " "
    exit $1
}

#-----------------------------------------------------------------------
#
# Default values
#
#-----------------------------------------------------------------------

show=0
verb=0
task=" "
VARDEFNS="../var_defns.sh"
host_name=$(hostname)
if [[ $host_name =~ "stampede2" ]]; then
  machine="stampede"
elif [[ $host_name =~ "odin" ]]; then
  machine="odin"
elif [[ $host_name =~ fe* ]]; then
  machine="jet"
elif [[ $host_name =~ "4373-Wang-mbp" ]]; then
  machine="macos"
else
  machine="UNKOWN"
fi

nens="0"

#xmlparser="python $(dirname $0)/read_xml.py"
#-----------------------------------------------------------------------
#
# Handle command line arguments
#
#-----------------------------------------------------------------------

while [[ $# > 0 ]]
    do
    key="$1"

    case $key in
        -h)
            usage 0
            ;;
        -n)
            show=1
            ;;
        -v)
            verb=1
            ;;
        -m)
            machine=$2
            shift
            ;;
        -a)
            if [[ $2 =~ ^[0-9,-]+$ ]]; then
              nens="$2"
              shift
            else
                echo ""
                echo "ERROR: ensemble job array not recognized, get [$2]."
                usage -2
            fi
            ;;
        -*)
            echo "Unknown option: $key"
            exit
            ;;
        *)
            if [[ -f $key ]]; then
                VARDEFNS=$key
            elif [[ $key =~ (grid|orog|sfc|ics|lbcs|fcst|post) ]]; then
                task=$key
            else
                echo ""
                echo "ERROR: unknown option, get [$key]."
                usage -2
            fi
            ;;
    esac
    shift # past argument or value
done

if [[ ! $task =~ (grid|orog|sfc|ics|lbcs|fcst|post) ]]; then
    echo "ERROR: unsupport task - <$task>. Must be one from [grid|orog|sfc|ics|lbcs|fcst|post]."
    usage -1
fi

if [[ -f $VARDEFNS ]]; then
    echo "VARDEFNS = $VARDEFNS"
else
    echo ""
    echo "ERROR: cannot find var_defns.sh - <$VARDEFNS>."
    usage -2
fi

##---------------- Prepare Python environment --------------------------

case $machine in
    odin)
        read -r -d '' pythonstring <<- EOM
		source /scratch/software/Odin/python/anaconda2/etc/profile.d/conda.sh
		conda activate regional_workflow
EOM
        ;;
    stampede)
		pythonstring="module load python3/3.7.0"
        ;;
    jet)
        read -r -d '' pythonstring <<- EOM
module use -a /contrib/miniconda3/modulefiles
module load miniconda3
conda activate regional_workflow
EOM
        ;;
    macos)
        read -r -d '' pythonstring <<- EOM
		source /Users/yunheng.wang/.python
		conda activate regional_workflow
EOM
        ;;
    *)
        echo "ERROR: unsupported machine - $machine"
        usage 0
        ;;
esac

if [[ $verb -eq 1 ]]; then
    echo "machine  = \"${machine}\""
fi

##
## Source python string for this script
##
#IFS=$'\n' pyenv=($pythonstring)
#for pye in ${pyenv[@]}; do
#    IFS=$' ' pys=(${pye})
#    ${pys[*]}
#done

#-----------------------------------------------------------------------
#
# Definitions
#
#-----------------------------------------------------------------------

VARDEFNS="$(realpath ${VARDEFNS})"
source ${VARDEFNS}

declare -A tasknames  queues wrappers
tasknames=(["grid"]="make_grid"     ["orog"]="make_orog"  \
           ["sfc"]="make_sfc_climo" ["ics"]="make_ics"    \
           ["lbcs"]="make_lbcs"     ["fcst"]="run_fcst"   \
           ["post"]="run_post" )

if [[ $machine =~ "jet" ]]; then
    partitions=(["grid"]="${PARTITION_DEFAULT}" ["orog"]="${PARTITION_DEFAULT}" \
                ["sfc"]="${PARTITION_DEFAULT}"  ["ics"]="${PARTITION_DEFAULT}"  \
                ["lbcs"]="${PARTITION_DEFAULT}" ["fcst"]="${PARTITION_FCST}"    \
                ["post"]="${PARTITION_DEFAULT}")

fi
queues=(["grid"]="${QUEUE_DEFAULT}" ["orog"]="${QUEUE_DEFAULT}" \
        ["sfc"]="${QUEUE_DEFAULT}"  ["ics"]="${QUEUE_DEFAULT}"  \
        ["lbcs"]="${QUEUE_DEFAULT}" ["fcst"]="${QUEUE_FCST}"    \
        ["post"]="${QUEUE_DEFAULT}")

wrappers=(["grid"]="run_make_grid.sh"     ["orog"]="run_make_orog.sh" \
          ["sfc"]="run_make_sfc_climo.sh" ["ics"]="run_make_ics.sh"   \
          ["lbcs"]="run_make_lbcs.sh"     ["fcst"]="run_fcst.sh"      \
          ["post"]="run_post.sh" )


#---------------- Decode rocoto XML file -------------------------------

wflow=0
if [[ -f $EXPTDIR/FV3LAM_wflow.xml ]]; then
    echo "FV3LAM_wflow = $EXPTDIR/FV3LAM_wflow.xml"
    wflow=1

    #metatask=""
    #if [[ $task =~ "post" ]]; then
    #  metatask="-m"
    #fi
    #
    #resources=$($xmlparser -t ${tasknames[$task]} $metatask -g nodes $EXPTDIR/FV3LAM_wflow.xml)
    ##echo $resources
    #
    #nodes=${resources%%:ppn=*}
    #ppn=${resources##*:ppn=}
    #numprocess=$(( nodes*ppn ))
    #walltime=$($xmlparser -t ${tasknames[$task]} $metatask -g walltime $EXPTDIR/FV3LAM_wflow.xml)

    taskname=${tasknames[$task]^^}
    noderef="NNODES_${taskname}"; ppnref="PPN_${taskname}"; wtimeref="WTIME_${taskname}"

    nodes=${!noderef}
    ppn=${!ppnref}
    walltime=${!wtimeref}

    queue=${queues[$task]}
    [[ $machine =~ "jet" ]] && queue=${partitions[$task]}
else
    nodes=1
    ppn=4
    #numprocess=$(( nodes*ppn ))
    walltime="3:00:00"
    queue="None"
fi

if [[ $verb -eq 1 ]]; then
    echo "task     = \"$task\",   taskname = \"${tasknames[$task]}\""
    echo "nodes    = \"$nodes\",  ppn = \"$ppn\",   walltime = \"$walltime\",   queue = \"$queue\""
fi

##================ Prepare job script ==================================

CODEBASE="${HOMErrfs}"

WRKDIR="${LOGDIR}"
if [[ ! -d $WRKDIR ]]; then
  mkdir $WRKDIR
fi

cd $WRKDIR

#
# ensemble specific
#
if [[ $nens == "0" ]]; then       # One run
    logdir="${LOGDIR}"
    logstr="${tasknames[$task]}_%j"
    memstr=" "
    subopt=""
else                              # ensemble runs
    memstr='mid=$(printf "%03d" ${SLURM_ARRAY_TASK_ID})'
    if [[ $wflow -ne 1 ]]; then
        nmem=(${nens//,/ })
        mems=()
        for m in ${nmem[@]}; do
            if [[ $m =~ ^([0-9]+)-([0-9]+)$ ]]; then
                #echo -$m-, ${BASH_REMATCH[1]}, ${BASH_REMATCH[2]}
                for ((n=${BASH_REMATCH[1]};n<=${BASH_REMATCH[2]};n++)); do
                    mems+=($n)
                done
            else
                mems+=($m)
            fi
        done
        subopt=($(tr ' ' '\n' <<< "${mems[@]}" | sort -u | tr '\n' ' '))
        memstr='mid=$(printf "%03d" $1)'
    else
      subopt="-a $nens"
    fi

    exptdirbase=${EXPTDIR:0:${#EXPTDIR}-4}
    EXPTDIR="${exptdirbase}_\${mid}"
    logdir=${LOGDIR/_[0-9][0-9][0-9]\/log/_%3a\/log}
    logstr="${tasknames[$task]}_%j_%a"
fi

if [[ $wflow -eq 1 ]]; then
    read -r -d '' taskheader <<EOF
#!/bin/sh -l
#SBATCH -A ${ACCOUNT}
#SBATCH -p ${queue}
#SBATCH -J ${tasknames[$task]}
#SBATCH --nodes=${nodes} --ntasks-per-node=${ppn}
#SBATCH --exclusive
#SBATCH -t ${walltime}
#SBATCH -o ${logdir}/out.${logstr}
#SBATCH -e ${logdir}/err.${logstr}

${pythonstring}

$memstr
export EXPTDIR=${EXPTDIR}

EOF
else
    read -r -d '' taskheader <<EOF
#!/bin/bash

${pythonstring}

$memstr
export EXPTDIR=${EXPTDIR}

EOF

fi


##@@@@@@@@@@@@@@@@@@@@@ Submit job script @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

jobscript="${tasknames[$task]}.job"

sed "1d" ${CODEBASE}/ush/wrappers/${wrappers[$task]}  > ${jobscript}

echo "$taskheader" | cat - ${jobscript} > temp && mv temp ${jobscript}

#if [[ $verb -eq 1 ]]; then
    echo "jobscript: $WRKDIR/$jobscript is created."
#fi

if [[ $show -eq 1 ]]; then
    if [[ $wflow -eq 1 ]]; then
        echo "To run <${tasknames[$task]}>, submit the job manually as follow:"
        echo "    \$> sbatch ${subopt} $WRKDIR/$jobscript"
    else
        echo "To run <${tasknames[$task]}>, execute the following command manually:"
        if [[ $nens -ne 0 ]]; then
            for mid in ${subopt[@]}; do
                mem=$(printf "%03d" $mid)
                logdir=${LOGDIR/_[0-9][0-9][0-9]\/log/_${mem}\/log}
                echo "    \$> $WRKDIR/${jobscript} $mid |& tee $logdir/out.${tasknames[$task]}"
            done
        else
            echo "    \$> $WRKDIR/${jobscript} |& tee ${LOGDIR}/out.${tasknames[$task]}"
        fi
    fi
else
    if [[ $wflow -eq 1 ]]; then
        output=$(sbatch ${subopt} ${jobscript})
        if [[ $? -eq 0 ]]; then
            echo "${output}"
            words=(${output})
            jobid=${words[-1]}
            echo " "
            echo "Logfiles for this job (once started) are:"
            echo "    ${LOGDIR}/out.${tasknames[$task]}_${jobid}"
            echo "    ${LOGDIR}/err.${tasknames[$task]}_${jobid}"
            echo " "
            #touch out.${tasknames[$task]}_${jobid}
            #touch err.${tasknames[$task]}_${jobid}
        else
            echo "${output}"
        fi
    else
        chmod +x ${jobscript}
        if [[ $nens -ne 0 ]]; then
            for mid in ${subopt[@]}; do
                mem=$(printf "%03d" $mid)
                logdir=${LOGDIR/_[0-9][0-9][0-9]\/log/_${mem}\/log}
                ${jobscript} $mid |& tee ${logdir}/out.${tasknames[$task]}
            done
        else
            ${jobscript} |& tee ${LOGDIR}/out.${tasknames[$task]}
        fi
    fi
fi

exit 0
