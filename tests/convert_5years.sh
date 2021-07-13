#!/bin/bash
# this bash script convert 5 years of medcordex data
module load ncl
ATM=/work/remhi/pm09220/medcordex/from_cmip5_global/CNRM-CM5/rcp85/r1i1p1/result/atm_regional
OCN=/work/remhi/pm09220/medcordex/from_cmip5_global/CNRM-CM5/rcp85/r1i1p1/result/oce_regional
export OUTPATH=../intermediate_out
mkdir -p $OUTPATH

for y in {2008..2013}
do
  export ATMDATA=$ATM/$y
  export OCNDATA=$OCN/$y
  ncl ../src/mcordex2int.ncl
done
