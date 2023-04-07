# mole
Implementation of "MOLE - Makes One's Life Easier" text editor wrapper for VUT IOS course. 

## System Requirements
This script should be fully POSIX-complient, although it won't run on systems that don't have `realpath` or `readlink` commmands. Tested on Ubuntu 22.04 using `sh`,  `bash` and on macOS 13 using `sh`, `zsh` with `grealpath` installed.

## Usage
Environment variables `MOLE_RC` with path to the config file and `EDITOR` must be set. Fallback editor is `vi`.

- `mole -h` - Prints help message
- `mole [-g GROUP] FILE` - Opens file (creates new if does not exist) and optionally assigns group to it
- `mole [-m] [FILTERS] [DIRECTORY]` - Opens the most recent file using filters (most opened if `-m` flag is set)
- `mole list [FILTERS] [DIRECTORY]` - Prints list of all files and their corresponding groups that has even been opened through this script
- `mole secret-log [-b DATE] [-a DATE] [DIRECTORY1 [DIRECTORY2 [...]]]` - Creates an archive with log of all files that has been opened and their opening dates

### Filters
`FILTERS` is a combination of the following filters:
- `[-f GROUP1[,GROUP2[,...]]` - Specifies the groups
- `[-a DATE]` - "After" date
- `[-b DATE]` - "Before" date

`DATE` is formatted as `YYYY-MM-DD` (it is possible to specify hours, minutes and seconds, but it's not required by the task)

## Task
Task contents and all the implementation details can be found in the `TASK.md` file.
