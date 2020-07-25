# mkdogeroot, create a chrooted & namespaced root environment

`mkdogeroot` is a script that prepares a system to provide pseudo-root access to a user.

## Usage

```sh
$ sudo mkdogeroot.sh -u test -b /home/chrootbin -c /mnt data
```

Where:

* `-u test` is the user authorized to become root
* `-b /home/chrootbin` is the path to `sudo` scripts to become `root`
* `-c /mnt` is the directory where to `chroot`
* `data` is an additional mointpoint, it will be mounted as `/data` on the `chroot`

The user will have to launch the following command to enter pseudo-`root` mode:

```sh
$ sudo /home/chrootbin/broot
#
```

## Logic

`mkdogeroot.sh` will create 3 scripts:

* `/home/chrootbin/broot` is the command the user will type to "become root", it uses `unshare` to hide the real filesystem to the `chroot`
* `/home/chrootbin/mkchroot` is the `chroot` creation, invoked by `broot`, it creates the fake filesystem if it does not exist yet and mounts necessary mountpoints
* `/home/chrootbin/rmroot` must be called when the user doesn\'t need root anymore

`mkdogeroot.sh` adds a line to `/etc/sudoers`, for example:

```ini
test  ALL=(ALL) NOPASSWD: /home/chrootbin/mkchroot, /home/chrootbin/broot
``` 
Allowing the user `test` to run `/home/chrootbin/broot`

Regular system directories (`bin boot sbin lib lib64 media mnt opt sbin srv usr var`) are mounted read only.  
Dynamic directories (`proc sys dev run`) are mounted read / write.  
Additional directories (`data`) are mounted read / write.

## Additional settings

In order to see all processes inside the chroot when [grsecurity](https://grsecurity.net/) is enabled, a `grsec` feature must be disabled:

```sh
$ sudo sysctl -w kernel.grsecurity.chroot_findtask=0
```

## Example

* Copy `mkdogeroot.sh` to the target machine

```sh
$ scp mkdogeroot.sh customer633:
```

* Deploy the scripts

```sh
$ sudo ./mkdogeroot.sh -u www -b /home/chrootbin -c /mnt data
```

* Test

```sh
$ sudo su - www
$ sudo /home/chrootbin/broot
# ps axuww
```

* Check that you can see all the processes
* Optionally remove `mkdogeroot`

```sh
$ rm mkdogeroot.sh
```

## Removal

`rmroot` umounts remaining mount points if any, removes them, and delete the
user `broot` command from `/etc/sudoers`.

## Greets and sources

* _gab_ on _#gcu_
* https://blog.w1r3.net/2018/01/13/containers-with-shell-and-unshare.html
* https://wiki.archlinux.org/index.php/Chroot#Using_chroot
