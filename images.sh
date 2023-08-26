#!/bin/bash

#-------------------------------------------------------------------------------
# Minimum arguments required for a function
#-------------------------------------------------------------------------------
minimum_arguments() {
    if [ $2 -lt $3 ]; then
        printf "Function $1 requires a minimum of $3 arguments but $2 provided.\n\n"
        script_usage
    fi
}

#-------------------------------------------------------------------------------
# Optimise and resize jpgs and pngs
#-------------------------------------------------------------------------------
optimise_resize() {
    echo -e "Do you want to modify the width of following files to" ${@: -1} "pixels?\n" ${@:1:$#-1}
    echo
    read -p "Press 'y' to continue or any other key to abort: "

    if [ $REPLY == 'y' ]; then
        for i in ${@:1:$#-1}
        do
            mogrify -filter Triangle -define filter:support=2 -thumbnail ${@: -1} \
            -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 \
            -define jpeg:fancy-upsampling=off -define png:compression-filter=5 \
            -define png:compression-level=9 -define png:compression-strategy=1 \
            -define png:exclude-chunk=all -interlace none -colorspace sRGB -path . $i
        done
        echo "Files have been optimised and resized to" ${@: -1} "pixels."
    fi
}

#-------------------------------------------------------------------------------
# Print script usage
#-------------------------------------------------------------------------------
script_usage()
{
    echo "---------------------------------------------------------------------"
    echo "Script usage: $0 [-h] [c|cpdf|o|r|t]"
    echo "---------------------------------------------------------------------"

    # Format of columns
    format=" %-6s %-18s %s\n"

    printf "\n$format" '-c' '--combine' 'Combine multiple images vertically to jpg/png.'
    printf "$format" '' '' "Usage: $0 -c <inputs> <output>"
    printf "$format" '' '' "Example: $0 -c *.jpg output.jpg"

    printf "\n$format" '-cpdf' '--combine_to_pdf' 'Combine multiple images vertically to pdf.'
    printf "$format" '' '' "Usage: $0 -cpdf <inputs> <output.pdf>"
    printf "$format" '' '' "Example: $0 -cpdf *.jpg output"

    printf "\n$format" '-h' '--help' 'Display script usage'

    printf "\n$format" '-o' '--optimise' 'Optimise and resize jpgs and pngs in-place.'
    printf "$format" '' '' "Usage: $0 -o <inputs> <width_in_pixels>"
    printf "$format" '' '' "Example: $0 -o *.jpg 1500"

    printf "\n$format" '-pti' '--pdf_to_image' 'Convert multiple pdfs to image.'
    printf "$format" '' '' "Usage: $0 -pti <output_format> <inputs>"
    printf "$format" '' '' "Example: $0 -pti png *.pdf"

    printf "\n$format" '-r' '--rotate' 'Rotate multiple images in-place.'
    printf "$format" '' '' "Usage: $0 -r <angle> <inputs>"
    printf "$format" '' '' "Example: $0 -r 90 *.jpg"

    printf "\n$format" '-t' '--transparent' 'Set specific color to be transparent in png.'
    printf "$format" '' '' "Usage: $0 -t <input> <percentage_colour_deviation>"
    printf "$format" '' '' "                      <colour> <output>"
    printf "$format" '' '' "Example: $0 -t input.png 35% white output.png"

    echo
    exit 1
}


#-------------------------------------------------------------------------------
# Check script parameters
#-------------------------------------------------------------------------------
# Exit if no arguments are passed
if [[ $# == 0 ]]; then
    script_usage
    exit 1
fi

case $1 in
    -h|--help)
        script_usage
        shift;;

    -c|--combine)
        montage -mode concatenate -tile 1x ${@:2:$#-2} ${@: -1}
        shift;;

    -cpdf|--combine_to_pdf)
        convert ${@:2:$#-2} ${@: -1}.pdf
        shift;;

    -o|--optimise)
        minimum_arguments $1 $(($#-1)) 2
        optimise_resize ${@:2}
        for i in 1 .. $#-1; do shift; done
        shift;;

    -pti|--pdf_to_image)
        minimum_arguments $1 $(($#-1)) 2
        for i in ${@:3}
        do
            pdftoppm -$2 $i ${i%????}
            # pdftoppm -$2 -rx 1000 -ry 1000 $i ${i%????}
        done
        shift;;

    -r|--rotate)
        mogrify -rotate $2 ${@:3}
        shift;;

    -t|--transparent)
        convert "$2" -fuzz "$3" -transparent "$4" "$5"
        for i in 1 .. $#-1; do shift; done
        shift;;

    *)
        printf "Invalid parameters passed to script\n";
        script_usage
        exit 1;;
esac