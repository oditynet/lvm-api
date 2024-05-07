#!/bin/bash
n1=""
s1=""
p1=""
d1=""

get_list_pvs()
{
#   PV         VG       Fmt  Attr PSize   PFree
# /dev/sdb3  lvm-root lvm2 a--  <15.00g    0
# /dev/sdb4  var_root lvm2 a--   <3.00g    0
	_pvs=$(pvs|grep lvm2|awk '{print $2}')
}
get_list_pvs_disks()
{
	_pvs=$(pvs|grep lvm2|awk '{print $1}')
}
get_disk_at_vg()
{
        _vgdisk=$(pvs|awk '$2 == "'$1'" { print $1 }') 
}
get_list_vgs()
{  

#  VG       #PV #LV #SN Attr   VSize   VFree
#  lvm-root   1   2   0 wz--n- <15.00g    0 
#  var_root   1   1   0 wz--n-  <3.00g    0 	
	_vgs_count=$(vgs|wc -l)
	#echo "vgs count = $((_vgs_count -1 ))"
	if (( $((_vgs_count - 1)) > 1));then
		_vgs=$(vgs|tail -$((_vgs_count - 1 ))|awk '{print $1}')
	fi
}

get_list_lvs()
{
#  LV   VG       Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
#  root lvm-root -wi-a----- 13.00g                                                    
#  swap lvm-root -wi-a----- <2.00g                                                    
#  var  var_root -wi-a----- <3.00g      
	get_list_vgs
	vgs=$_vgs
	_lvs=""
	n1=""
	s1=""
	p1=""

	for i in $(echo $vgs);do
	   tmp=""
	   tmp=$(lvs|awk '$2 == "'$i'" { print $1 }') 
	   t1=$(lvs|awk '$2 == "'$i'" { print $2 }')
	   for t in $(echo $t1);do
	      n1+=$t"|"
	      get_disk_at_vg $t
	      d1+=$_vgdisk"|"

	   done
	   _lvs=$tmp" "$_lvs
	   _size=$(lvs --units m|awk '$2 == "'$i'" { print $NF }' |tr -d '<|m|>'|sed -r 's/^([0-9]{1,}).*/\1/')
           
	   for t in $(echo $_size);do
	     s1+=$t"|"
	   done
	   for t in $(echo $tmp);do
	     p1+=$t"|"
	   done
	done
	n1=$(echo $n1|sed -r 's/(^.*)\|$/\1/')
	s1=$(echo $s1|sed -r 's/(^.*)\|$/\1/')
	p1=$(echo $p1|sed -r 's/(^.*)\|$/\1/')
	d1=$(echo $d1|sed -r 's/(^.*)\|$/\1/')
}
del_lvm_all()
{
  for i in $(seq $(echo $n1|sed -r 's/\|/\n/g'|wc -l));do
    get_value $n1 $((i+1))
    t_vgs=$_val
    get_value $p1 $((i+1))
    t_name=$_val


    echo "Delete $t_name in $t_vgs"
    eval "lvremove -y /dev/$t_vgs/$t_name 2>/dev/null"
    #echo "Error is "$?
  done
}
del_vgs_all()
{
	get_list_vgs
	for i in $(echo $_vgs); do
		echo "[!] Delete Volume group $i"
		eval "vgremove -y  $i 2>/dev/null"
#		echo "Error is $?"
	done
}
del_pvs_all()
{
	get_list_pvs_disks
	for i in $(echo $_pvs);do
		echo "Delete pvs $i"
		eval "pvremove $i -y 2>/dev/null"
		eval "wipefs -af $i"
#		echo "Error is $?"
	done
}
get_value()
{
 val=$1
 ind=$2
 count=$(echo $val|sed -r 's/\|/\n/g'|wc -l)
 _count=$count
 _val=$(echo $val|sed -r 's/\|/\n/g'|tail -$((count-(ind-1)))|head -1)
}
get_list_pvs
echo "PVS     : "$_pvs

get_list_pvs_disks
echo "PVS disk: "$_pvs

get_list_vgs
echo "VGS     : "$_vgs

get_list_lvs
echo "LVS     : "$_lvs

echo "n1="$n1
echo "s1="$s1
echo "p1="$p1
echo "d1="$d1

echo "[*] Delete all part"
del_lvm_all
del_vgs_all
del_pvs_all

#PV
echo "[*] Create PV"
for i in $(seq $(echo $d1|sed -r 's/\|/\n/g'|wc -l));do
  get_value $d1 $((i))
  t_disk=$_val
  echo $t_disk
  eval "pvcreate $t_disk 2>/dev/null "
done

echo "[*] Create VG"
for i in $(seq $(echo $n1|sed -r 's/\|/\n/g'|wc -l));do
  get_value $d1 $((i))
  t_disk=$_val
  get_value $n1 $((i))
  t_name=$_val
  #echo "$vgcreate $t_name $t_disk"
  eval "vgcreate $t_name $t_disk 2>/dev/null"
  eval "vgchange -a y $t_name"
  #echo "vgchange -a y $t_name"
done

echo "[*] Create LV"
for i in $(seq $(echo $p1|sed -r 's/\|/\n/g'|wc -l));do
  get_value $p1 $((i))
  t_part=$_val
  get_value $n1 $((i))
  t_name=$_val
  get_value $s1 $((i))
  t_size=$_val
  #echo "lvcreate -L "$t_size"M -n $t_part $t_name"
  eval "lvcreate -L "$t_size"M -n $t_part $t_name -y"
done
echo "Done"

