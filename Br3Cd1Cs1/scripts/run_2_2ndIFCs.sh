#!/bin/bash
#SBATCH -p v3_64
#SBATCH -N 1
#SBATCH -n 24
source /public1/soft/modules/module.sh
source /public1/home/sc30830/software/alamode/alamode-1.1.0/env.sh
source /public1/soft/other/vasp/cn-module-vasp.5.4.4.sh
module  unload intel/17.0.7
module unload anaconda
module load python/3.6.5
module load  mpi/intel/5.0.3.049
module load vasp/intel-17/vasp544

#VASP="/home/nijun/apps/vasp/vasp.5.4.1/bin/vasp_std"
vasppot="/public1/home/sc30830/pseudo/vasppot/vasppot_paw_pbe.54.sh"

## give the POSCAR format of supercell structure, it is the SPOSCAR generated by Phonopy ##
cp ./relax/SPOSCAR POSCAR

#-----------------------------------------------------------------------
element_num=$(cat element_num.dat)
ion_1=$(grep -B 1 Direct POSCAR | head -1 | awk '{print $1}')
ion_2=$(grep -B 1 Direct POSCAR | head -1 | awk '{print $2}')
ion_3=$(grep -B 1 Direct POSCAR | head -1 | awk '{print $3}')
ion_4=$(grep -B 1 Direct POSCAR | head -1 | awk '{print $4}')
if [ "$element_num" = "1" ];then
 ion=${ion_1}
elif [ "$element_num" = "2" ];then
 ion=$(echo "${ion_1}+${ion_2}"|bc)
elif [ "$element_num" = "3" ];then
 ion=$(echo "${ion_1}+${ion_2}+${ion_3}"|bc)
elif [ "$element_num" = "4" ];then
 ion=$(echo "${ion_1}+${ion_2}+${ion_3}+${ion_4}"|bc)
else
 echo "The No. of chemical elements is wrong."
fi

echo $ion > ion.dat
element=$(grep -B 2 Direct POSCAR | head -1)
## basis vestor of unite cell ##
A_1=$(grep -B 5 Direct POSCAR | head -1 | tail -1)
A_2=$(grep -B 5 Direct POSCAR | head -2 | tail -1)
A_3=$(grep -B 5 Direct POSCAR | head -3 | tail -1)
## basis vestor of unite cell ##

## create alm.in with MODE=suggest, the structure information is from the above POSCAR ##
cat > alm.in << eof
&general
  PREFIX = uc
  MODE = suggest
  NAT = ${ion}; NKD = ${element_num}
  KD = ${element}
  PERIODIC = 1 1 1
/
&interaction
  NORDER = 1  # 1: harmonic, 2: cubic, ..
/
&cutoff
  *-* None
/
&cell
  1.8897261254578282 # factor in Bohr unit
  ${A_1}
  ${A_2}
  ${A_3}
/
&position
eof
if [ "$element_num" = "1" ];then
 grep -A ${ion_1} "Direct" POSCAR | tail -${ion_1} |awk -v val=$j '{print val, 1, $1,$2,$3}' > posi.in
elif [ "$element_num" = "2" ];then
 grep -A ${ion_1} "Direct" POSCAR | tail -${ion_1} |awk -v val=$j '{print val, 1, $1,$2,$3}' > posi.in
 grep -A $(echo "${ion_1}+${ion_2}"|bc) "Direct" POSCAR | tail -${ion_2} |awk -v val=$j '{print val, 2, $1,$2,$3}' >> posi.in
elif [ "$element_num" = "3" ];then
 grep -A ${ion_1} "Direct" POSCAR | tail -${ion_1} |awk -v val=$j '{print val, 1, $1,$2,$3}' > posi.in
 grep -A $(echo "${ion_1}+${ion_2}"|bc) "Direct" POSCAR | tail -${ion_2} |awk -v val=$j '{print val, 2, $1,$2,$3}' >> posi.in
 grep -A $(echo "${ion_1}+${ion_2}+${ion_3}"|bc) "Direct" POSCAR | tail -${ion_3} |awk -v val=$j '{print val, 3, $1,$2,$3}' >> posi.in
elif [ "$element_num" = "4" ];then
 grep -A ${ion_1} "Direct" POSCAR | tail -${ion_1} |awk -v val=$j '{print val, 1, $1,$2,$3}' > posi.in
 grep -A $(echo "${ion_1}+${ion_2}"|bc) "Direct" POSCAR | tail -${ion_2} |awk -v val=$j '{print val, 2, $1,$2,$3}' >> posi.in
 grep -A $(echo "${ion_1}+${ion_2}+${ion_3}"|bc) "Direct" POSCAR | tail -${ion_3} |awk -v val=$j '{print val, 3, $1,$2,$3}' >> posi.in
 grep -A $(echo "${ion_1}+${ion_2}+${ion_3}+${ion_4}"|bc) "Direct" POSCAR | tail -${ion_4} |awk -v val=$j '{print val, 4, $1,$2,$3}' >> posi.in
else
echo "The No. of chemical elements is wrong."
fi
echo "/" >> posi.in
cat posi.in >> alm.in
#${alm} alm.in > alm1.log
alm alm.in > alm1.log

## create structures including displacement, the PREFIX is uc ##
#python ~/apps/alamode/alamode-v.1.1.0/tools/displace.py --VASP=POSCAR --mag=0.01 --prefix 2nd uc.pattern_HARMONIC
python3 ~/software/alamode/alamode-1.1.0/tools/displace.py --VASP=POSCAR --mag=0.01 --prefix 2nd uc.pattern_HARMONIC

## confirm the No. of 2nd structures ##
find ./ -name "2nd*" -print > filename
num=$(awk 'END{print NR}' filename)

## do 2nd structures ##
for i in $(seq -f %01g 1 $num)
do 
mkdir 2nd-$i
mv 2nd${i}.POSCAR 2nd-$i/POSCAR
cd ./2nd-$i
cat > INCAR << eof
sYSTEM=Br3CdCs  #???????????????????????????
ISTART=0
ICHARG=2
ENCUT=650

ISMEAR=0
SIGMA=0.01
EDIFF=1E-8
NELMIN=5
IBRION=-1
#ISPIN=2
PREC=Accurate

GGA=PS
IALGO=38
LREAL=.FALSE.
LWAVE=.FALSE.
LCHARG=.FALSE.
ADDGRID=.TRUE.
NPAR=4
#SYMPREC=0.001
NELM=100
eof
cat > KPOINTS << eof
A
0
G
2 2 2
0 0 0
eof
#vasppot_paw61_pbe.sh Li_sv H
${vasppot} Br Cd  Cs_sv  #  !?????????????????????????????????
srun vasp_std > scf.out
cd ..
done

## create the disp-force2 ###
#python ~/apps/alamode/alamode-v.1.1.0/tools/extract.py --VASP=POSCAR 2nd-*/vasprun.xml > disp-force2.dat
python3 ~/software/alamode/alamode-1.1.0/tools/extract.py --VASP=POSCAR 2nd-*/vasprun.xml > disp-force2.dat

## create alm.in with MODE=optimize and NORDER=1 ##
cat > alm.in << eof
&general
  PREFIX = uc       
  MODE = optimize        
  NAT = ${ion}; NKD = ${element_num}
  KD = ${element}
  PERIODIC = 1 1 1
/
&interaction
  NORDER = 1          # 1: harmonic, 2: cubic, ..
/
&optimize
  LMODEL= least-squares
  NDATA = $num
  DFSET = disp-force2.dat
/
&cutoff
  *-* None
/
&cell
  1.8897261254578282 # factor in Bohr unit
  ${A_1}
  ${A_2}
  ${A_3}
/
&position
eof
cat posi.in >> alm.in
alm alm.in > alm2.log
mv uc.fcs uc_2nd.fcs  
mv uc.xml uc_2nd.xml  

#rm -rf 2nd-*
