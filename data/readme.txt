phis.nc     -> It's the original file given by Laurent Li
phis_box.nc -> It contains the same fields of the previuos file, the domain of interest is cropped using a lat-lon box, 
               by "ncks -d lat,24.12869,55.81967 -d lon,-12.88637,42.52213 phis.nc phis_box.nc"
