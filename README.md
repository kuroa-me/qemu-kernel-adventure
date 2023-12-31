# qemu-kernel-adventure

## Building

### Build custom kernel

Be sure to change some critical configs, diff file is included and to be cleaned.

Refs:
- https://www.josehu.com/memo/2021/01/02/linux-kernel-build-debug.html
- https://akhileshmoghe.github.io/_post/linux/debian_minimal_rootfs
- https://unix.stackexchange.com/questions/631343/kernel-i-built-from-debian-sources-doesnt-see-qemu-dev-vda-despite-same-setup
- https://unix.stackexchange.com/questions/414655/not-syncing-vfs-unable-to-mount-root-fs-on-unknown-block0-0

```bash
make -j 4
```

### Build RootFS

We are using `multistrap` here for we having a internal debian package mirror.

Be aware `multistrap` have a bug that prevents `noauth` from functioning normally, apply the [patch](multistrap-noauth.patch) created by Lisandro Damián Nicanor Pérez Meyer.

Refs:
- https://unix.stackexchange.com/questions/559014/what-exactly-does-the-noauth-property-mean-in-multistrap-config

The following command creates a directory that holds the rootfs.

```bash
sudo ./multistrap -f rootfs.conf
```

Copy some files from the host to the guest

```bash
cp /etc/zsh/zshrc rootfs/etc/zsh/
cp /etc/resolv.conf rootfs/etc/
```

Next `chroot` into the rootfs and do some configurations.

```bash
sudo chroot rootfs/
# Use systemd as init
ln -s /lib/systemd/systemd /sbin/init
# Enable ttyS0
ln -sf /lib/systemd/system/getty@.service /etc/systemd/system/getty.target.wants/getty@ttyS0.service
# Disable tty1, may not be necessary
rm /etc/systemd/system/getty.target.wants/getty@tty1.service
# Use systemd-networkd as our network daemon
systemctl enable systemd-networkd
# Install openssh-server
apt install openssh-server
# change to zsh
chsh /bin/zsh
```

While still in `chroot` environment, configure both networkd and sshd:
> Create a file at `/etc/systemd/network/20-qemu.network` with the following content [20-qemu.network](20-qemu.network)
> PermitRootLogin for sshd

#### The raw image way

Exit `chroot` and use the `pack-rootfs.sh` to pack it into a raw disk image in ext4 format.

```bash
sudo ./pack-rootfs.sh
```

Refs:
- https://github.com/kata-containers/kata-containers/pull/4987/files
- https://eaasi.gitlab.io/program_docs/qemu-qed/usage/create_raw_disk_image/

#### The 9P way

When using 9P, there is no need to make a image from the directory, it will use the host directory directly.

Refs:
- https://wiki.qemu.org/Documentation/9p_root_fs
- https://wiki.qemu.org/Documentation/9psetup
- https://qemu-devel.nongnu.narkive.com/EyP5Ftyi/9p-as-rootfs


## Running

Start

#### The raw image way

```bash
sudo qemu-system-x86_64 -kernel kernel/arch/x86_64/boot/bzImage -nographic -drive format=raw,file=multistrap/rootfs.ext4,if=virtio -append "root=/dev/vda rw console=ttyS0 nokaslr" -m 4G -enable-kvm -cpu host -smp $(nproc) -net nic,model=virtio -net user,hostfwd=tcp::10022-:22 -s
```

#### The 9P way

```bash
sudo qemu-system-x86_64 \
-kernel kernel/arch/x86_64/boot/bzImage \
-append 'root=/dev/root rw rootfstype=9p rootflags=trans=virtio,version=9p2000.L,msize=5000000,cache=mmap,posixacl console=ttyS0 nokaslr' \
-fsdev local,security_model=passthrough,multidevs=remap,id=fsdev-fsRoot,path=multistrap/rootfsbear \
-device virtio-9p-pci,id=fsRoot,fsdev=fsdev-fsRoot,mount_tag=/dev/root \
-net nic,model=virtio -net user,hostfwd=tcp::10022-:22 \
-machine pc,accel=kvm,usb=off,dump-guest-core=off -m 2048 \
-smp 4,sockets=4,cores=1,threads=1 \
-nographic -s
```

TODO: The terminal is messed up for some reason, help me...

Connect

```bash
ssh -p 10022 root@localhost
```