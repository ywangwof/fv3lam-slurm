#!/bin/bash

cdatehh=${1}    # date string
what=${2}       # wflow, ics, lbcs, fcst, post, plot
mem=${3-1}      # ensemble starting member id
nens=${4-40}    # ensemble ending member id

runcase="SP"

host_name=$(hostname)
if [[ $host_name =~ "stampede2" ]]; then
  machine="stampede"
elif [[ $host_name =~ "odin" ]]; then
  machine="odin"
  homefv3=/scratch/ywang/EPIC2/ufs-srweather-app/regional_workflow/ush
  homerunscript=/scratch/ywang/EPIC2/expt_dirs/fv3lam-slurm
  hometemplates=/scratch/ywang/EPIC2/templates
  homeconfig=/scratch/ywang/EPIC2/config
  homerun=/scratch/ywang/EPIC2/expt_dirs
  homeshape=/scratch/ywang/fix/NaturalEarth
elif [[ $host_name =~ fe* ]]; then
  machine="jet"
  homefv3=/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/ufs-srweather-app/regional_workflow/ush
  homerunscript=/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/fv3lam-slurm
  hometemplates=/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/templates
  homeconfig=/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/config
  homerun=/lfs4/NAGAPE/hpc-wof1/ywang/EPIC2/expt_dirs
  homeshape=/lfs4/BMC/wrfruc/FV3-LAM/NaturalEarth
elif [[ $host_name =~ "4373-Wang-mbp" ]]; then
  machine="macos"
else
  machine="UNKOWN"
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
        if [[ $what =~ "plot" ]]; then
            read -r -d '' pythonstring <<- EOM
module use -a /contrib/miniconda3/modulefiles
module load miniconda3
conda activate pygraf
EOM
        else
            read -r -d '' pythonstring <<- EOM
module use -a /contrib/miniconda3/modulefiles
module load miniconda3
conda activate regional_workflow
EOM
        fi
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

#
# Source python string for this script
#
IFS=$'\n' pyenv=($pythonstring)
for pye in ${pyenv[@]}; do
    IFS=$' ' pys=(${pye})
    ${pys[*]}
done

#
# Run ensemble task, mainly prepare ensemble workflow one by one
#
for ((m=$mem;m<=$nens;m++)); do

      mid=$(printf "%03d" $m)
      rundir=${homerun}/${runcase}_${cdatehh}_${mid}

      if [[ $what =~ "wflow" ]]; then
        #
        # Prepare workflow
        #
        cd ${hometemplates}
        sed "/EXPT_SUBDIR/s/GRID_${cdatehh}/${runcase}_${cdatehh}_${mid}/;s/mem000/mem${mid}/g" ${hometemplates}/configGrid_${cdatehh}.sh > ${homeconfig}/config${runcase}_${cdatehh}_${mid}.sh
        cat << EOF >> ${homeconfig}/config${runcase}_${cdatehh}_${mid}.sh

RUN_TASK_MAKE_GRID="FALSE"
GRID_DIR="${homerun}/GRID_${cdatehh}/grid"

RUN_TASK_MAKE_OROG="FALSE"
OROG_DIR="${homerun}/GRID_${cdatehh}/orog"

RUN_TASK_MAKE_SFC_CLIMO="FALSE"
SFC_CLIMO_DIR="${homerun}/GRID_${cdatehh}/sfc_climo"
EOF


        #
        # Generate workflow
        #
        cd ${homefv3}
        rm -f config.sh

        ln -s ${homeconfig}/config${runcase}_${cdatehh}_${mid}.sh config.sh
        ./generate_FV3LAM_wflow.sh

        #
        # Stage files
        #
        cd ${homerunscript}
        ./get_files.sh  $rundir/var_defns.sh
      fi

      if [[ $what =~ "plot" ]]; then
        #
        # plot forecast
        #
        cd ${homefv3}/Python
        python plot_allvars.py ${cdatehh} 0 6 1 ${rundir} ${homeshape}
      fi

done

#
# run other tasks in the workflow
#
rundir=${homerun}/${runcase}_${cdatehh}_001

nopt="${mem}-${nens}"

cd ${homerunscript}
[[ $what =~ "ics"  ]] && ./run_fv3lam.sh -a $nopt $rundir/var_defns.sh ics
[[ $what =~ "lbcs" ]] && ./run_fv3lam.sh -a $nopt $rundir/var_defns.sh lbcs
[[ $what =~ "fcst" ]] && ./run_fv3lam.sh -a $nopt $rundir/var_defns.sh fcst
[[ $what =~ "post" ]] && ./run_fv3lam.sh -a $nopt $rundir/var_defns.sh post

exit 0
