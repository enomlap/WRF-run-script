#!/bin/bash
# Modified for new version of wrf
# zuo,Jul 03, 2016
# Nested.bash

# zuohj, NXMB
# Dec.30, 2010
# Run wrf3.2 for Zhangxiaojing
# zuo, Dec.16, 2011
# run wrf for specified day....

# CAUTION:
# georgid.exe must run preperly already and the domain defination files exist.
# otherwise, run this FIRST:
# -------------------------------------
# ./geogrid.exe >& geogrid.log.${YEAR}1123
# vi geogrid.log.${YEAR}1123 
# -------------------------------------


#----------------------------------------------------------------------
# public variables setting up
#----------------------------------------------------------------------
CENT_LAT=37.5;
CENT_LON=106.5;
SX1=30;
SY1=28;
SZ1=30;
DX1=3000;
DY1=3000;
TIME_STEP=45;

BASE="/public/home/wrf/WRFV3";
WRFOUT="/public/home/wrf/WRFV3/WRFOUT";
GEOGPATH='/public/geog/';
GFSBASE='/public/gfs/';
CPUS=8;
if [ $# -ne 3 ]; then
# TODO check argument number here.
    echo -e "\tusage: $0 FROM_TIME START_TIME END_TIME"
    echo "FOR EXAMPLE:"
    echo -e "\t$0 2013010112 2013010112 2013010118"
    echo -e "\t$0 2016070112 2016070112 2016070118"
    echo -e "\n\tthis will use the gfs.2010090112 dato as the \n\tglobal IC & BC to run wrf forcasting from \n\t2010090200 to 2010090300"
    exit 0;
fi
START_YEAR=`    echo $2     | cut -c1-4`;
END_YEAR=`      echo $3     | cut -c1-4`;

START_MONTH=`   echo $2     | cut -c5-6`;
END_MONTH=`     echo $3     | cut -c5-6`;

START_DAY=`     echo $2     | cut -c7-8`;
END_DAY=`       echo $3     | cut -c7-8`;

START_HOUR=`    echo $2     | cut -c9-10`;
END_HOUR=`      echo $3     | cut -c9-10`;

BASE_DATA_TIME=$1;

RUN_HOURS=$(((`date -d "${END_YEAR}-${END_MONTH}-${END_DAY}" +%s` - `date -d "${START_YEAR}-${START_MONTH}-${START_DAY}" +%s`)/3600+${END_HOUR}-${START_HOUR}));
if [ $RUN_HOURS -le 0 ];then
# examine the paraments
    echo "END_TIME must later than START_TIME!"
    exit 0
fi
# public variables setting up done.

#----------------------------------------------------------------------
# function defination part
#----------------------------------------------------------------------
function runwps(){
# 01 -------------------------------------
# WPS
  cd ${BASE}/WPS

  echo "- 1   RUN WPS-------------------------------------------------"
  echo "- 1.1 GENERATE NAMELIST.WPS ----------------------------------"
  cat > namelist.wps << EOF
&share
 wrf_core = 'ARW',
 max_dom = 1,
 start_date = '$START_YEAR-$START_MONTH-${START_DAY}_${START_HOUR}:00:00',
 end_date = '$END_YEAR-$END_MONTH-${END_DAY}_${END_HOUR}:00:00',
 interval_seconds = 21600,
 io_form_geogrid = 2,
 opt_output_from_geogrid_path = './',
/

&geogrid
 parent_id         = 1,
 parent_grid_ratio = 1,
 i_parent_start    = 1,
 j_parent_start    = 1,
 e_we              = $SX1,
 e_sn              = $SY1,
 geog_data_res     = '5',
 dx                = $DX1,
 dy                = $DY1,
 map_proj          =  'lambert',
 ref_lat           = $CENT_LAT,
 ref_lon           = $CENT_LON,
 truelat1          = 30,
 truelat2          = 60,
 stand_lon         = $CENT_LON,
 geog_data_path    = '$GEOGPATH',
/

&ungrib
 out_format        = 'WPS',
 prefix            = 'FILE',
/

&metgrid
 fg_name           = 'FILE',
 io_form_metgrid   = 2,
/
EOF
#return 0;
  ncl myplotwps.ncl
  convert wps_show_dom.ps wps_show_dom.png
#return; exit;
  cat > machfile <<EOF
node1 slots=16
node2 slots=16
node3 slots=16
node4 slots=16
EOF

# do some clean work...
  rm -f *.nc PFILE:* FILE:* GRIBFILE*
  echo "- 1.2 RUN GROGRID.EXE-----------------------------------------"
  ./geogrid.exe >& geogrid.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  tail -n 100 geogrid.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  echo "- END OF GROGRID.EXE RUN -------------------------------------"
#return;#-----------DEBUG-----------------
  # TODO check geogrid.exe output
  # TODO check namelist.wps

  echo "- 1.3 RUN UNGRIB.EXE------------------------------------------"
  rm GRIBFILE.* FILE:* met_em.d* 
  # TODO : check namelist.wps
  cd ${BASE}/WPS
  #/data3/wind/zuo/201301GFS/gfs.2013012412
  ./link_grib.csh $GFSBASE/$BASE_DATA_TIME/*
  ./ungrib.exe 
  #mpiexec -n 4 ./ungrib.exe >& ungrib.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  mv rsl.out.0000 ungrib.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  tail -n 100 ungrib.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  echo "- END OF UNGRIB.EXE RUN -------------------------------------"
  # TODO : check the log file here


  echo "- 1.4 RUN METGRID.EXE-----------------------------------------"
  # TODO : check namelist.wps
  #mpiexec -n 4 ./metgrid.exe >& metgrid.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  mpirun --bind-to-core --mca btl openib,sm,self -np 16 -hostfile ./machfile ./metgrid.exe 
  mv rsl.out.0000 metgrid.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  tail -n 100 metgrid.log.$START_YEAR$START_MONTH$START_DAY$START_HOUR.f${RUN_HOURS}
  echo "- END OF METGRID.EXE RUN -------------------------------------"

  # TODO : check the log file heri
} # end of function runwps()


function runwrf(){
# 02 -------------------------------------
# WRF
# TODO : check the namelist.wrf file first
  echo "- 2   RUN GRID WRF-------------------------------------"
  cd ${BASE}/WRFV3/run/
  echo "- 2.1 GENERATE NAMELIST.INPUT FOR GRID-----------------"
  echo "refere:";
  echo "http://www.mmm.ucar.edu/wrf/OnLineTutorial/Basics/WRF/namelist.input.htm";
  cat <<EOF | sed -e 's/##.*$//g' > namelist.input
&time_control
run_days                 = 0,
run_hours                = ${RUN_HOURS},
run_minutes              = 0,
run_seconds              = 0,
start_year               = $START_YEAR,
start_month              = $START_MONTH,
start_day                = $START_DAY,
start_hour               = $START_HOUR,
start_minute             = 00,
start_second             = 00,
end_year                 = $END_YEAR,
end_month                = $END_MONTH,
end_day                  = $END_DAY,
end_hour                 = $END_HOUR,
end_minute               = 00,
end_second               = 00,
interval_seconds         = 21600,
input_from_file          = .true.,
history_interval         = 60,
frames_per_outfile       = 500,
restart                  = .false.,
restart_interval         = 5000,
io_form_history          = 2,
io_form_restart          = 2,
io_form_input            = 2,
io_form_boundary         = 2,
debug_level              = 0,
/

&domains
time_step                = $TIME_STEP,
time_step_fract_num      = 0,
time_step_fract_den      = 1,
max_dom                  = 1,
e_we                     = $SX1,
e_sn                     = $SY1,
e_vert                   = $SZ1,
p_top_requested          = 5000,
num_metgrid_levels       = 32,
num_metgrid_soil_levels  = 4,
dx                       = $DX1,
dy                       = $DY1,
grid_id                  = 1,
parent_id                = 0,
i_parent_start           = 1,
j_parent_start           = 1,
parent_grid_ratio        = 1,
parent_time_step_ratio   = 1,
feedback                 = 1,
smooth_option            = 0
/

&physics
mp_physics               = 10,
ra_lw_physics            = 1,
ra_sw_physics            = 1,
radt                     = 30,
sf_sfclay_physics        = 1,
sf_surface_physics       = 2,
bl_pbl_physics           = 1,
bldt                     = 0,
cu_physics               = 1,
cudt                     = 5,
isfflx                   = 1,
ifsnow                   = 0,
icloud                   = 1,
surface_input_source     = 1,
num_soil_layers          = 4,
sf_urban_physics         = 0,
/

&fdda
/

&dynamics
w_damping                = 0,
diff_opt                 = 1,
km_opt                   = 4,
diff_6th_opt             = 0,
diff_6th_factor          = 0.12,
base_temp                = 290.,
damp_opt                 = 0,
zdamp                    = 5000.,
dampcoef                 = 0.01,
khdif                    = 0,
kvdif                    = 0,
non_hydrostatic          = .true.,
moist_adv_opt            = 1, 1,
scalar_adv_opt           = 1, 1,
/

&bdy_control
spec_bdy_width           = 5,
spec_zone                = 1,
relax_zone               = 4,
specified                = .true.,
nested                   = .false.,
/

&grib2
/

&namelist_quilt
nio_tasks_per_group      = 0,
nio_groups               = 1,
/

EOF

cat > machfile <<EOF
node1 slots=16
node2 slots=16
node3 slots=16
node4 slots=16
EOF
#return 0;
#nodebak slots=${CPUS} max_slots=${CPUS}

  echo "- 2.2 RUN REAL.EXE FOR GRID-----------------"
  rm -f met_em.d*.nc
  ln -sf ${BASE}/WPS/met_em.d*.nc .
  #mpirun -np 8 ./real.exe
  mpirun --bind-to-core --mca btl openib,sm,self -np 64 -hostfile ./machfile ./real.exe 
  #/home/soft/openmpi.static.ib/bin/mpirun -mca btl openib,self -np 8 -machinefile ./machfile ./real.exe

  echo "- 2.3 CHECK REAL.EXE OUTPUT FOR GRID-----------------"
  ic_size=`\ls -ls wrfinput_d01 | awk '{print $6}'`
  bc_times=`ncdump -h wrfbdy_d01 | grep 'Time = UNLIMITED' | cut -d'(' -f2 | cut -dc -f1`
  echo "=============================================================================";
  tail rsl.out.0000
  echo "=============================================================================";
  if [ $ic_size -ge 10000 ] ; then
  #if ( ( $ic_size > 10000 ) && ( $bc_times == 4 ) ) then
    rm rsl*
  else
      echo grid ic bc wrong size
      exit 2;
  fi

  echo "- 2.5 RUN GRID WRF.EXE -----------------"
  #mpirun -np 8 ./wrf.exe
  mpirun --bind-to-core --mca btl openib,sm,self -np 64 -hostfile ./machfile ./wrf.exe 

  echo "- 2.6 CHECK WRF.EXE OUTUT FOR GRID  -----------------"
#  m_times=`ncdump -h wrfout_d01_${START_YEAR}-${START_MONTH}-${START_DAY}_${START_HOUR}:00:00 | grep "Time = UNLIMITED" | cut -d"(" -f2 | cut -dc -f1`
#  echo m_times
#  echo "=============================================================================";
#  tail rsl.out.0000
#  echo "=============================================================================";
#  if [ $m_times -eq $((${RUN_HOURS} + 1)) ]; then
#     rm rsl*
#  else
#     echo grid wrf output wrong size
#     exit 3 
#  fi

  cd ${BASE}/WRFV3/run/
  mv wrfout_d0?_* $WRFOUT
} # end of function runwrf()

#----------------------------------------------------------------------
# function defination part
#----------------------------------------------------------------------
date;
runwps;
runwrf;
date;
#dump70m;

echo "7777777"
echo "---NORMAL END---"
exit 0



# TODO : check the output file
# TODO : mv the wrf output netCDF file to another place


