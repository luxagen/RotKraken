# RotKraken

## What is it?

RotKraken (RK) is a long-term defence against [bit rot](http://en.wikipedia.org/wiki/Data_corruption). It associates persistent [hashes](http://en.wikipedia.org/wiki/Hash_function) with files via [extended attributes](http://en.wikipedia.org/wiki/Extended_file_attributes), along with enough information to find a good copy in your backups. This allows detection of both acute and gradual data corruption across many types of storage and backup, even as technology evolves over the decades. I developed it because I'd tired of the flaws in my previous system: comparing [md5deep](http://en.wikipedia.org/wiki/Md5deep) logs. Over the two years since I wrote it, it's alerted me to countless bit-flips (both during data copying and at rest over time) in the various online-storage systems I administer, and I also habitually write RK metadata with tapes for backup and offline storage.

## What does RK track?
Extended attributes can only be associated with regular files and directories. RK uses them only on regular files, and silently ignores every other type (e.g. named pipes and device nodes). RK does not traverse symbolic links by design in order to avoid both infinite loops and multiple iteration of the same parts of a filesystem.

## Where can I use it?

### Linux / NAS / macOS

RotKraken can be used on all major Linux-supported filesystems that support extended attributes, including [NTFS](http://en.wikipedia.org/wiki/NTFS) via [NTFS-3G](http://en.wikipedia.org/wiki/NTFS-3G). Since most Linux-based NASes tend to support Perl, it should also work there. RK also works on macOS, whether HFS+ or APFS, although it has been known in the past to emit some spurious `stat`-related messages.

### Windows

Windows isn't yet supported.

Although it seems that [Windows now supports extended attributes via NTFS](http://milestone-of-se.nesuke.com/en/sv-basic/windows-basic/ntfs-filesystem-structure), Cygwin doesn't. While it's likely that the [Windows Subsystem for Linux](http://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux) and/or one of its ancestors might be suitable for RK under Windows, I haven't investigated them because I use Linux and Cygwin.

## License

RotKraken is released under a "[GPL3](http://www.gnu.org/licenses/gpl-3.0.en.html) or later" licence and, despite my best efforts to make it obviously defect-free, comes with absolutely no warranty whatsoever, express or implied; use it at your own risk. If you find bugs, please either report them to me so I can fast-track a fix or submit a pull request with a fix of your own. I can be reached at rotkraken@luxagen.com for bug reports, suggestions, and abuse (but not all three at once). 

## Installation

1. Install Perl.
2. Clone or download this repository.
3. Install the dependencies:

	Ubuntu:
	```
	sudo apt install libdatetime-perl libfile-extattr-perl libgetopt-lucid-perl # RK itself
	sudo apt install libtest-more-utf8-perl libipc-run3-perl                    # Tests
	```
	CPAN:
	```
	cpan -I DateTime File::ExtAttr Digest::MD5::File Getopt::Lucid # RK itself
	cpan -I Test::More IPC::Run3                                   # Tests
	```

4. Although not strictly necessary, running the tests is generally a good starting point, especially on unusual platforms. Invoking `run-tests` will do this using a temporary subdirectory of the current working directory

### Add to PATH (optional)

To facilitate addition to your `$PATH`, a `bin/` directory is provided with both a convenience symlink and Bash scripts (`rkdiff` and `rkdiff-stdin`) for instantly comparing filesystem trees and/or hash logs.

## How to use

All commands currently take the following form:

```
rk <options...> <paths...>
```

...where `<paths...>` is a list of files and/or directories to be recursed. Shell globbing is supported and there must be at least one path. Invoking RK without any options will do nothing but print per-file status.

### Status versus logging

RK's has two output modes: the default prints one line per file of the form:

```<status> <path>```

...where ```<status>``` is one of the following:

|   char  | meaning                               |
| ------: | :------                               |
| <space> | No metadata or just removed           |
|       N | Just hashed, metadata added           |
|       ? | Previously hashed but never verified  |
|       V | Last verify passed, vtime updated     |
|       X | Last verify failed, vtime not updated |

When invoked with the `-e` option, RK instead prints one line per file in `md5deep -zl` format. This is useful to instantly compare two trees for identicality or spot changes (see `rkdiff` and `rkdiff-stdin`) and is completely orthogonal to RK's other commands. For example, you can use `rk -iue` to update a tree's metadata and print an up-to-date hash log in one pass.

NB: `-e` will fill the hash field with question marks (?) for uninitialised files and 'S' for stale ones.

### Commands
RK has four main commands, which, except for *clear*, can be combined with each other. For example, use `rk -iu` to both initialise new files and update stale ones so that everything has up-to-date metadata. `rk -iuv` will even verify non-new, non-stale files in the same run in case it's useful.

#### Initialise
`rk -i` creates metadata for each file that doesn't already have it.

#### Update
A file is stale when its modification timestamp is newer than its `rk -i` metadata, and is likely to have different content. `rk -u` updates the `rk -i` metadata for those files.

#### Verify
`rk -v` checks the content of each initialised, non-stale file against its stored `rk -i` metadata by rehashing; successful verification will update the files' verification timestamps, but mismatches won't &mdash; this is so that a future version can print a timespan within which backups will contain a known-good copy of the file.

#### Clear
`rk -x` will unconditionally remove metadata from files. There's rarely a good reason to do this, and it will break the "integrity chain" on the files.

### Directive files

You can exclude certain subtrees from RK's recursion or logging using marker files with the names ```.rk.skip``` and ```rk.quiet```. A marker file can be either empty (in which case the directive will apply to its entire parent directory) or a list of concrete file/subdirectory names (siblings) to which the directive applies.

Artful use of empty directive files inside a directory versus a non-empty one outside the same directory will still allow you to manually verify certain data when needed. For instance, naming your ```.snapshots``` directory in a volume's ```/.rk.skip``` file doesn't stop you from entering ```.snapshots``` and issuing `rk -vQ` commands to verify the datasets.

#### Exclude
Files with the name ```.rk.skip``` limit RK's recursion, i.e. will prevent it from touching certain subtrees. This allows it to be used on the root filesystem of a Linux install without deadlocking by trying to hash (for example) ```/dev/urandom```. In those scenarios, any snapshots and subvolume mounts should be also excluded for efficiency.

#### Hide
Files with the name ```.rk.quiet``` do not affect RK's recursion but prevent it from printing status or hash-log lines for certain subtrees. This can be useful for including sensitive files in RK's integrity tracking without revealing their presence. To verify those files, use unquiet mode (below).

### (un)quiet mode
The `-q` option will suppress all status/log output from RK. See below (`.rk.quiet`) for the ability to selectively suppress. `-Q` generates output even for files covered by ```.rk.quiet``` directive files.

## Example workflows

### Securely copying large datasets

Note: make sure you copy extended attributes (see below)!

The standard workflow is to run `rk -i` on the original tree (let's call it **$SRC**) before copying, and then verify the results by running `rk -v` on the new tree (**$DST**).

You can also copy the data first; once it's done, either `rk -i $SRC` and `rsync -X $SRC/ $DST/` to copy the metadata, or `rk -i $SRC` and `rk -i $DST` in parallel. Finally `rkdiff $SRC $DST` to verify the copy.

If you've initial-hashed **$DST** via `rk -i` but don't want to let `rk` touch your source tree, you can use `rk -e` to generate a log in `md5deep -zl` format:

```
(cd "$SRC" && md5deep -rzlj0 .) | rkdiff-stdin "$DST"
```

### Disk-to-disk backups

My standard workflow is:
1. Update the backup with `rsync --progress --partial --delete-before -aHAi $MAIN/ $BAK/`.
2. Run `rk -i $MAIN` and `rk -i $BAK` in parallel.
3. Run `rkdiff $MAIN $BAK` to integrity-check the newly-copied data.

This method avoids reverifying the untouched stuff, but you probably want to fully reverify all of your copies once in a while too.

## Caveats, rationales and warnings

**DANGER WILL ROBINSON**: `cp`, `mv`, `rsync`, and `tar` are all capable of preserving extended attributes but won't necessarily do it by default! Double-check your command-line options and run as `root` to be sure you're not throwing anything away in transit; `-a` can be useful for maximising preservation.

Since it works on a per-file basis, RotKraken won't detect wholesale loss of a file. I therefore recommend separately keeping either export logs from `rke $DIR` or listings from `find $DIR -not -type -d` somewhere (e.g. a git repository) to catch events like this.

I chose [MD5](http://en.wikipedia.org/wiki/MD5) because speed is important; I don't consider malicious replacement of files with bogus variants by bad actors a real problem in my use case, so a true cryptographic hash would be overkill. I named the hash attribute `md5` so that extra signatures from other hash functions can be added later, but I haven't worked out the best logic for handling multiple signatures; ideas welcome.

No facility yet exists to print the known-good timespan for corrupt files.