# bar
A simple archive tool in pure bash using baee64 and stat

## HELP


Usage: bar.sh [Xlvxh]

    Options:
        -X      Extract
        -l      list
        -v      View
        -n      No dot files
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


    NOTE:
        Currently no compression is scripted
        Currently you can't extract single files in current directory
        
# TODO
* Implement https:////github.com/hyperupcall/bash-algo/blob/main/pkg/lib/public/bash-algo.sh
* Implement append
* Implement edit
* Implement remove
* Implement timestamp
* Implement extract with permissions


# WHY?
Well it's fun :D
