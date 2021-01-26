# RotKraken

## Introduction
RotKraken is designed as a long-term defence against [bit rot](http://en.wikipedia.org/wiki/Data_corruption). It uses [extended attributes](http://en.wikipedia.org/wiki/Extended_file_attributes) &mdash; available on all major Linux-supported filesystems including [NTFS](http://en.wikipedia.org/wiki/NTFS) via [NTFS-3G](http://en.wikipedia.org/wiki/NTFS-3G) &mdash; to store content hashes against files so that unwanted changes can later be detected. The stored metadata provides enough information to locate a relevant backup for recovery.

I developed RotKraken because I'd tired of the flaws in my previous system: comparing [md5deep](http://en.wikipedia.org/wiki/Md5deep) logs. [APL](mailto:andrew@landells.net) helped me with initial prototyping while I did technical feasibility testing on extended attributes.

RotKraken is written in Perl and depends on the ```DateTime``` (Ubuntu: ```libdatetime-perl```), ```File::ExtAttr``` (Ubuntu: ```libfile-extattr-perl```), and ```Digest::MD5::File``` (Ubuntu: ```libdigest-md5-file-perl```) modules. As such, I believe it should work on most Linux-based NASes. The tests are also written in Perl and depend on the ```File::ExtAttr``` (Ubuntu: ```libfile-extattr-perl```), ```Test::More``` (Ubuntu: ```libtest-most-perl```), ```IPC::Run``` (Ubuntu: ```libipc-run-perl```), and ```File::Path``` (Ubuntu: ```perl```) modules. A Bash test script is provided that runs the tests against the ext2, ext3, ext4, and btrfs filesystems on Linux; I would have liked to include more (e.g. XFS and ZFS), but their nonstandard ```mkfs``` commands dissuaded me.

To facilitate addition to your ```$PATH```, a ```bin/``` directory is provided with a convenience symlink.

RotKraken is released under a "[GPL3](http://www.gnu.org/licenses/gpl-3.0.en.html) or later" licence and, despite my best efforts to make it obviously defect-free, comes with absolutely no warranty whatsoever, express or implied; use it at your own risk. If you find bugs, please either report them to me so I can fast-track a fix or submit a pull request with a fix of your own. I can be reached at rotkraken@luxagen.com for bug reports, suggestions, and abuse (but not all three at once).

## Usage
All commands currently take the following form:

```rk -<single-option> <items...>```

...where ```<items...>``` is a list of files and/or directories to be recursed. Shell globbing is supported.

## Scenarios

### First-time hashing

To do an initial hashing run, use ```rk -i```. This will place a timestamp and content hash in the extended attributes of each (accessible) regular file while printing a status line. Previously hashed files will not be affected and their existing status printed instead.

### Verification
To verify items against the stored metadata, use ```rk -v```. For every previously hashed file, this will rehash its content and compare with the stored hash to derive a new status value. Unhashed files will not be read but will have a status line in the output.

Matched files will have their verification timestamps updated but mismatches won't &mdash; this is so that, in future, mismatches can be printed with a timespan within which any backup will contain a known-good copy of the file.

### Securely copying large datasets
Note: make sure you copy extended attributes (see below)!

The standard workflow is to run ```rk -i``` on the original tree (let's call it **$SRC**) before copying, and then verify the results by running ```rk -v``` on the new tree (**$DST**). If you've already copied the data, you can instead run ```rk -i``` on both **$SRC** and **$DST** and then verify the copy using ```rk -e```.

If you've initial-hashed **$DST** via ```rk -i``` but don't want to let ```rk``` touch your source tree, you can use ```rk -e``` to generate a log in ```md5deep -zl``` format:

```diff <(sort <(cd "$SRC" && md5deep -rzlj0 .)) <(sort <(cd "$DST" && rk -e .))```

## Modes
| option | meaning                                                       |
| -----: | :------------------------------------------------------------ |
|     -x | Clear own metadata from extended attributes                   |
|     -e | Export hash log to stdout in the same format as ````md5deep -zl```` |
|     -i | Initialise files that are missing metadata                    |
|     -v | Verify files with metadata                                    |
|     -a | Combination of -i & -v                                        |

## Status characters

|   char  | meaning                                   |
| ------: | :------                                   |
| <space> | No metadata or just removed               |
|       N | Just hashed, metadata added               |
|       ? | Previously hashed but never verified      |
|       V | Last verify passed, timestamp updated     |
|       X | Last verify failed, timestamp not updated |

## Caveats & rationales
Mac OS isn't yet supported, but I've established feasibility and it's on the roadmap. Although it seems that [Windows now supports extended attributes via NTFS](http://milestone-of-se.nesuke.com/en/sv-basic/windows-basic/ntfs-filesystem-structure), Cygwin doesn't, so it's currently unsupported. While it's likely that the [Windows Subsystem for Linux](http://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux) and/or one of its ancestors might be suitable for RotKraken under Windows, I haven't investigated any of them because I use Linux and Cygwin.

**DANGER WILL ROBINSON**: ```cp```, ```mv```, ```rsync```, and ```tar``` are all capable of preserving extended attributes but won't necessarily do it by default! Double-check your command-line options and run as ```root``` to be sure you're not throwing anything away in transit; ```-a``` can be useful for maximising preservation.

I chose [MD5](http://en.wikipedia.org/wiki/MD5) because I value speed; I don't consider malicious replacement of files with bogus variants by bad actors a real problem in my use case, so a true cryptographic hash would be overkill. I named the hash attribute `md5` so that extra signatures from other hash functions can be added later, but I haven't worked out the logic for handling multiple signatures.

Since extended attributes only work on regular files, other filesystem entities like named pipes and device nodes (everything but regular files and directories) are silently ignored.

I haven't yet written tests for return-code behaviour, so please consider terminal output the final word on results; ```grep -v``` and ```sort```+```diff``` are your friends.

Although there's no command-line option to disable directory recursion, the code contains an internal switch ```$no_recurse``` for later implementation. Symbolic links are not followed, but the code contains internal switches ```$no_follow_file_symlinks``` and ```$no_follow_dir_symlinks```. In both cases, the main blockers to full implementation are improving the option-parsing code and writing tests; for now, ```find``` is your friend.

Because I wanted to get the happy path working robustly first, no facility exists to print the known-good timespan for corrupt files, or print status without either initial-hashing or verifying; both features are on the roadmap.

Files that change legitimately (e.g. logs and backups) are not yet well supported; you can either be more selective in which parts of your filesystem you run ```rk -i``` on in the first place, or use ```rk -x; rk -i``` to work around it. **DANGER WILL ROBINSON**: if you use this combination indiscriminately, yer gonna have a bad time &mdash; used on unchanged files, it will both break the "chain of custody" on the data and destroy the timestamps required to locate good backups.