# bar
A simple archive tool in pure bash using baee64 and stat

## HELP


Usage: bar.sh [azRXlvnxh]

    Options:
        -a      Append
        -X      Extract
        -l      list
        -v      View
        -n      No dot files
        -R      Don't restore rights
        -z      Compress
        -s      Dry-run
        -x      Xtrace

    Example:
        Create a bar file
            bar.sh NAME.bar file1 dir1/

        View file in bar
            bar.sh -v NAME.bar file

        List files in bar
            bar.sh -l NAME.bar

        Extract:
            Extract files in a different folder:
                bar.sh -X NAME.bar folder

            Extract files in current folder:
                bar.sh -X NAME.bar

            Extract custom files in a different folder:
                bar.sh -X NAME.bar folder FILE1 FILE2

    Environment Variable:
        BAR_COMPRESS    default : gzip
        BAR_UNCOMPRESS  default : gunzip
        
    NOTE:
        Currently no compression is scripted
        Currently you can't extract single files in current directory
        
# TODO
* Implement https:////github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
* Implement edit
* Implement remove
* Implement timestamp


# WHY?
Well it's fun :D
