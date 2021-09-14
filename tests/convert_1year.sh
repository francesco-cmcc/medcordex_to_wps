#!/bin/bash
# this bash script convert 1 year of medcordex data
export ATMDATA=/work/remhi/pm09220/medcordex/from_cmip5_global/CNRM-CM5/historical/r1i1p1/result/atm_regional/2000
export OCNDATA=/work/remhi/pm09220/medcordex/from_cmip5_global/CNRM-CM5/historical/r1i1p1/result/oce_regional/2000
export OUTPATH=../intermediate_out
export LANDSEA_MASK_PATH=/work/remhi/pm09220/medcordex/mask_laurent/phis_box.nc
mkdir -p $OUTPATH
module load ncl
ncl ../src/mcordex2int.ncl

