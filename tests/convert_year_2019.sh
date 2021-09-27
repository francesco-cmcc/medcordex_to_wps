#!/bin/bash
# this bash script convert 1 year of medcordex data
export ATMDATA=/data/inputs/metocean/historical/model/atmos/IPSL/MedCordex/projections/atm_regional/2019
export OCNDATA=/work/remhi/pm09220/medcordex/29_07_21
export OUTPATH=/work/remhi/pm09220/medcordex/24_09_21/intermediate_out
export LANDSEA_MASK_PATH=/work/remhi/pm09220/medcordex/24_09_21/medcordex_to_wps/data/phis_box.nc
mkdir -p $OUTPATH
module load ncl
ncl ../src/mcordex2int.ncl
