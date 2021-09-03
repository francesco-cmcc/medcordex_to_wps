; ---- NCL script to convert MEDCORDEX to WPS intermediate files.
; ---- Created by F. Repola, I. Manco, C. De Lucia from CMCC Foundation -----


; # LOAD LIBRARIES [1]
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"


; # USER DEFINED FUNCTIONS [2]
function get_fpath(base:string, fname:string)
local pattern, ls_command, ls_out
; ## Get full path of local file from shell regular expression [3]
begin
    pattern =  base + fname 
    ls_command =  "ls " + pattern 
    ls_out = systemfunc(ls_command)
    if (dimsizes(ls_out) .ne. 1)
        print("Error - Too much matching files for patter:")
        print(pattern)
        print(ls_out)
        exit()
    end if 
    return ls_out
end 

procedure printNdie(miss_var:string)
; ## print the help and die [4]
begin
    print("Error: " + miss_var + " is missing !")
    print("This script require the following environment variables:")
    print(" - ATMDATA")
    print(" - OCNDATA")
    print(" - OUTPATH")
    print(" ")
	print("Example of usage: ")
	print("  export ATMDATA=MEDCORDEX/CNRM-CM5/historical/atm/2002/ ")
	print("  export OCNDATA=MEDCORDEX/CNRM-CM5/historical/ocn/2002/ ")
	print("  export OUTPATH=WPS/itermediate_out/ ")
	print("  ncl mcordex2int.ncl ")
	exit()
end

function read_envvar(var:string)
; ## read environment variables [5]
local out_var
begin
	if(ismissing(getenv(var))) then 
		printNdie(var)
	else
		out_var =  getenv(var) + "/" 
	end if
	return out_var
end

; # MAIN PROGRAM [6]
begin
	; ## step 1. Read all variables from input files [7]
	; ### Read environment variables [8]
	ATMDATA = read_envvar("ATMDATA")
	OCNDATA = read_envvar("OCNDATA")
	OUTPATH = read_envvar("OUTPATH")
	LAND_MASK_PATH = read_envvar("LAND_MASK_PATH")
	; ### get files' paths [9]
	t2m_name        =  get_fpath( ATMDATA, "LMDZ_day_t2m.nc*" )
	spechumd_name   =  get_fpath( ATMDATA, "LMDZ_3hr_q2m.nc*" )
	pmsl_name       =  get_fpath( ATMDATA, "LMDZ_3hr_slp.nc*" )
	psfc_name       =  get_fpath( ATMDATA, "LMDZ_3hr_psol.nc*")
	soilm_name      =  get_fpath( ATMDATA, "LMDZ_3hr_gqsb.nc*" )
	u10_name        =  get_fpath( ATMDATA, "LMDZ_3hr_u10m.nc*" )
	v10_name        =  get_fpath( ATMDATA, "LMDZ_3hr_v10m.nc*" )
	sst_name        =  get_fpath( OCNDATA, "MED8_1d_2D.nc*" )
	Tfile_name      =  get_fpath( ATMDATA, "LMDZ_day_temp.nc*" )
	Ufile_name      =  get_fpath( ATMDATA, "LMDZ_day_vitu.nc*" ) 
	Vfile_name      =  get_fpath( ATMDATA, "LMDZ_day_vitv.nc*" )
	Sfile_name      =  get_fpath( ATMDATA, "LMDZ_day_ovap.nc*" )
	Gfile_name      =  get_fpath( ATMDATA, "LMDZ_day_geop.nc*" )
	; ### open data files (read-only) [10]
	T2Mfile         =  addfile(t2m_name, "r")
	SPECHUMDfile    =  addfile(spechumd_name, "r")
	PMSLfile        =  addfile(pmsl_name, "r")
	PSFCfile        =  addfile(psfc_name, "r")
	LSMfile         =  addfile(LAND_MASK_PATH, "r")
	SMfile          =  addfile(soilm_name, "r")
	U10file         =  addfile(u10_name, "r")
	V10file         =  addfile(v10_name, "r")
	SSTfile         =  addfile(sst_name, "r")
	Tfile           =  addfile(Tfile_name, "r")
	Ufile           =  addfile(Ufile_name, "r")
	Vfile           =  addfile(Vfile_name, "r")
	Sfile           =  addfile(Sfile_name, "r")
	Gfile           =  addfile(Gfile_name, "r")
	; #### load all variables [11]
	t2m_nat         =  T2Mfile->t2m  ; "nat" stands for native
	spechumd_3h_nat =  SPECHUMDfile->q2m 
	pmsl_3h_nat     =  PMSLfile->slp
	psfc_3h_nat     =  PSFCfile->psol
	sm_3h_nat       =  SMfile->gqsb
	u10_3h_nat      =  U10file->u10m
	v10_3h_nat      =  V10file->v10m
	sst_nat         =  SSTfile->sosstsst
	UonP_nat        =  Ufile->vitu
	VonP_nat        =  Vfile->vitv
	TonP_nat        =  Tfile->temp 
	RonP_nat        =  Sfile->ovap
	ZonP_nat        =  Gfile->geop
	; #### create a land-sea mask for atm fields as suggested by Laurent Li   [12]
	fract_ter = LSMfile->fract_ter
	fract_lic = LSMfile->fract_lic
	frac_lnd = fract_ter + fract_lic
	lsm_nat = where( frac_lnd .gt. 0.5, 1.0, 0.0)	
	
	; ## step 2. Resize and/or regrid atmospheric and oceanic fields [13]
	; ### crop the atmospheric grid  [14]
	; #### define box indices [15]
	NORTH = 15
	SOUTH = 88 
	EAST  = 40
	WEST  = 107
	; #### crop atm fields  [16]
	t2m = t2m_nat(:, NORTH:SOUTH, EAST:WEST)
	spechumd_3h = spechumd_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	pmsl_3h = pmsl_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	psfc_3h = psfc_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	sm_3h = sm_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	u10_3h = u10_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	v10_3h = v10_3h_nat(:, NORTH:SOUTH, EAST:WEST)
	lsm = lsm_nat(NORTH:SOUTH, EAST:WEST)
	UonP = UonP_nat(:, :,NORTH:SOUTH, EAST:WEST)
	VonP = VonP_nat(:, :, NORTH:SOUTH, EAST:WEST)
	TonP = TonP_nat(:, :, NORTH:SOUTH, EAST:WEST)
	RonP = RonP_nat(:, :, NORTH:SOUTH, EAST:WEST)
	ZonP = ZonP_nat(:, :, NORTH:SOUTH, EAST:WEST)
	; #### Daily aggregation for variables with 3h frequency [17]
	nDim       = 0
	spechumd   = calculate_daily_values(spechumd_3h, "avg", nDim, False)
	pmsl       = calculate_daily_values(pmsl_3h, "avg", nDim, False)
	psfc       = calculate_daily_values(psfc_3h, "avg", nDim, False)
	sm         = calculate_daily_values(sm_3h, "avg", nDim, False)
	u10        = calculate_daily_values(u10_3h, "avg", nDim, False)
	v10        = calculate_daily_values(v10_3h, "avg", nDim, False)
	spechumd&time = t2m&time ; Correct time axis 
	pmsl&time     = t2m&time    
	psfc&time     = t2m&time   
	sm&time       = t2m&time
	u10&time      = t2m&time 
	v10&time      = t2m&time
	; #### Create missing soil variables [18]
	; Create soil temperature as a summer mean temeperature 
	t2m_mon = calculate_monthly_values(t2m, "avg", nDim, False)
	soilt_2d = dim_avg_n(t2m_mon(5:7,:,:), 0)
	soilt = t2m * 0 
	NDAYS = dimsizes(soilt(:,0,0))
	do t=0,NDAYS-1
		soilt(t,:,:) = soilt_2d(:,:)
	end do 
	; ### Regrid sst [19]

	; #### Define sst interpolation options [20]
	SST_DLAT                   = 0.1 ; degrees
	SST_DLON                   = 0.125 ; degrees
	SST_DLAT_DLON              = "0.1x0.125" 
	regrid_ocn                 = True
	regrid_ocn@SkipSrcGrid     = False
	regrid_ocn@SkipDstGrid     = False
	regrid_ocn@SkipWgtGen      = False
	regrid_ocn@ForceOverwrite  = True
	regrid_ocn@SrcRegional     = True
	regrid_ocn@DstRegional     = True
	regrid_ocn@SrcGridLat      = SSTfile->nav_lat
	regrid_ocn@SrcGridLon      = SSTfile->nav_lon
	regrid_ocn@InterpMethod    = "neareststod"
	regrid_ocn@SrcFileName     = "src_ocn_grid.nc"
	regrid_ocn@DstFileName     = "dst_ocn_grid.nc"
	regrid_ocn@WgtFileName     = "weight_ocn.nc"
	regrid_ocn@DstGridType     = SST_DLAT_DLON
	nav_lat = SSTfile->nav_lat
	nav_lon = SSTfile->nav_lon
	latN = max(nav_lat)
	latS = min(nav_lat)
	lonW = min(nav_lon)
	lonE = max(nav_lon)
	regrid_ocn@DstLLCorner    = (/ latS, lonW /)
	regrid_ocn@DstURCorner    = (/ latN, lonE /)
	; #### create a land sea mask for SST [21]
	sst_msk    = ESMF_regrid(sst_nat ,regrid_ocn)
	sst_lsm    = where(sst_msk .gt. 0.0, 0, 1)
	; #### sst interpolation [22]
	MISSING = 0.0 ; this value is used in the next steps
	sst_nan = sst_nat
	sst_nan@_FillValue = MISSING
	sstK       = sst_nan + 273.15 ; to Kelvin
	; to extrapolate points over land, should be defined a mask
	srcmask = where(sst_nat(0,:,:) .gt. 0, 1, 0) 
	regrid_ocn@SrcGridMask = srcmask
	sst        = ESMF_regrid(sstK, regrid_ocn)
	
	; ## step 3. Write it to intermediate format [23]
	; ### definition of variable ids to be written in intermediate files [24]
	; surface 
	FIELD_T2M        = "TT"  
	UNITS_T2M        = "K" 
	DESC_T2M         = "2-meter air temperature"

	FIELD_SPECHUMD   = "SPECHUMD"
	UNITS_SPECHUMD   = "kg kg-1"
	DESC_SPECHUMD    = "Specific humidy"
					  
	FIELD_PMSL       = "PMSL"
	UNITS_PMSL       = "Pa"
	DESC_PMSL        =  "Mean sea-level pressure"
					   
	FIELD_PSFC       = "PSFC"
	UNITS_PSFC       = "Pa"
	DESC_PSFC        = "Surface pressure"
					   
	FIELD_LSM        = "LANDSEA"
	UNITS_LSM        = "fraction"
	DESC_LSM         = "Land-sea mask"
	
	FIELD_SST_MASK   = "SST_MASK"
	UNITS_SST_MASK   = "fraction"
	DESC_SST_MASK    = "Land-sea mask for ocen variables"
	
					  
	FIELD_SOILT      = "SOILT000"
	UNITS_SOILT      = "K"
	DESC_SOILT       = "Soil temperature 0 cm"

	FIELD_SOILM      = "SOILM000"
	UNITS_SOILM      = "kg m-3"
	DESC_SOILM       = "Soil moisture 0 cm"

	FIELD_SOILT300   = "SOILT300"
	UNITS_SOILT300   = "K"
	DESC_SOILT300    = "Soil temperature 30 cm"

	FIELD_SOILM300   = "SOILM300"
	UNITS_SOILM300   = "kg m-3"
	DESC_SOILM300    = "Soil moisture 30 cm"

	FIELD_SKT        = "SKINTEMP"
	UNITS_SKT        = "K"
	DESC_SKT         = "Skin temperature"

	FIELD_U10        = "UU"
	UNITS_U10        = "m s-1"
	DESC_U10         = "10-meter wind u-component"

	FIELD_V10        = "VV"
	UNITS_V10        = "m s-1"
	DESC_V10         = "10-meter wind v-component"
	; pressure levels
	FIELD_T          = "TT"
	UNITS_T          = "K"
	DESC_T           = "Temperature"

	FIELD_U          = "UU"
	UNITS_U          = "m s-1"
	DESC_U           = "Zonal Wind Speed"

	FIELD_V          = "VV"
	UNITS_V          = "m s-1"
	DESC_V           = "Meridional Wind Speed"

	FIELD_R          = "SPECHUMD"
	UNITS_R          = "kg kg-1"
	DESC_R           = "Specific Humidity"

	FIELD_Z          = "GHT"
	UNITS_Z          = "m"
	DESC_Z           = "Geopotential Height"

	FIELD_SST        = "SST"
	UNITS_SST        = "K"
	DESC_SST         = "Sea-Surface Temperature"

	pnew = (/ 1000, 900, 850, 700, 500, 400, 300, 200, 100 /)*100 ; Pa 

	NLEV = dimsizes(pnew)
	NT = dimsizes(Ufile->vitu&time) ; daily frequency
	
	; ### define base patter for outputs and earth radius [25]
	output_file_name = OUTPATH + "/FILE"
	earth_radius     = 6367.470 ; km 
	
	; ### define output grid properties to write into intermediate format [26]
	; #### ATM grid description for intermediate files [27]
	DLAT                  = 0.30 ; degrees
	DLON                  = 0.3461 ; degrees
	opt                   = True
	opt@projection        = "Equidistant_Lat_Lon"
	opt@map_source        = "CMCC - REMHI"
	opt@startloc          = "SWCORNER"	     ; 8 chars exact
	opt@startlon          = min(t2m&lon)
	opt@startlat          = min(t2m&lat)
	opt@deltalon          = DLON
	opt@deltalat          = DLAT
	opt@earth_radius      = earth_radius
	opt@is_wind_earth_relative = False
	; #### OCN grid description for intermediate files [28]
	sst_opt                   = True
	sst_opt@projection        = "Equidistant_Lat_Lon"
	sst_opt@map_source        = "CMCC - REMHI"
	sst_opt@startloc          = "SWCORNER"	     ; 8 chars exact
	sst_opt@startlon          = lonW
	sst_opt@startlat          = latS
	sst_opt@deltalon          = SST_DLON
	sst_opt@deltalat          = SST_DLAT
	sst_opt@earth_radius      = earth_radius
	sst_opt@is_wind_earth_relative = False
	; #### removing existing files in output folder [29]
	sfc_fname = output_file_name + "_SFC"
	sst_fname = output_file_name + "_SST"
	ml_fname = output_file_name + "_ML" 
	cmd = "rm -f "
	do t=0,NT-1
		date = UonP&time(t)
		dt = cd_string(date,"%Y-%N-%D_%H")
		cmd = cmd + sfc_fname + ":" + dt + " "
		cmd = cmd + sst_fname + ":" + dt + " "
		cmd = cmd + ml_fname + ":" + dt + " "
	end do 
	print("info: Removing matching files in output directory")
	system(cmd)

	; #### Write surface fields [30]
	opt@level = 200100
	sst_opt@level = 200100
	
	do t=0,NT-1
		; select current date 
		date = UonP&time(t)
		opt@date = cd_string(date,"%Y-%N-%D_%H")
		sst_opt@date = cd_string(date,"%Y-%N-%D_%H")
		; NOTE: wrf_wps_write_int expects that latitudes and longitude in
		; ascending order. Since the latitudes have a descending order
		; for the atmospheric variables we must flip the latitudes
		; axis manually. SST is already flipped by interpolation function
		wrf_wps_write_int(sfc_fname,FIELD_T2M,UNITS_T2M,\
						  DESC_T2M,t2m(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SPECHUMD,UNITS_SPECHUMD,\
						  DESC_SPECHUMD,spechumd(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_PMSL,UNITS_PMSL,\
						  DESC_PMSL,pmsl(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_PSFC,UNITS_PSFC,\
						  DESC_PSFC,psfc(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_LSM,UNITS_LSM,\
						  DESC_LSM,lsm(::-1,:),opt)
		; ---- Upper soil level 
		wrf_wps_write_int(sfc_fname,FIELD_SOILT,UNITS_SOILT,\
						  DESC_SOILT,soilt(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SOILM,UNITS_SOILM,\
						  DESC_SOILM,sm(t,::-1,:),opt)
		; ---- lower soil level
		wrf_wps_write_int(sfc_fname,FIELD_SOILT300,UNITS_SOILT300,\
						  DESC_SOILT300,soilt(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SOILM300,UNITS_SOILM300,\
						  DESC_SOILM300,sm(t,::-1,:),opt)
		; ---- Wind 
		wrf_wps_write_int(sfc_fname,FIELD_U10,UNITS_U10,\
						  DESC_U10,u10(t,::-1,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_V10,UNITS_V10,\
						  DESC_V10,v10(t,::-1,:),opt)
		; ---- SST
		wrf_wps_write_int(sst_fname,FIELD_SST,UNITS_SST,\
						  DESC_SST,sst(t,:,:),sst_opt)
		wrf_wps_write_int(sst_fname,FIELD_LSM,UNITS_SST_MASK,\
						  DESC_SST_MASK,sst_lsm(t,:,:),sst_opt)
	end do

	; #### Write fields on pressure levels  [31]
	do t=0,NT-1
		; select current date 
		date = UonP&time(t)
		opt@date = cd_string(date,"%Y-%N-%D_%H")
		do ilev=0,NLEV-1
			; select the pressure level
			opt@level = pnew(ilev)

			wrf_wps_write_int(ml_fname,FIELD_U,UNITS_U,\
							  DESC_U,UonP(t,ilev,::-1,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_V,UNITS_V,\
							  DESC_V,VonP(t,ilev,::-1,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_T,UNITS_T,\
							  DESC_T,TonP(t,ilev,::-1,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_R,UNITS_R,\
							  DESC_R,RonP(t,ilev,::-1,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_Z,UNITS_Z,\
							  DESC_Z,ZonP(t,ilev,::-1,:),opt)
		end do
	end do
end
