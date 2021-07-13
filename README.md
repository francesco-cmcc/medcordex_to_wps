# Medcordex to WRF intermediate file

This tool is designed to convert Medcordex data stored in netcdf format to  WPS intermediate file format. In the repository are included examples of usage. Look at `tests/`

## Input variables

The input variables taken into account to generate wrf intermediate files are listed in the following table:

| input variable      | original timestep | input filename       | source grid       | interpolated to   | out. file    |
| ------------------- | ----------------- | -------------------- | ----------------- | ----------------- | ------------ |
| T2M                 | day               | `LMDZ_day_t2m.nc`    | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| SPECHUMD            | 3hr               | `LMDZ_3hr_q2m.nc`    | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| PMSL                | 3hr               | `LMDZ_3hr_slp.nc`    | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| PSFC                | 3hr               | `LMDZ_3hr_psol.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| SOILM (UPPER)       | 3hr               | `LMDZ_3hr_gqsb.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| LANDSEA             | 3hr               | `LMDZ_3hr_evapot.nc` | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| U10                 | 3hr               | `LMDZ_3hr_u10m.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| V10                 | 3hr               | `LMDZ_3hr_v10m.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_SFC:*` |
| SST                 | day               | `MED8_1d_2D.nc`      | curvilinear       | 0.1x0.125 lat/lon | `FILE_SST:*` |
| UU (9 levels)       | day               | `LMDZ_day_vitu.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_ML:*`  |
| VV (9 levels)       | day               | `LMDZ_day_vitv.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_ML:*`  |
| TT (9 levels)       | day               | `LMDZ_day_temp.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_ML:*`  |
| SPECHUMD (9 levels) | day               | `LMDZ_day_ovap.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_ML:*`  |
| GHT  (9 levels)     | day               | `LMDZ_day_geop.nc`   | irregular lat/lon | 0.30x0.35 lat/lon | `FILE_ML:*`  |
|                     |                   |                      |                   |                   |              |

## Regridding 

The WPS intermediate format supports only standard projection (lat/lon, Mercator, LCC, stereographic, rotated pole), however the Medocordex dataset use a non-standard projections. So we have to remap it to a canonical projection. 

### the atmosphere

The atmospheric variables are arranged on an non-regular lat/lon grid.

![img](C:\Users\Francesco\Desktop\img.png)

In we consider only the region near to the Adriatic sea the grid could be approximated as a regular lat/lon grid (0.30x0.35). So we have used a nearest neighbor interpolation (source to destination) to remap the grid.

### the ocean

The oceanic grid is curvilinear unstructured.

In the region of interest It has been interpolated to a regular lat/lon grid.

## Output timestep and land-sea mask

1. The Land sea mask is extracted from evapotranspiration. 
2. All variables into intermediate format have daily frequency. All variables sampled with 3 hours frequency are averaged on daily basis. 

## Soil layers

The WRF model to run requires at least 2 soil layers. In our case we have the soil moisture (SOILM) on the upper layer and the soil temperature is missing. So the routine creates 2 dummy soil layers. The upper layer (depth 0 cm) has the soil moisture equals to SOILM and the soil temperature equals to the mean T2M in summer. The bottom soil layer (depth 30 cm) is equal to upper soil layer.
