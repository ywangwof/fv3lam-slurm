To run FV3LAM forecast on Odin, Stampede or macOS that has no Rocoto.

Step 0: Edit file `config.sh` following instructions on [SRW Application Getting Started](https://github.com/ufs-community/ufs-srweather-app/wiki/Getting-Started)
 and/or [Getting Started on Stampede](https://github.com/ywangwof/ufs-srweather-app/wiki/Getting-Started-on-Stampede).

Step 1: run `generate_FV3SAR_wflow.sh`, change to `${EXPTDIR}` and clone this repository into `${EXPTDIR}`

Step 2: Stage exernal model files
        ```
        $> cd fv3lam-slurm
        $> get_files.sh
        ```

Step 3: run `run_fv3lam.sh` following the following steps one by one

    3.1: `run_fv3lam.sh grid`
    3.2: `run_fv3lam.sh orog`
    3.3: `run_fv3lam.sh sfc`
    3.4: `run_fv3lam.sh ics`
    3.5: `run_fv3lam.sh lbcs`
    3.6: `run_fv3lam.sh fcst`
    3.7: `run_fv3lam.sh post`

**Note**: 
    - Step 3.1 - 3.7 will generate job script (SLURM) and then submit the job (run the job script directly on macOS).  
    - Step 0, 1 and 2 will run the scripts on the front node.  
    - If file `../var_defns.sh` not exist, both scripts `get_files.sh` and `run_fv3lam.sh` accept an extra option with the absolute path for file `var_defns.sh`. For example,  
```
    run_fv3lam.sh $EXPTDIR/var_defn.sh grid
```
    execute, `run_fv3lam.sh -h` for more options.  
    - Using these scripts on macOS is not recommended to users of the UFS Short Range Weather public release v1.0.0. Instead, follow the instructions in the [user's guide](https://ufs-srweather-app.readthedocs.io/en/latest/ConfigNewPlatform.html)  
