# RotKraken

## What is it?

RotKraken is a long-term defence against [bit rot](http://en.wikipedia.org/wiki/Data_corruption). It associates persistent [hashes](http://en.wikipedia.org/wiki/Hash_function) with files via [extended attributes](http://en.wikipedia.org/wiki/Extended_file_attributes), along with enough information to find an uncorrupted copy. This allows detection of data corruption across many types of storage and backup, even as technology evolves over many years.

## Where can I use it?

### Linux / NAS

RotKraken can be used on all major Linux-supported filesystems that support extended attributes, including [NTFS](http://en.wikipedia.org/wiki/NTFS) via [NTFS-3G](http://en.wikipedia.org/wiki/NTFS-3G). Since most Linux-based NASes tend to support Perl, it should also work there.

### macOS

RotKraken has been tested on HFS+ and should work on macOS in general, with the caveat that it emits some spurious `stat`-related messages (fix on the roadmap).

### Windows

Windows isn't yet supported.

Although it seems that [Windows now supports extended attributes via NTFS](http://milestone-of-se.nesuke.com/en/sv-basic/windows-basic/ntfs-filesystem-structure), Cygwin doesn't. While it's likely that the [Windows Subsystem for Linux](http://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux) and/or one of its ancestors might be suitable for RotKraken under Windows, I haven't investigated them because I use Linux and Cygwin.

## License

RotKraken is released under a "[GPL3](http://www.gnu.org/licenses/gpl-3.0.en.html) or later" licence and, despite my best efforts to make it obviously defect-free, comes with absolutely no warranty whatsoever, express or implied; use it at your own risk. If you find bugs, please either report them to me so I can fast-track a fix or submit a pull request with a fix of your own. I can be reached at rotkraken@luxagen.com for bug reports, suggestions, and abuse (but not all three at once). 

## Installation

1. Clone or download this repository.
2. Install the dependencies:

	Ubuntu:
	```
	sudo apt install libdatetime-perl libfile-extattr-perl libdigest-md5-file-perl libgetopt-lucid-perl
	```
	CPAN:
	```
	cpan -I DateTime File::ExtAttr Digest::MD5::File Getopt::Lucid
	```

### Add to PATH (optional)

To facilitate addition to your `$PATH`, a `bin/` directory is provided with both a convenience symlink and a two-parameter Bash script (`rkdiff`) for comparing pre-initialised filesystem trees.

## Usage

All commands currently take the following form:

```
rk -<single-option> <items...>
```

...where `<items...>` is a list of files and/or directories to be recursed. Shell globbing is supported. There must be exactly one option and at least one item.

### First-time hashing

To do an initial hashing run, use `rk -i`. This will place a timestamp and content hash in the extended attributes of each (accessible) regular file while printing a status line. Previously-hashed files will not be affected and their existing status printed instead.

### Verification

To verify items against their stored metadata, use `rk -v`. This will rehash each initialised file and compare the result with the stored hash to derive a new status value. Uninitialised files will not be read but will still print a status line.

Matched files will have their verification timestamps updated but mismatches won't &mdash; this is so that, in future, mismatches can be printed with a timespan within which any backup will contain a known-good copy of the file.

### Status

To see the status of files without doing anything to them (i.e. neither -i nor -v), use `rk -s`.

### Skipping subtrees
The presence of an ```.rk.skip``` file will make RK skip this directory and all descendants.

### Securely copying large datasets

Note: make sure you copy extended attributes (see below)!

The standard workflow is to run `rk -i` on the original tree (let's call it **$SRC**) before copying, and then verify the results by running `rk -v` on the new tree (**$DST**). If you've already copied the data, you can instead run `rk -i` on both **$SRC** and **$DST** and then verify the copy using `rk -e`.

If you've initial-hashed **$DST** via `rk -i` but don't want to let `rk` touch your source tree, you can use `rk -e` to generate a log in `md5deep -zl` format:

```
diff <(sort <(cd "$SRC" && md5deep -rzlj0 .)) <(sort <(cd "$DST" && rk -e .))
```

### Disk-to-disk backups

My standard workflow is:
1. Update the backup with `rsync --progress --partial --delete-before -aHAi $MAIN/ $BAK/`.
2. Run `rk -i $MAIN` and `rk -i $BAK` in parallel.
3. Run `rkdiff $MAIN $BAK` to integrity-check the newly-copied data.

This method avoids reverifying the untouched stuff, but you probably want to fully reverify all of your copies once in a while too.

### Mode options

| option | meaning                                                       |
| -----: | :------------------------------------------------------------ |
|     -x | Clear metadata from extended attributes                       |
|     -e | Export hash log to stdout in the same format as `md5deep -zl` |
|     -i | Initialise files that are missing metadata                    |
|     -v | Verify initialised files against metadata                     |
|     -a | Combination of -i & -v                                        |
|     -s | Show status; no action                                        |

### Status characters

|   char  | meaning                               |
| ------: | :------                               |
| <space> | No metadata or just removed           |
|       N | Just hashed, metadata added           |
|       ? | Previously hashed but never verified  |
|       V | Last verify passed, vtime updated     |
|       X | Last verify failed, vtime not updated |

## Caveats, rationales and warnings

**DANGER WILL ROBINSON**: `cp`, `mv`, `rsync`, and `tar` are all capable of preserving extended attributes but won't necessarily do it by default! Double-check your command-line options and run as `root` to be sure you're not throwing anything away in transit; `-a` can be useful for maximising preservation.

Since it works on a per-file basis, RotKraken won't detect wholesale loss of a file. I therefore recommend separately keeping either export logs from `rk -e $DIR` or listings from `find $DIR -not -type -d` somewhere (e.g. a git repository) to catch events like this.

I chose [MD5](http://en.wikipedia.org/wiki/MD5) because speed is important; I don't consider malicious replacement of files with bogus variants by bad actors a real problem in my use case, so a true cryptographic hash would be overkill. I named the hash attribute `md5` so that extra signatures from other hash functions can be added later, but I haven't worked out any logic for handling multiple signatures.

Since extended attributes only work on regular files, other filesystem entities like named pipes and device nodes (everything but regular files and directories) are silently ignored.

I haven't yet written tests for return-code behaviour, so please consider terminal output the final word on results; `grep -v` and `sort`+`diff` are your friends.

Although there's no command-line option to disable directory recursion, the code contains an internal switch `$no_recurse` for later implementation. While the code supports symlink traversal, it's currently disabled via the internal switches `$no_follow_file_symlinks` and `$no_follow_dir_symlinks`. In both cases, the main blockers to full implementation are improving the option-parsing code and writing tests; for now, `find` is a good workaround.

Because I wanted to get the happy path working robustly first, no facility exists to print the known-good timespan for corrupt files; this is on the roadmap.

Files that change legitimately over time (e.g. logs and backups) are not yet well supported; you can either be more selective in which parts of your filesystem you run `rk -i` on in the first place, or use `rk -x; rk -i` to work around it. **DANGER WILL ROBINSON**: if you use this combination indiscriminately, yer gonna have a bad time &mdash; used on unchanged files, it will both break the "chain of custody" on the data and destroy the timestamps required to locate good backups.

Ultimately, better support for selective hashing/verification and files that change will likely involve implementing `--older-vtime` and `--newer-vtime` features; I haven't yet worked out what they'll do with files missing vtime stamps, and it's possible a `--new-only` option might be useful.

## Test scripts

A Bash test script is provided that runs the tests against the ext2, ext3, ext4, and btrfs filesystems on Linux; I would have liked to include more (e.g. XFS and ZFS), but their nonstandard `mkfs` commands dissuaded me.

### Additional dependencies for tests

Ubuntu:
```
sudo apt install libtest-more-utf8-perl libipc-run-perl
```
CPAN:
```
cpan -I Test::More IPC::Run
```

## Background

I developed RotKraken because I'd tired of the flaws in my previous system: comparing [md5deep](http://en.wikipedia.org/wiki/Md5deep) logs. [APL](mailto:andrew@landells.net) helped me with initial prototyping while I did technical feasibility testing on extended attributes.
