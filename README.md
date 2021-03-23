**VDIComp** - compresses the `*.vdi` file of the VirtualBox

Dependencies: `virtualbox`

Before compressing, the VM must be "cleaned up" from the inside:
- For Linux virtual machine, go to the `su/password` terminal and run:  
`dd if=/dev/zero of=/zerofile bs=4096 status=progress; rm -f /zerofile`
- For Windows virtual machines, use `sdelete`
- Turn off the VM and compress it to VDIComp

`VDIComp` immediately creates a VM clone with the original UUID and puts it next to the original one in the `vm_file_name.vdi-Clone.vdi`. Thus, discarding the `-Clone.vdi` we get a compressed, already working clone. The clone disk is also automatically removed from the list of `familiar` media to avoid duplicating the UUID. The cloning method is more reliable than directly compressing the VM disk "into itself" (unplanned power outage, incorrect system shutdown, etc.), since the original does not change. The direct compression mode is saved (the check mark is removed), but cloning is suggested by default.

**Important:** Compression/Clone virtual machine images when VirtualBox is turned OFF. If any VM is running, its process will be forcibly killed. Either we are working with a loaded VM, or we are working with disks. These processes are mutually exclusive, which is absolutely true according to the logic of VirtualBox.

The `VDIComp` startup shortcut is located in the `Menu-Emulators`.

Made and tested in Mageia Linux-7/8.

![](https://github.com/AKotov-dev/vdicomp/blob/main/ScreenShot.png)
