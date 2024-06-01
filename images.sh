#!/bin/bash

#-------------------------------------------------------------------------------
# Print heading
#-------------------------------------------------------------------------------
function heading {
    echo -e "\e[33m\n$1\e[0m"
}

#-------------------------------------------------------------------------------
# Print success and error and warning logs
#-------------------------------------------------------------------------------
function success_log {
    echo -e "\e[32m$1\e[0m"
}

function error_log {
    echo -e "\e[41mERROR: $1\e[0m"
}

function warning_log {
    echo -e "\e[31mWARN: $1\e[0m"
}

#-------------------------------------------------------------------------------
# Check if previous command succeeded or not
#-------------------------------------------------------------------------------
function check_command {
    if [ $? -eq 0 ]; then
        success_log "$1 successful"
    else
        error_log "$1 failed"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Check arguments for case
#-------------------------------------------------------------------------------
check_case_arguments() {
    heading=$1
    grep_string=$2
    num_minimum_args=$3

    # Print case heading
    heading "$heading"

    # Print case usage
    cat $TEMP_FILE | grep -A2 "$grep_string"

    # Check case minimum arguments
    if [ $NUM_SCRIPT_ARGS -lt $num_minimum_args ]; then
        error_log "Script requires a minimum of '$num_minimum_args' arguments but '$NUM_SCRIPT_ARGS' provided"
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# Confirm action from user
#-------------------------------------------------------------------------------
function confirm_action {
    action=$1
    echo -e "$action"
    read -p "Press 'y' to continue or any other key to abort: "
}

#-------------------------------------------------------------------------------
# Check script arguments
#-------------------------------------------------------------------------------
function check_script_arguments {
    # Exit if no argument is passed to script
    if [[ $NUM_SCRIPT_ARGS == 0 ]]; then
        script_usage_error "No options passed to script"
    fi

    # Check if only one option is passed in
    num_options=0
    for arg in $SCRIPT_ARGS; do
        if [[ $arg =~ ^- ]]; then
            num_options=$(($num_options + 1))
        fi

        if [[ $num_options -gt 1 ]]; then
            script_usage_error "More than one option passed to script"
            exit 1
        fi
    done
}

#-------------------------------------------------------------------------------
# Check existence of input files
#-------------------------------------------------------------------------------
function check_input_files {
    input_files=$@
    valid_inputs="true"

    if [[ $# -lt 2 ]]; then
        error_log "Minimum 2 input files need to be specified!"
        echo "Input files specified = $input_files"
        valid_inputs="false"
        exit 1
    fi

    heading "Checking input files '$input_files' ..."
    for file in $input_files; do
        if [ ! -f $file ]; then
            error_log "Input file '$file' doesn't exist"
            valid_inputs="false"
            exit 1
        fi
    done

    if [ $valid_inputs == "true" ]; then
        success_log "All input files exist"
    fi
}

#-------------------------------------------------------------------------------
# Check existence of output file
#-------------------------------------------------------------------------------
function check_output_file {
    output_file=$1

    heading "Checking output file '$output_file' ..."
    if [ -f $output_file ]; then
        warning_log "Output file already exists"
        confirm_action "Do you want to overwrite '$output_file'?"
        if [ $REPLY != 'y' ]; then
            exit 1
        fi
    else
        success_log "Output file doesn't exist"
    fi
}

#-------------------------------------------------------------------------------
# Combine multiple images vertically or horizontally
#-------------------------------------------------------------------------------
function combine_images {
    input_images=$1
    output_image=$2

    check_input_files $input_images
    check_output_file $output_image

    heading "Enter inputs ..."

    # Image orientation
    read -p "Enter image orientation, 'h' for horizontal or anything else for vertical:"
    if [[ $REPLY == 'h' ]]; then
        orientation="horizontal"
    else
        orientation="vertical"
    fi

    # Image spacing
    read -p "Enter $orientation spacing (default = 10) between images:"
    if [[ -z $REPLY ]]; then
        spacing=10
    else
        spacing=$REPLY
    fi

    heading "Combining images ..."
    confirm_action "Combining the following images '${orientation}ly' with spacing '$spacing'\n\t'$input_images'\nto output image\n\t'$output_image'"
    if [[ $REPLY == 'y' ]]; then
        if [[ $orientation == "vertical" ]]; then
            montage -mode concatenate -tile 1x -geometry +0+"$spacing" $input_images $output_image
        elif [[ $orientation == "horizontal" ]]; then
            num_input_images=`echo $input_images | wc -w`
            montage -mode concatenate -tile ${num_input_images}x -geometry +$spacing+0 $input_images $output_image
        fi
        check_command "Combining images"
    fi
}

#-------------------------------------------------------------------------------
# Optimise and resize jpgs and pngs
#-------------------------------------------------------------------------------
function optimise_resize {
    input_images=$1
    resize_width_pixels=$2

    echo -e "Do you want to modify the width of following files to '$resize_width_pixels' pixels?\n\t '$input_images'"
    read -p "Press 'y' to continue or any other key to abort: "

    if [ $REPLY == 'y' ]; then
        for input_image in $input_images; do
            mogrify -filter Triangle -define filter:support=2 -thumbnail $resize_width_pixels \
            -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 \
            -define jpeg:fancy-upsampling=off -define png:compression-filter=5 \
            -define png:compression-level=9 -define png:compression-strategy=1 \
            -define png:exclude-chunk=all -interlace none -colorspace sRGB -path . $input_image
        done
        check_command "Optimising images"
    fi
}

#-------------------------------------------------------------------------------
# Resize images pixels by width or height
#-------------------------------------------------------------------------------
function resize_images {
    resize_pixels=$1
    input_images=$2

    # Resize direction
    read -p "Enter resize direction, 'w' for width or anything else for height:"
    if [[ $REPLY == 'w' ]]; then
        direction="width"
    else
        direction="height"
    fi

    heading "Resizing images ..."
    confirm_action "Resizing the '$direction' of following images to '$resize_pixels' pixels inplace\n\t'$input_images'"
    if [[ $REPLY == 'y' ]]; then
        if [[ $direction == "width" ]]; then
            mogrify -resize ${resize_pixels}x $input_images
        else
            mogrify -resize x$resize_pixels $input_images
        fi
        check_command "Resizing images"
    fi
}

#-------------------------------------------------------------------------------
# Script usage error
#-------------------------------------------------------------------------------
function script_usage_error {
    error_log "$1"
    script_usage
    exit 1
}

#-------------------------------------------------------------------------------
# Print script usage
#-------------------------------------------------------------------------------
function script_usage {
    heading "Script usage:\n$0 [OPTIONS]"

    # Format of columns
    format=" %-6s %-18s %s\n"

    # Get script name
    script_name=`basename "$0"`

    printf "\n$format" '-c' '--combine' 'Combine multiple images vertically/horizontally to jpg/png.'
    printf "$format" '' '' "Usage: $script_name -c <inputs> <output>"
    printf "$format" '' '' "Example: $script_name -c *.jpg output.jpg"

    printf "\n$format" '-cpdf' '--combine_to_pdf' 'Combine multiple images vertically to pdf.'
    printf "$format" '' '' "Usage: $script_name -cpdf <inputs> <output.pdf>"
    printf "$format" '' '' "Example: $script_name -cpdf *.jpg output"

    printf "\n$format" '-h' '--help' 'Display script usage'

    printf "\n$format" '-o' '--optimise' 'Optimise and resize jpgs and pngs in-place.'
    printf "$format" '' '' "Usage: $script_name -o <inputs> <width_in_pixels>"
    printf "$format" '' '' "Example: $script_name -o *.jpg 1500"

    printf "\n$format" '-pti' '--pdf_to_image' 'Convert multiple pdfs to image.'
    printf "$format" '' '' "Usage: $script_name -pti <output_format> <inputs>"
    printf "$format" '' '' "Example: $script_name -pti png *.pdf"

    printf "\n$format" '-ro' '--rotate' 'Rotate multiple images in-place.'
    printf "$format" '' '' "Usage: $script_name -ro <angle> <inputs>"
    printf "$format" '' '' "Example: $script_name -ro 90 *.jpg"

    printf "\n$format" '-r' '--resize' 'Resize width/height of multiple images in-place.'
    printf "$format" '' '' "Usage: $script_name -r <resize_pixels> <inputs>"
    printf "$format" '' '' "Example: $script_name -r 500 *.jpg"

    printf "\n$format" '-t' '--transparent' 'Set specific color to be transparent in png.'
    printf "$format" '' '' "Usage: $script_name -t <input> <percentage_colour_deviation> <colour> <output>"
    printf "$format" '' '' "Example: $script_name -t input.png 35% white output.png"

    echo
}

#===============================================================================
# Main script code
#===============================================================================

# Script constants
NUM_SCRIPT_ARGS=$#
SCRIPT_ARGS=$@
TEMP_FILE=`mktemp`

# Write script usage to temporary file
script_usage > $TEMP_FILE

# Check if only one option and atleast 1 argument is passed to script
check_script_arguments

# Other script constants
LAST_ARG=${@: -1}
if [[ $NUM_SCRIPT_ARGS -gt 1 ]]; then
    SECOND_TO_SECONDLAST_ARG=${@:2:$NUM_SCRIPT_ARGS-2}
fi

# Parse script options
case $1 in
    -c|--combine)
        check_case_arguments "Selected option to combine multiple jpg/png images" \
          " \-\-combine " "3"
        input_images=$SECOND_TO_SECONDLAST_ARG
        output_image=$LAST_ARG
        combine_images "$input_images" "$output_image"
        ;;

    -cpdf|--combine_to_pdf)
        check_case_arguments "Selected option to combine multiple jpg/png images to pdf" \
          " \-\-combine_to_pdf " "3"
        input_images=$SECOND_TO_SECONDLAST_ARG
        output_pdf=$LAST_ARG.pdf

        heading "Combining images ..."
        confirm_action "Combining the following images vertically\n\t'$input_images'\nto output image\n\t'$output_pdf'"
        if [[ $REPLY == 'y' ]]; then
            convert $input_images $output_pdf
            check_command "Combining images"
        fi
        ;;

    -o|--optimise)
        check_case_arguments "Selected option to optimise multiple images" \
          " \-\-optimise " "3"
        input_images=$SECOND_TO_SECONDLAST_ARG
        resize_width_pixels=$LAST_ARG
        optimise_resize "$input_images" "$resize_width_pixels"
        ;;

    -pti|--pdf_to_image)
        check_case_arguments "Selected option to convert multiple pdfs to image (png/jpeg)" \
          " \-\-pdf_to_image " "3"
        output_format=$2
        input_pdfs=${@:3}

        # DPI of converted image
        echo "Do you want to specify quality of converted images in DPI (default 150)?"
        read -p "Enter 'y' for 'yes' or anything else for 'no':"
        if [[ $REPLY == 'y' ]]; then
            read -p "Enter DPI of converted image:"
            dpi=$REPLY
        else
            dpi=150
        fi

        heading "Converting pdfs to images ..."
        confirm_action "Converting the following pdfs to '$output_format' with DPI '$dpi'\n\t'$input_pdfs'"
        for input_pdf in $input_pdfs
        do
            output_file=${input_pdf%????}
            pdftoppm -$output_format -rx $dpi -ry $dpi $input_pdf $output_file
        done
        ;;

    -ro|--rotate)
        check_case_arguments "Selected option to rotate multiple images inplace" \
          " \-\-rotate " "3"
        rotation_angle=$2
        input_images=${@:3}

        heading "Rotating images ..."
        confirm_action "Rotating the following images by '$rotation_angle' degrees inplace\n\t'$input_images'"
        if [[ $REPLY == 'y' ]]; then
            mogrify -rotate "$rotation_angle" "$input_images"
            check_command "Rotating images"
        fi
        ;;

    -r|--resize)
        check_case_arguments "Selected option to resize width/height of multiple images inplace" \
          " \-\-resize " "3"
        resize_pixels=$2
        input_images=${@:3}
        resize_images "$resize_pixels" "$input_images"
        ;;

    -t|--transparent)
        check_case_arguments "Set specific colour to be transparent in a png" \
          " \-\-transparent " "5"
        input_image=$2
        per_colour_dev=$3
        colour=$4
        output_image=$LAST_ARG

        heading "Making image transparent ..."
        confirm_action "Setting colour '$colour' to transparent with deviation '$per_colour_dev' for input image\n\t'$input_image'\nto output image\n\t'$output_image'"
        if [[ $REPLY == 'y' ]]; then
            convert "$input_image" -fuzz "$per_colour_dev" -transparent "$colour" "$output_image"
            check_command "Making image transparent"
        fi
        ;;

    -h|--help)
        script_usage
        ;;

    *)
        script_usage_error "Invalid parameters passed to script"
esac