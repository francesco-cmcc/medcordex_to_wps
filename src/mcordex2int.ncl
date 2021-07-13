; ---- NCL script to convert MEDCORDEX to WPS intermediate files.
; ---- Created by F. Repola, I. Manco, C. De Lucia from CMCC Foundaion -----
load "$NCARG_ROOT/lib/ncarg/nclscripts/contrib/cd_string.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/esmf/ESMF_regridding.ncl"

; ---- UTILITIES
function get_fpath(base:string, fname:string)
local pattern, ls_command, ls_out
; --- Function to locate local files
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
; --- print the help and die
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
;----- read variables from environment
local out_var
begin
	if(ismissing(getenv(var))) then 
		printNdie(var)
	else
		out_var =  getenv(var) + "/" 
	end if
	return out_var
end


; ---- MAIN
begin
	; ---- Read the inputs and outputs paths from environment variable
	ATMDATA = read_envvar("ATMDATA")
	OCNDATA = read_envvar("OCNDATA")
	OUTPATH = read_envvar("OUTPATH")

	; ---- Open input files for surface fields
	t2m_name =        get_fpath( ATMDATA, "LMDZ_day_t2m.nc*" )
	spechumd_name =   get_fpath( ATMDATA, "LMDZ_3hr_q2m.nc*" )
	pmsl_name =       get_fpath( ATMDATA, "LMDZ_3hr_slp.nc*" )
	psfc_name =       get_fpath( ATMDATA, "LMDZ_3hr_psol.nc*")
	soilm_name =	  get_fpath( ATMDATA, "LMDZ_3hr_gqsb.nc*" ) ; we use the upper soil moisture 
	landsea_name =    get_fpath( ATMDATA, "LMDZ_3hr_evapot.nc*" )
	u10_name =        get_fpath( ATMDATA, "LMDZ_3hr_u10m.nc*" )
	v10_name =        get_fpath( ATMDATA, "LMDZ_3hr_v10m.nc*" )
	sst_name =        get_fpath( OCNDATA, "MED8_1d_2D.nc*" )

	T2Mfile =      addfile(t2m_name, "r")
	SPECHUMDfile = addfile(spechumd_name, "r")
	PMSLfile =     addfile(pmsl_name, "r")
	PSFCfile =     addfile(psfc_name, "r")
	LSMfile = 	   addfile(landsea_name, "r")
	SMfile  = 	   addfile(soilm_name, "r")
	U10file =  	   addfile(u10_name, "r")
	V10file =  	   addfile(v10_name, "r")
	SSTfile =      addfile(sst_name, "r")

	; ---- preprocessing of surface variables
	t2m_nat         = T2Mfile->t2m
	spechumd_3h_nat = SPECHUMDfile->q2m 
	pmsl_3h_nat     = PMSLfile->slp
	psfc_3h_nat     = PSFCfile->psol
	evapot_3h_nat   = LSMfile->evapot ; --- the landsea mask is extracted from evapot
	sm_3h_nat       = SMfile->gqsb
	u10_3h_nat      = U10file->u10m
	v10_3h_nat      = V10file->v10m
	sst_nat         = SSTfile->sosstsst

	; ---- Regridding parameters atm 
	DLAT = 0.30 ; degrees
	DLON = 0.35 ; degrees
	DLAT_DLON = "0.30x0.35" 
	regrid_atm             = True 
	regrid_atm@SkipSrcGrid = False
	regrid_atm@SkipDstGrid = False
	regrid_atm@SkipWgtGen  = False
	; regrid_atm@Overwrite   = True
	regrid_atm@ForceOverwrite   = True
	regrid_atm@SrcGridLat  = T2Mfile&lat
	regrid_atm@SrcGridLon  = T2Mfile&lon
	regrid_atm@DstGridType = DLAT_DLON
	regrid_atm@InterpMethod= "neareststod"
	regrid_atm@SrcRegional = True
	regrid_atm@DstRegional = True
	regrid_atm@SrcFileName = "src_atm_grid.nc"
	regrid_atm@DstFileName = "dst_atm_grid.nc"
	regrid_atm@WgtFileName = "weight_atm.nc"

	Nlon = dimsizes(T2Mfile&lon)
	Nlat = dimsizes(T2Mfile&lat)
	latN = T2Mfile&lat(0)
	latS = T2Mfile&lat(Nlat -1)
	lonW = T2Mfile&lon(0)
	lonE = T2Mfile&lon(Nlon -1)
	regrid_atm@DstLLCorner    = (/ latS, lonW /)
	regrid_atm@DstURCorner    = (/ latN, lonE /)

	; ---- regrid atm surface fields 
	print("info: Regridding T2M to "+ DLAT_DLON + " lat/lon")
	t2m         = ESMF_regrid(t2m_nat        , regrid_atm)
	regrid_atm@SkipSrcGrid = True
	regrid_atm@SkipDstGrid  = True
	regrid_atm@SkipWgtGen  = True
	print("info: Regridding SPECHUMD to "+ DLAT_DLON + " lat/lon")
	spechumd_3h = ESMF_regrid(spechumd_3h_nat, regrid_atm)
	print("info: Regridding PMSL to "+ DLAT_DLON + " lat/lon")
	pmsl_3h     = ESMF_regrid(pmsl_3h_nat    , regrid_atm)
	print("info: Regridding PSFC to "+ DLAT_DLON + " lat/lon")
	psfc_3h     = ESMF_regrid(psfc_3h_nat    , regrid_atm)
	print("info: Regridding LANDSEA to "+ DLAT_DLON + " lat/lon")
	evapot_3h   = ESMF_regrid(evapot_3h_nat  , regrid_atm)
	print("info: Regridding SOILM to "+ DLAT_DLON + " lat/lon")
	sm_3h       = ESMF_regrid(sm_3h_nat      , regrid_atm)
	print("info: Regridding U10 to "+ DLAT_DLON + " lat/lon")
	u10_3h      = ESMF_regrid(u10_3h_nat     , regrid_atm)
	print("info: Regridding V10 to "+ DLAT_DLON + " lat/lon")
	v10_3h      = ESMF_regrid(v10_3h_nat     , regrid_atm)

	; ---- regrid sst
	SST_DLAT = 0.1 ; degrees
	SST_DLON = 0.125 ; degrees
	SST_DLAT_DLON = "0.1x0.125" 
	regrid_ocn = regrid_atm
	regrid_ocn@SkipSrcGrid = False
	regrid_ocn@SkipDstGrid = False
	regrid_ocn@SkipWgtGen  = False
	delete(regrid_ocn@SrcGridLat)
	delete(regrid_ocn@SrcGridLon)
	regrid_ocn@SrcGridLat  = SSTfile->nav_lat
	regrid_ocn@SrcGridLon  = SSTfile->nav_lon
	; regrid_ocn@SrcGridMask = where(sst_nat(0,:,:) .gt. 0.0, 1, 0) 
	regrid_ocn@InterpMethod= "neareststod"
	regrid_ocn@SrcFileName = "src_ocn_grid.nc"
	regrid_ocn@DstFileName = "dst_ocn_grid.nc"
	regrid_ocn@WgtFileName = "weight_ocn.nc"
	regrid_ocn@DstGridType = SST_DLAT_DLON

	; ---- remap sst 
	print("info: Regridding SST to " + SST_DLAT_DLON + " lat/lon")
	sst_r        = ESMF_regrid(sst_nat     , regrid_ocn)
	sst          = sst_r + 273.15  ; to Kelvin
	; ---- create landsea mask for sst 
	sst_mask     = where(sst_nat .gt. 0.0, 1, 0)
	print("info: Regridding SST_MASK to "+ SST_DLAT_DLON + " lat/lon")
	sst_lsm          = ESMF_regrid(sst_mask     , regrid_ocn)
	
	; - Daily aggregation for 3h variables
	nDim = 0
	spechumd  = calculate_daily_values(spechumd_3h, "avg", nDim, False)
	pmsl      = calculate_daily_values(pmsl_3h, "avg", nDim, False)
	psfc      = calculate_daily_values(psfc_3h, "avg", nDim, False)
	evapot    = calculate_daily_values(evapot_3h, "avg", nDim, False)
	sm        = calculate_daily_values(sm_3h, "avg", nDim, False)
	u10        = calculate_daily_values(u10_3h, "avg", nDim, False)
	v10        = calculate_daily_values(v10_3h, "avg", nDim, False)

	; - Correct time axis 
	spechumd&time = t2m&time
	pmsl&time = t2m&time    
	psfc&time = t2m&time   
	evapot&time = t2m&time
	sm&time = t2m&time
	 
	; - Create landsea mask for atm variables
	; lsm = where(isnan_ieee(evapot), 0, 1)
	; lsm = where(evapot .gt. 1.e19, 0.0, 1.0)
	lsm = where(ismissing(evapot), 0.0, 1.0)

	; - Create skin temperature
	; skt = t2m
	; - Create soil temperature as a summer mean temeperature 
	t2m_mon = calculate_monthly_values(t2m, "avg", nDim, False)
	soilt_2d = dim_avg_n(t2m_mon(5:7,:,:), 0)
	soilt = t2m * 0 
	NDAYS = dimsizes(soilt(:,0,0))
	do t=0,NDAYS-1
		soilt(t,:,:) = soilt_2d(:,:)
	end do 


	; ---- Open input files on pressure levels 
	Tfile_name =  get_fpath( ATMDATA, "LMDZ_day_temp.nc*" )
	Ufile_name =  get_fpath( ATMDATA, "LMDZ_day_vitu.nc*" ) 
	Vfile_name =  get_fpath( ATMDATA, "LMDZ_day_vitv.nc*" )
	Sfile_name =  get_fpath( ATMDATA, "LMDZ_day_ovap.nc*" )
	Gfile_name =  get_fpath( ATMDATA, "LMDZ_day_geop.nc*" )

	Tfile = addfile(Tfile_name, "r")
	Ufile = addfile(Ufile_name, "r")
	Vfile = addfile(Vfile_name, "r")
	Sfile = addfile(Sfile_name, "r")
	Gfile = addfile(Gfile_name, "r")

	; ---- select fields
	UonP_nat = Ufile->vitu
	VonP_nat = Vfile->vitv
	TonP_nat = Tfile->temp 
	RonP_nat = Sfile->ovap
	ZonP_nat = Gfile->geop

	; ---- regrid pressure fields
	print("info: Regridding UU to " + DLAT_DLON + " lat/lon")
	UonP = ESMF_regrid(UonP_nat, regrid_atm)
	print("info: Regridding VV to " + DLAT_DLON + " lat/lon")
	VonP = ESMF_regrid(VonP_nat, regrid_atm)
	print("info: Regridding TT to " + DLAT_DLON + " lat/lon")
	TonP = ESMF_regrid(TonP_nat, regrid_atm) 
	print("info: Regridding QQ to " + DLAT_DLON + " lat/lon")
	RonP = ESMF_regrid(RonP_nat, regrid_atm) 
	print("info: Regridding ZZ to " + DLAT_DLON + " lat/lon")
	ZonP = ESMF_regrid(ZonP_nat, regrid_atm)
	; ---- description 

	output_file_name = OUTPATH + "/FILE"
	earth_radius     = 6367.470

	; - surface 
	FIELD_T2M        = "TT"  
	UNITS_T2M        = "K" 
	DESC_T2M         = "2-meter air temperature"

	FIELD_SPECHUMD   = "SPECHUMD"
	UNITS_SPECHUMD   = "kg kg-1"
	DESC_SPECHUMD    = "Specific humidy"
					  
	FIELD_PMSL        = "PMSL"
	UNITS_PMSL        = "Pa"
	DESC_PMSL        =  "Mean sea-level pressure"
					   
	FIELD_PSFC        = "PSFC"
	UNITS_PSFC        = "Pa"
	DESC_PSFC         = "Surface pressure"
					   
	FIELD_LSM        = "LANDSEA"
	UNITS_LSM        = "fraction"
	DESC_LSM         = "Land-sea mask"
	
	FIELD_SST_MASK   = "SST_MASK"
	UNITS_SST_MASK   = "fraction"
	DESC_SST_MASK    = "Land-sea mask for ocen variables"
	
					  
	FIELD_SOILT        = "SOILT000"
	UNITS_SOILT        = "K"
	DESC_SOILT         = "Soil temperature 0 cm"

	FIELD_SOILM        = "SOILM000"
	UNITS_SOILM        = "kg m-3"
	DESC_SOILM         = "Soil moisture 0 cm"

	FIELD_SOILT300        = "SOILT300"
	UNITS_SOILT300        = "K"
	DESC_SOILT300         = "Soil temperature 30 cm"

	FIELD_SOILM300        = "SOILM300"
	UNITS_SOILM300        = "kg m-3"
	DESC_SOILM300         = "Soil moisture 30 cm"

	FIELD_SKT        = "SKINTEMP"
	UNITS_SKT        = "K"
	DESC_SKT         = "Skin temperature"

	FIELD_U10          = "UU"
	UNITS_U10          = "m s-1"
	DESC_U10           = "10-meter wind u-component"

	FIELD_V10          = "VV"
	UNITS_V10          = "m s-1"
	DESC_V10           = "10-meter wind v-component"
	; - pressure levels
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

	pnew = (/ 1000, 900, 850, 700, 500, 400, 300, 200, 100 /)*100

	NLEV = dimsizes(pnew)
	NT = dimsizes(Ufile->vitu&time) ; --- daily frequency

	; ---- ATM grid description for itermediate files
	opt                   = True
	opt@projection        = "Equidistant_Lat_Lon"
	opt@map_source        = "CMCC - REMHI"
	opt@startloc          = "SWCORNER"	     ; 8 chars exact
	opt@startlon          = lonW
	opt@startlat          = latS
	opt@deltalon          = DLON
	opt@deltalat          = DLAT
	opt@earth_radius      = earth_radius
	opt@is_wind_earth_relative = False

	; ---- OCN grid description for itermediate files
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

	; --- Write surface fields

	sfc_fname = output_file_name + "_SFC"
	sst_fname = output_file_name + "_SST"
	ml_fname = output_file_name + "_ML" 

	; ---- remove all match files present in out folder
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

	opt@level = 200100
	sst_opt@level = 200100

	do t=0,NT-1
		; ---- select current date 
		date = UonP&time(t)
		opt@date = cd_string(date,"%Y-%N-%D_%H")
		sst_opt@date = cd_string(date,"%Y-%N-%D_%H")

		wrf_wps_write_int(sfc_fname,FIELD_T2M,UNITS_T2M,\
						  DESC_T2M,t2m(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SPECHUMD,UNITS_SPECHUMD,\
						  DESC_SPECHUMD,spechumd(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_PMSL,UNITS_PMSL,\
						  DESC_PMSL,pmsl(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_PSFC,UNITS_PSFC,\
						  DESC_PSFC,psfc(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_LSM,UNITS_LSM,\
						  DESC_LSM,lsm(t,:,:),opt)
		; ---- Upper soil level 
		wrf_wps_write_int(sfc_fname,FIELD_SOILT,UNITS_SOILT,\
						  DESC_SOILT,soilt(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SOILM,UNITS_SOILM,\
						  DESC_SOILM,sm(t,:,:),opt)
		; ---- lower soil level
		wrf_wps_write_int(sfc_fname,FIELD_SOILT300,UNITS_SOILT300,\
						  DESC_SOILT300,soilt(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_SOILM300,UNITS_SOILM300,\
						  DESC_SOILM300,sm(t,:,:),opt)
		; ---- Wind 
		wrf_wps_write_int(sfc_fname,FIELD_U10,UNITS_U10,\
						  DESC_U10,u10(t,:,:),opt)
		wrf_wps_write_int(sfc_fname,FIELD_V10,UNITS_V10,\
						  DESC_V10,v10(t,:,:),opt)
		; ---- SST
		wrf_wps_write_int(sst_fname,FIELD_SST,UNITS_SST,\
						  DESC_SST,sst(t,:,:),sst_opt)
		wrf_wps_write_int(sst_fname,FIELD_SST_MASK,UNITS_SST_MASK,\
						  DESC_SST_MASK,sst_lsm(t,:,:),sst_opt)
	end do

	; ---- Write fields on pressure levels 
	do t=0,NT-1
		; ---- select current date 
		date = UonP&time(t)
		opt@date = cd_string(date,"%Y-%N-%D_%H")
		do ilev=0,NLEV-1
			; ---- select the pressure level
			opt@level = pnew(ilev)

			wrf_wps_write_int(ml_fname,FIELD_U,UNITS_U,\
							  DESC_U,UonP(t,ilev,:,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_V,UNITS_V,\
							  DESC_V,VonP(t,ilev,:,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_T,UNITS_T,\
							  DESC_T,TonP(t,ilev,:,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_R,UNITS_R,\
							  DESC_R,RonP(t,ilev,:,:),opt)
			wrf_wps_write_int(ml_fname,FIELD_Z,UNITS_Z,\
							  DESC_Z,ZonP(t,ilev,:,:),opt)
		end do
	end do
end 
