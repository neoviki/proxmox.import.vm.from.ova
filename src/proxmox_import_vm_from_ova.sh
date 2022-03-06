#!/bin/bash

#   Script to import vm on proxmox hypervisor from ova file
#
#
#   Author: Viki (a) Vignesh Natarajan

if [ -z "$1" ]; then
	echo "error: specify the ova file"
	exit 1
fi

OVA_FILE="$1"


function create_temp_dir()
{
	TMP_DIR_INDEX=100
	TMP_DIR="./ova_extract$TMP_DIR_INDEX"
	while [ 1 ]
	do
		TMP_DIR="./ova_extract$TMP_DIR_INDEX"
		if [ -f "$TMP_DIR" ]; then
			echo "DEBUG: temp direcotry ( $TMP_DIR ) already exist"
			TMP_DIR_INDEX=$((TMP_DIR_INDEX+1))	
			continue
		fi
	
		if [ -d "$TMP_DIR" ]; then
			echo "DEBUG: temp direcotry ( $TMP_DIR ) already exist"
			TMP_DIR_INDEX=$((TMP_DIR_INDEX+1))	
			continue
		fi
	
		echo "INFO: creating temp directory $TMP_DIR"
		mkdir -p $TMP_DIR
		break

	done
}


function extract_ova(){
	echo "INFO: Extracting $OVA_FILE"
	tar -xvf "$OVA_FILE" -C $TMP_DIR
	cd "$TMP_DIR"
}

function generate_vm_id(){
	new_vm_id=104
	while [ 1 ]
	do
		qm list --full |  awk '{print $1}' | grep "$new_vm_id" 2>/dev/null 1>/dev/null
	
		if [ $? -ne 0 ]; then
			echo "INFO: New VM is getting created with id : $new_vm_id"
			break
		fi
	
		echo "DEBUG: VM with id [ $new_vm_id ] already exist"
		new_vm_id=$((new_vm_id+1))
	done

}




function create_vm_from_ovf()
{
	qm importovf $new_vm_id *.ovf local-lvm
}

function import_disk(){
	qm importdisk $new_vm_id *disk*1.vmdk local-lvm -format qcow2	
}

function get_new_disk_name()
{
	qm config $new_vm_id | grep disk | grep "vm-$new_vm_id-disk-0" 2>/dev/null 1>/dev/null

	if [ $? -eq 0 ]; then
 		new_disk="vm-$new_vm_id-disk-0"
	fi
}

function config_disk()
{
	qm set $new_vm_id --scsihw virtio-scsi-pci --scsi0 local-lvm:$new_disk
}
function set_boot_disk()
{
	qm set $new_vm_id --boot c --bootdisk scsi0
}

function enable_serial()
{
	qm set $new_vm_id --serial0 socket --vga serial0
}

function enable_gui()
{
	qm set $new_vm_id --vga std
	#qm set $new_vm_id --vga qxl
	#qm set $new_vm_id --vga cirrus
}

function start_vm()
{
	qm start $new_vm_id
}

function cleanup()
{
    cd ..
    rm -rf $TMP_DIR
}

generate_vm_id
create_temp_dir
extract_ova
create_vm_from_ovf
import_disk
get_new_disk_name
config_disk
set_boot_disk
enable_serial
enable_gui
start_vm
cleanup

echo
echo
echo "New VM is created with id : [ $new_vm_id ]"
echo
echo
