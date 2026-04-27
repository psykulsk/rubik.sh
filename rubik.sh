#!/usr/bin/env bash


# check if script is executed with bash, version >= 4.0
if [[ -z $BASH_VERSION ]]; then
		echo 'Execute this script with bash, version >= 4.0'
		exit 1
fi

VERSION_ABOVE_OR_EQUAL_4_REGEX='^[^0-3]\..*\|^[0-9][0-9][0-9]*\..*'
echo $BASH_VERSION | grep $VERSION_ABOVE_OR_EQUAL_4_REGEX
if [[ $? -ne 0 ]]; then
	echo "Execute this script with bash, version >= 4.0. Your current version=$BASH_VERSION"
	exit 1
fi

set -euo pipefail

# remove highlighted terminal cursor
tput civis
# reset to normal on exit
trap 'tput cnorm;' EXIT

# declare default options
declare -i cols=47
declare -i rows=45
X_TIME=0.05
Y_TIME=0.14
REFRESH_TIME=$X_TIME

# holds a screen matrix in an associative array
declare -A screen
# holds a cube matrix in an associative array
declare -A cube

declare -i draw_start_cols=10
declare -i draw_start_rows=9

declare -i back_cube_draw_start_cols=10
declare -i back_cube_draw_start_rows=$(( rows - 21 ))

# key input from user
key=""

# constants
declare -r EMPTY=" "
declare -r UPPERCASE_U="U"
declare -r LOWERCASE_U="u"
declare -r UPPERCASE_B="B"
declare -r LOWERCASE_B="b"
declare -r ARROW_UP="A"
declare -r ARROW_DOWN="B"
declare -r ARROW_RIGHT="C"
declare -r ARROW_LEFT="D"
declare -r HORIZONTAL_BAR="-"
declare -r VERTICAL_BAR="|"
declare -r CORNER_ICON="+"
declare -r WHITE_TEXT="\e[37m"
declare -r RED_TEXT="\e[31m"
declare -r GREEN_TEXT="\e[32m"
declare -r YELLOW_TEXT="\e[33m"
declare -r BLUE_TEXT="\e[34m"
declare -r PINK_TEXT="\e[35m"
declare -r TEAL_TEXT="\e[36m"
declare -r DIM="\e[2m"
declare -r GREEN_BG="\e[42m"
declare -r RESET="\e[0m"
declare -r GREEN_LOWER_DIAG="${GREEN_TEXT}\u259B\e${RESET}"
declare -r GREEN_UPPER_DIAG="${GREEN_TEXT}\u259F\e${RESET}"
declare -r GREEN_PARA="${GREEN_TEXT}\u28FF\e${RESET}"
declare -r FULL="\u28FF"
declare -r WHITE_FULL="${WHITE_TEXT}\u28FF${RESET}"
declare -r GREEN_FULL="${GREEN_TEXT}\u28FF${RESET}"
declare -r RED_FULL="${RED_TEXT}\u28FF${RESET}"
declare -r YELLOW_FULL="${YELLOW_TEXT}\u28FF${RESET}"
declare -r TEAL_FULL="${TEAL_TEXT}\u28FF${RESET}"
declare -r BLUE_FULL="${BLUE_TEXT}\u28FF${RESET}"
declare -r PINK_FULL="${PINK_TEXT}\u28FF${RESET}"
declare -r DIM_GREEN_FULL="${DIM}${GREEN_TEXT}\u28FF${RESET}"
declare -r DIM_RED_FULL="${DIM}${RED_TEXT}\u28FF${RESET}"
declare -r DIM_YELLOW_FULL="${DIM}${YELLOW_TEXT}\u28FF${RESET}"
declare -r DIM_BLUE_FULL="${DIM}${BLUE_TEXT}\u28FF${RESET}"
declare -r DIAG_TOP="\u28E0"
declare -r DIAG_BOT="\u280B"
declare -r DIAG_BOT_2="\u281F"

declare -i N_CUBE=3

# isometric cube display constants
declare -i FRONT_SQUARE_COLS_SIZE=5
declare -i FRONT_SQUARE_ROWS_SIZE=4
declare -i TOP_SQUARE_COLS_SIZE=5
declare -i TOP_SQUARE_ROWS_SIZE=2
declare -i RIGHT_SQUARE_COLS_SIZE=3
declare -i RIGHT_SQUARE_ROWS_SIZE=4

parse_args ()
{
	local OPTIND opt
	while getopts ":c:r:s:h" opt; do
		case ${opt} in
			c )
			cols=$OPTARG
			;;
			r )
			rows=$OPTARG
			;;
			s )
			set_speed "$OPTARG"
			;;
			h )
			usage
			exit 0
			;;
			\? )
			usage
			exit 1
			;;
		esac
	done
}

usage ()
{
    echo "usage: $0 [-c cols ] [-r rows] [-s speed]"
    echo "  -h display help"
    echo "  -c cols specify game area cols. Make sure it's not higher then the actual terminal's width. "
    echo "  -r rows specify game area rows. Make sure it's not higher then the actual terminal's height."
    echo "  -s speed specify snake speed. Value from 1-10."
}

clear_game_area_screen ()
{
	clear
	for ((i=1;i<rows;i++)); do
		for ((j=1;j<cols;j++)); do
			screen[$i,$j]=$EMPTY
		done
	done
	draw_game_area_boundaries
}

draw_game_area_boundaries()
{
	for i in 0 $rows; do
		for ((j=0;j<cols;j++)); do
			screen[$i,$j]=$HORIZONTAL_BAR
		done
	done
	for j in 0 $cols; do
		for ((i=0;i<rows+1;i++)); do
			screen[$i,$j]=$VERTICAL_BAR
		done
	done
	screen[0,0]=$CORNER_ICON
	screen[0,$cols]=$CORNER_ICON
	screen[$rows,$cols]=$CORNER_ICON
	screen[$rows,0]=$CORNER_ICON
}

print_screen ()
{
	for ((i=0;i<rows+1;i++)); do
        for ((j=0;j<cols+1;j++)); do
			printf "${screen[$i,$j]}"
		done
		printf "\n"
	done
}

handle_input ()
{
	if [[ "$1" = "t" ]]; then
        top_wall_counter_clockwise_rotation
	elif [[ "$1" = "T" ]]; then
        top_wall_clockwise_rotation
	elif [[ "$1" = "g" ]]; then
        mid_wall_counter_clockwise_rotation
	elif [[ "$1" = "G" ]]; then
        mid_wall_clockwise_rotation
	elif [[ "$1" = "b" ]]; then
        bot_wall_counter_clockwise_rotation
	elif [[ "$1" = "B" ]]; then
        bot_wall_clockwise_rotation
	elif [[ "$1" = "Y" ]]; then
        front_wall_left_col_down_rotation
	elif [[ "$1" = "y" ]]; then
        front_wall_left_col_up_rotation
	elif [[ "$1" = "U" ]]; then
        front_wall_mid_col_down_rotation
	elif [[ "$1" = "u" ]]; then
        front_wall_mid_col_up_rotation
	elif [[ "$1" = "I" ]]; then
        front_wall_right_col_down_rotation
	elif [[ "$1" = "H" ]]; then
        front_wall_counter_clockwise_rotation
	elif [[ "$1" = "h" ]]; then
        front_wall_clockwise_rotation
	elif [[ "$1" = "i" ]]; then
        front_wall_right_col_up_rotation
	elif [[ "$1" = "j" ]]; then
        right_wall_mid_col_down_rotation
	elif [[ "$1" = "J" ]]; then
        right_wall_mid_col_up_rotation
	elif [[ "$1" = "K" ]]; then
        back_wall_counter_clockwise_rotation
	elif [[ "$1" = "k" ]]; then
        back_wall_clockwise_rotation
	elif [[ "$1" = "r" ]]; then
        # whole cube horizontal right rotation
        top_wall_counter_clockwise_rotation
        mid_wall_counter_clockwise_rotation
        bot_wall_counter_clockwise_rotation
	elif [[ "$1" = "R" ]]; then
        # whole cube horizontal left rotation
        top_wall_clockwise_rotation
        mid_wall_clockwise_rotation
        bot_wall_clockwise_rotation
	elif [[ "$1" = "f" ]]; then
        # whole cube up rotation
        front_wall_left_col_up_rotation
        front_wall_mid_col_up_rotation
        front_wall_right_col_up_rotation
	elif [[ "$1" = "F" ]]; then
        # whole cube down rotation
        front_wall_left_col_down_rotation
        front_wall_mid_col_down_rotation
        front_wall_right_col_down_rotation
	elif [[ "$1" = "v" ]]; then
        # whole cube clockwise rotation
        front_wall_clockwise_rotation
        right_wall_mid_col_down_rotation
        back_wall_clockwise_rotation
	elif [[ "$1" = "V" ]]; then
        # whole cube counter clockwise rotation
        front_wall_counter_clockwise_rotation
        right_wall_mid_col_up_rotation
        back_wall_counter_clockwise_rotation
	elif [[ "$1" = "s" ]]; then
        shuffle
	else
		:
	fi
}
declare -i LEFT_X=${N_CUBE}
declare -i LEFT_Y=0
declare -i FRONT_X=${N_CUBE}
declare -i FRONT_Y=$(( 1*${N_CUBE} ))
declare -i RIGHT_X=${N_CUBE}
declare -i RIGHT_Y=$(( 2*${N_CUBE} ))
declare -i BACK_X=${N_CUBE}
declare -i BACK_Y=$(( 3*${N_CUBE} ))
declare -i TOP_X=0
declare -i TOP_Y=${N_CUBE}
declare -i BOT_X=$(( 2*${N_CUBE} ))
declare -i BOT_Y=${N_CUBE}

declare -r SEQ_DIR_NORTH="N"
declare -r SEQ_DIR_SOUTH="S"
declare -r SEQ_DIR_EAST="E"
declare -r SEQ_DIR_WEST="W"

declare -r BLUE="BLUE"
declare -r GREEN="GREEN"
declare -r WHITE="WHITE"
declare -r YELLOW="YELLOW"
declare -r RED="RED"
declare -r PINK="PINK"
declare -r UNSET="___"
declare -A STARTING_COLORS=( $BLUE $GREEN $WHITE $YELLOW $RED $PINK)
declare -A COLOR_MAPPING=( [$BLUE]=$BLUE_FULL [$GREEN]=$GREEN_FULL [$WHITE]=$WHITE_FULL [$YELLOW]=$TEAL_FULL [$RED]=$RED_FULL [$PINK]=$PINK_FULL )


set_color_to_wall_on_cube()
{
    start_x=$1
    start_y=$2
    color=$3
	for (( x=start_x;x<start_x+N_CUBE;x++ )); do
        for (( y=start_y;y<start_y+N_CUBE;y++ )); do
			cube[$x,$y]=$color
		done
	done
}

debug_print_cube()
{
	for (( x=0;x<N_CUBE*3;x++ )); do
        for (( y=0;y<N_CUBE*4;y++ )); do
            printf "|%-7s| " "${cube[$x,$y]}"
		done
        printf "\n"
	done
}

set_cube_unset()
{
	for (( x=0;x<N_CUBE*3;x++ )); do
        for (( y=0;y<N_CUBE*4;y++ )); do
            cube[$x,$y]=$UNSET
		done
	done
}

#rotate_top_right() 
#{
#   # top rotate around 
#   # save top row from right wall
#   # move front row to right wall
#   # move 
#   # back 
#   
#}

rotate_values_between_points()
{
    local -n map_of_values=$1
    IFS=';' read -r -a arrays_of_points <<< "$2" 
    #echo "arrays_of_points=${arrays_of_points[@]}"
    #first_array_of_points=${arrays_of_points[0]}
    #echo "first_array_of_points=$first_array_of_points"
    values_copy_0=()
    copy_values_from_2d_map_to_array map_of_values values_copy_0 ${arrays_of_points[0]}
    values_copy_1=()
    copy_values_from_2d_map_to_array map_of_values values_copy_1 ${arrays_of_points[1]}
    values_copy_2=()
    copy_values_from_2d_map_to_array map_of_values values_copy_2 ${arrays_of_points[2]}
    values_copy_3=()
    #echo "values_copy_0=$values_copy_0[@]"
    copy_values_from_2d_map_to_array map_of_values values_copy_3 ${arrays_of_points[3]}
    set_value_from_array_to_2d_map map_of_values values_copy_0 ${arrays_of_points[1]}
    set_value_from_array_to_2d_map map_of_values values_copy_1 ${arrays_of_points[2]}
    set_value_from_array_to_2d_map map_of_values values_copy_2 ${arrays_of_points[3]}
    set_value_from_array_to_2d_map map_of_values values_copy_3 ${arrays_of_points[0]}
}

copy_values_from_2d_map_to_array()
{
    local -n local_map_of_values=$1
    local -n output_array=$2
    IFS='_' read -r -a array_of_points leftover <<< $3
    i=0
    #echo "local_map_of_values=${local_map_of_values[0,0]}"
    #echo "array_of_points=${array_of_points[@]}"
    for point in ${array_of_points[@]}
    do
        # Temporarily change IFS to a comma and read into an array
        IFS=',' read -r x y leftover <<< $point
        value=${local_map_of_values[$x,$y]}
        #echo "x=$x, y=$y, i=$i, value=$value"
        output_array[$i]=$value
        #echo "output_array[@]=${output_array[@]}"
        i=$((i+1))
    done
}

copy_values_from_points_to_points_in_2d_map()
{
    local -n local_map_of_values=$1
    local -n source_points=$2
    local -n target_points=$3
    IFS='_' read -r -a array_of_source_points leftover <<< $source_points
    IFS='_' read -r -a array_of_target_points leftover <<< $target_points
    #echo "array_of_source_points=${array_of_source_points[@]}"
    #echo "array_of_target_points=${array_of_target_points[@]}"
    for i in 0 1 2
    do
        IFS=',' read -r source_x source_y leftover <<< ${array_of_source_points[$i]}
        IFS=',' read -r target_x target_y leftover <<< ${array_of_target_points[$i]}
        #echo "source_x=$source_x, source_y=$source_y"
        source_value=${local_map_of_values[$source_x,$source_y]}
        target_value=${local_map_of_values[$target_x,$target_y]}
        #echo "source_x=$source_x, source_y=$source_y, i=$i, target_x=$target_x, target_y=$target_y source_alue=$source_value target_value=$target_value"
        local_map_of_values[$target_x,$target_y]=$source_value
    done
}

set_value_from_array_to_2d_map()
{
    local -n local_map_of_values=$1
    local -n values=$2
    IFS='_' read -r -a array_of_points <<< $3
    i=0
    for point in ${array_of_points[@]}
    do
        IFS=',' read -r x y <<< $point
        value_before=${local_map_of_values[$x,$y]}
        value_to_set=${values[$i]}
        #echo "setting value x=$x, y=$y, i=$i, value_before=$value_before,value_to_set=$value_to_set"
        local_map_of_values[$x,$y]=$value_to_set
        i=$((i+1))
    done
}

reset_cube()
{
    set_cube_unset
    set_color_to_wall_on_cube $TOP_X $TOP_Y $BLUE
    set_color_to_wall_on_cube $LEFT_X $LEFT_Y $WHITE
    set_color_to_wall_on_cube $FRONT_X $FRONT_Y $RED
    set_color_to_wall_on_cube $RIGHT_X $RIGHT_Y $YELLOW
    set_color_to_wall_on_cube $BACK_X $BACK_Y $PINK
    set_color_to_wall_on_cube $BOT_X $BOT_Y $GREEN
}

draw_diag_right_square ()
{
    start_r=$1
    start_c=$2
    cell=$3
    r=$(( $start_r ))
    c=$start_c
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
    r=$(( $start_r-1 ))
    c=$(( $start_c+1 ))
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
    r=$(( $start_r-2 ))
    c=$(( $start_c+2 ))
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
}

draw_diag_right_square_for_bot_cube ()
{
    start_r=$1
    start_c=$2
    cell=$3
    r=$(( $start_r ))
    c=$start_c
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
    r=$(( $start_r+1 ))
    c=$(( $start_c+1 ))
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
    r=$(( $start_r+2 ))
    c=$(( $start_c+2 ))
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
}

top_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="T"
    screen[$(($r)),$(($c+1))]="0"
    screen[$(($r)),$(($c+2))]="P"
}

bottom_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="B"
    screen[$(($r)),$(($c+1))]="O"
    screen[$(($r)),$(($c+2))]="T"
}

right_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="R"
    screen[$(($r)),$(($c+1))]="I"
    screen[$(($r)),$(($c+2))]="G"
    screen[$(($r)),$(($c+3))]="H"
    screen[$(($r)),$(($c+4))]="T"
}

left_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="L"
    screen[$(($r)),$(($c+1))]="E"
    screen[$(($r)),$(($c+2))]="F"
    screen[$(($r)),$(($c+3))]="T"
}

front_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="F"
    screen[$(($r)),$(($c+1))]="R"
    screen[$(($r)),$(($c+2))]="O"
    screen[$(($r)),$(($c+3))]="N"
    screen[$(($r)),$(($c+4))]="T"
}

back_label()
{
    r=$1
    c=$2
    screen[$(($r)),$(($c))]="B"
    screen[$(($r)),$(($c+1))]="A"
    screen[$(($r)),$(($c+2))]="C"
    screen[$(($r)),$(($c+3))]="K"
}

draw_front_square ()
{
    #echo "drawing front square 1=$1 2=$2 3=$3"

    r=$1
    c=$2
    cell=$3
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r)),$(($c+1))]=$cell
    screen[$(($r)),$(($c+2))]=$cell
    screen[$(($r)),$(($c+3))]=$cell
    screen[$(($r)),$(($c+4))]=$cell
    screen[$(($r+1)),$(($c))]=$cell
    screen[$(($r+1)),$(($c+1))]=$cell
    screen[$(($r+1)),$(($c+2))]=$cell
    screen[$(($r+1)),$(($c+3))]=$cell
    screen[$(($r+1)),$(($c+4))]=$cell
    screen[$(($r+2)),$(($c))]=$cell
    screen[$(($r+2)),$(($c+1))]=$cell
    screen[$(($r+2)),$(($c+2))]=$cell
    screen[$(($r+2)),$(($c+3))]=$cell
    screen[$(($r+2)),$(($c+4))]=$cell
    screen[$(($r+3)),$(($c))]=$cell
    screen[$(($r+3)),$(($c+1))]=$cell
    screen[$(($r+3)),$(($c+2))]=$cell
    screen[$(($r+3)),$(($c+3))]=$cell
    screen[$(($r+3)),$(($c+4))]=$cell

}

draw_diag_top_square ()
{
    cell=$3
    r=$1
    c=$2
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r)),$(($c+1))]=$cell
    screen[$(($r)),$(($c+2))]=$cell
    screen[$(($r)),$(($c+3))]=$cell
    screen[$(($r)),$(($c+4))]=$cell
    r=$1+1
    c=$2-1
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r)),$(($c+1))]=$cell
    screen[$(($r)),$(($c+2))]=$cell
    screen[$(($r)),$(($c+3))]=$cell
    screen[$(($r)),$(($c+4))]=$cell
}

draw_diag_bot_square ()
{
    cell=$3
    r=$1
    c=$2
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r)),$(($c+1))]=$cell
    screen[$(($r)),$(($c+2))]=$cell
    screen[$(($r)),$(($c+3))]=$cell
    screen[$(($r)),$(($c+4))]=$cell
    r=$1+1
    c=$2+1
    screen[$(($r)),$(($c))]=$cell
    screen[$(($r)),$(($c+1))]=$cell
    screen[$(($r)),$(($c+2))]=$cell
    screen[$(($r)),$(($c+3))]=$cell
    screen[$(($r)),$(($c+4))]=$cell
}

wall_to_screen()
{
    draw_method=$1
    wall_start_row=$2
    wall_start_cols=$3
    wall_cube_x=$4
    wall_cube_y=$5
    wall_rows_size=$6
    wall_cols_size=$7
    row_shift_each_y=$8
    col_shift_each_x=$9
	for (( x=wall_cube_x;x<wall_cube_x+N_CUBE;x++ )); do
        for (( y=wall_cube_y;y<wall_cube_y+N_CUBE;y++ )); do
            row_shift=$(( $row_shift_each_y*(y-wall_cube_y) ))
            #echo "x=$x y=$y"
			color=${cube[$x,$y]}
            #echo "color=$color"
            color_from_mapping=${COLOR_MAPPING[$color]}
            col_shift=$(( $col_shift_each_x*(x-wall_cube_x) ))
            start_rows=$(( row_shift+wall_start_row+(x-wall_cube_x)*wall_rows_size))
            start_cols=$(( col_shift+wall_start_cols+(y-wall_cube_y)*wall_cols_size))
            color_to_set=$color_from_mapping
            #if (( (y-wall_cube_y) % 2 == 1 )); then
            #    if (( (x-wall_cube_x) % 2 == 1 )); then
            #        color_to_set=$DIM$color_from_mapping
            #    fi
            #else 
            #    if (( (x-wall_cube_x) % 2 == 0 )); then
            #        color_to_set=$DIM$color_from_mapping
            #    fi
            #fi
            $draw_method $start_rows $start_cols $color_to_set
		done
	done
}

wall_to_screen_mirrored()
{
    draw_method=$1
    wall_start_row=$2
    wall_start_cols=$3
    wall_cube_x=$4
    wall_cube_y=$5
    wall_rows_size=$6
    wall_cols_size=$7
    row_shift_each_y=$8
    col_shift_each_x=$9
	for (( x=wall_cube_x;x<wall_cube_x+N_CUBE;x++ )); do
        for (( y=wall_cube_y;y<wall_cube_y+N_CUBE;y++ )); do
            row_shift=$(( $row_shift_each_y*(y-wall_cube_y) ))
            reversed_x=$((wall_cube_x+N_CUBE-1-(x-wall_cube_x)))
            reversed_y=$((wall_cube_y+N_CUBE-1-(y-wall_cube_y)))
            #echo "reversed_x=$reversed_x reversed_y=$reversed_y"
            color=${cube[$reversed_x,$reversed_y]}
            #echo "color=$color"
            color_from_mapping=${COLOR_MAPPING[$color]}
            col_shift=$(( $col_shift_each_x*(x-wall_cube_x) ))
            start_rows=$(( row_shift+wall_start_row+(x-wall_cube_x)*wall_rows_size))
            start_cols=$(( col_shift+wall_start_cols+(y-wall_cube_y)*wall_cols_size))
            color_to_set=$color_from_mapping
            $draw_method $start_rows $start_cols $color_to_set
		done
	done
}

wall_to_screen_mirrored_horizontal()
{
    draw_method=$1
    wall_start_row=$2
    wall_start_cols=$3
    wall_cube_x=$4
    wall_cube_y=$5
    wall_rows_size=$6
    wall_cols_size=$7
    row_shift_each_y=$8
    col_shift_each_x=$9
	for (( x=wall_cube_x;x<wall_cube_x+N_CUBE;x++ )); do
        for (( y=wall_cube_y;y<wall_cube_y+N_CUBE;y++ )); do
            row_shift=$(( $row_shift_each_y*(y-wall_cube_y) ))
            reversed_x=$((wall_cube_x+N_CUBE-1-(x-wall_cube_x)))
            reversed_y=$((wall_cube_y+N_CUBE-1-(y-wall_cube_y)))
            #echo "reversed_x=$reversed_x reversed_y=$reversed_y"
            #color=${cube[$x,$reversed_y]}
            color=${cube[$reversed_x,$y]}
            #echo "color=$color"
            color_from_mapping=${COLOR_MAPPING[$color]}
            col_shift=$(( $col_shift_each_x*(x-wall_cube_x) ))
            start_rows=$(( row_shift+wall_start_row+(x-wall_cube_x)*wall_rows_size))
            start_cols=$(( col_shift+wall_start_cols+(y-wall_cube_y)*wall_cols_size))
            color_to_set=$color_from_mapping
            $draw_method $start_rows $start_cols $color_to_set
		done
	done
}

cube_to_screen()
{
    front_row=$1
    front_col=$2

    front_label $(( front_row + 5 )) $(( front_col - 7))
    wall_to_screen draw_front_square $front_row $front_col $FRONT_X $FRONT_Y $FRONT_SQUARE_ROWS_SIZE $FRONT_SQUARE_COLS_SIZE 0 0
    
    right_wall_row=$(( $front_row ))
    right_wall_col=$(( $front_col + FRONT_SQUARE_COLS_SIZE*N_CUBE ))
    right_label $(( right_wall_row + 5 )) $(( right_wall_col + 11 ))
    wall_to_screen draw_diag_right_square $right_wall_row $right_wall_col $RIGHT_X $RIGHT_Y $RIGHT_SQUARE_ROWS_SIZE $RIGHT_SQUARE_COLS_SIZE -2 0

    top_wall_row=$(( $front_row - TOP_SQUARE_ROWS_SIZE*N_CUBE  ))
    top_wall_col=$(( $front_col + RIGHT_SQUARE_COLS_SIZE*N_CUBE - 1 ))
    top_label $(( top_wall_row - 2 )) $(( top_wall_col + 3 ))
    wall_to_screen draw_diag_top_square $top_wall_row $top_wall_col $TOP_X $TOP_Y $TOP_SQUARE_ROWS_SIZE $TOP_SQUARE_COLS_SIZE 0 -3
}

back_cube_to_screen()
{
    front_row=$1
    front_col=$2

    back_label $(( front_row + 5 )) $(( front_col - 7))
    wall_to_screen draw_front_square $front_row $front_col $BACK_X $BACK_Y $FRONT_SQUARE_ROWS_SIZE $FRONT_SQUARE_COLS_SIZE 0 0
    
    right_wall_row=$(( $front_row ))
    right_wall_col=$(( $front_col + FRONT_SQUARE_COLS_SIZE*N_CUBE ))
    left_label $(( right_wall_row + 5 )) $(( right_wall_col + 11 ))
    wall_to_screen draw_diag_right_square_for_bot_cube $right_wall_row $right_wall_col $LEFT_X $LEFT_Y $RIGHT_SQUARE_ROWS_SIZE $RIGHT_SQUARE_COLS_SIZE 2 0

    bot_wall_row=$(( $front_row + FRONT_SQUARE_ROWS_SIZE*N_CUBE ))
    bot_wall_col=$(( $front_col + 1 ))
    bottom_label $(( bot_wall_row +  7 )) $(( bot_wall_col + 10 ))
    #wall_to_screen draw_diag_bot_square $bot_wall_row $bot_wall_col $BOT_X $BOT_Y $TOP_SQUARE_ROWS_SIZE $TOP_SQUARE_COLS_SIZE 0 3
    wall_to_screen_mirrored draw_diag_bot_square $bot_wall_row $bot_wall_col $BOT_X $BOT_Y $TOP_SQUARE_ROWS_SIZE $TOP_SQUARE_COLS_SIZE 0 3
}

rotation_seq()
{
    sequence=""
    for row_start_point in $1
    do
    
        #echo "row_start_point=$row_start_point"
        IFS=',' read -r sequence_direction x y <<< $row_start_point
	    if [[ $sequence_direction = $SEQ_DIR_SOUTH ]]; then
            for i in {0..2}
            do
                start_x=$((x+i))
                sequence="${sequence}${start_x},${y}_"
            done
            sequence="${sequence};"
	    elif [[ $sequence_direction = $SEQ_DIR_NORTH ]]; then
            for i in {0..2}
            do
                start_x=$((x+2-i))
                sequence="${sequence}${start_x},${y}_"
            done
            sequence="${sequence};"
	    elif [[ $sequence_direction = $SEQ_DIR_EAST ]]; then
            for i in {0..2}
            do
                start_y=$((y+i))
                sequence="${sequence}${x},${start_y}_"
            done
            sequence="${sequence};"
	    elif [[ $sequence_direction = $SEQ_DIR_WEST ]]; then
            for i in {0..2}
            do
                start_y=$((y+2-i))
                sequence="${sequence}${x},${start_y}_"
            done
            sequence="${sequence};"
        fi
    done
    echo $sequence
}


horizontal_rotation_seq()
{
    sequence=""
    for row_start_point in $1
    do
        #echo "row_start_point=$row_start_point"
        IFS=',' read -r x y <<< $row_start_point
        for i in {0..2}
        do
            #echo "x=$x, y=$y"
            start_y=$((y+i))
            #echo "start_x=$start_x"
            sequence="${sequence}${x},${start_y}_"
        done
        sequence="${sequence};"
    done
    echo $sequence
}

same_wall_rotation_seq_clockwise()
{
    sequence=""
    wall_top_left_x=$1
    wall_top_left_y=$2
    for i in {0..2}
    do
        start_y=$((wall_top_left_y+i))
        sequence="${sequence}${wall_top_left_x},${start_y}_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_x=$((wall_top_left_x+i))
        sequence="${sequence}${start_x},$((wall_top_left_y+2))_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_y=$((wall_top_left_y+2-i))
        sequence="${sequence}$((wall_top_left_x+2)),${start_y}_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_x=$((wall_top_left_x+2-i))
        sequence="${sequence}${start_x},${wall_top_left_y}_"
    done
    sequence="${sequence};"
    echo $sequence
}

same_wall_rotation_seq_counter_clockwise()
{
    sequence=""
    wall_top_left_x=$1
    wall_top_left_y=$2
    for i in {0..2}
    do
        start_y=$((wall_top_left_y+i))
        sequence="${sequence}${wall_top_left_x},${start_y}_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_x=$((wall_top_left_x+2-i))
        sequence="${sequence}${start_x},${wall_top_left_y}_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_y=$((wall_top_left_y+2-i))
        sequence="${sequence}$((wall_top_left_x+2)),${start_y}_"
    done
    sequence="${sequence};"
    for i in {0..2}
    do
        start_x=$((wall_top_left_x+i))
        sequence="${sequence}${start_x},$((wall_top_left_y+2))_"
    done
    sequence="${sequence};"
    echo $sequence
}


TOP_WALL_CLOCKWISE_ROTATION=$(same_wall_rotation_seq_clockwise ${TOP_X} ${TOP_Y})
TOP_ROW_FRONT_LEFT_ROTATION=$(rotation_seq "${SEQ_DIR_EAST},${FRONT_X},${FRONT_Y} ${SEQ_DIR_EAST},${LEFT_X},${LEFT_Y} ${SEQ_DIR_EAST},${BACK_X},${BACK_Y} ${SEQ_DIR_EAST},${RIGHT_X},${RIGHT_Y}")

top_wall_clockwise_rotation()
{
    rotate_values_between_points cube $TOP_ROW_FRONT_LEFT_ROTATION
    rotate_values_between_points cube $TOP_WALL_CLOCKWISE_ROTATION
}

TOP_WALL_COUNTER_CLOCKWISE_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${TOP_X} ${TOP_Y})
TOP_ROW_FRONT_RIGHT_ROTATION=$(horizontal_rotation_seq "${RIGHT_X},${RIGHT_Y} ${BACK_X},${BACK_Y} ${LEFT_X},${LEFT_Y} ${FRONT_X},${FRONT_Y}")

top_wall_counter_clockwise_rotation()
{
    rotate_values_between_points cube $TOP_WALL_COUNTER_CLOCKWISE_ROTATION
    rotate_values_between_points cube $TOP_ROW_FRONT_RIGHT_ROTATION
}

BOT_ROW_X_SHIFT=2
BOT_WALL_CLOCKWISE_ROTATION=$(same_wall_rotation_seq_clockwise ${BOT_X} ${BOT_Y})
BOT_ROW_FRONT_RIGHT_ROTATION=$(horizontal_rotation_seq "$(( FRONT_X + BOT_ROW_X_SHIFT )),$(( FRONT_Y )) $(( RIGHT_X + BOT_ROW_X_SHIFT )),$(( RIGHT_Y )) $(( BACK_X + BOT_ROW_X_SHIFT )),$(( BACK_Y )) $(( LEFT_X + BOT_ROW_X_SHIFT )),$(( LEFT_Y )) ")
bot_wall_counter_clockwise_rotation()
{
    rotate_values_between_points cube $BOT_WALL_CLOCKWISE_ROTATION
    rotate_values_between_points cube $BOT_ROW_FRONT_RIGHT_ROTATION
}

BOT_WALL_COUNTER_CLOCKWISE_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${BOT_X} ${BOT_Y})
BOT_ROW_FRONT_LEFT_ROTATION=$(horizontal_rotation_seq "$(( FRONT_X + BOT_ROW_X_SHIFT )),$(( FRONT_Y )) $(( LEFT_X + BOT_ROW_X_SHIFT )),$(( LEFT_Y )) $(( BACK_X + BOT_ROW_X_SHIFT )),$(( BACK_Y )) $(( RIGHT_X + BOT_ROW_X_SHIFT )),$(( RIGHT_Y ))")
bot_wall_clockwise_rotation()
{
    rotate_values_between_points cube $BOT_WALL_COUNTER_CLOCKWISE_ROTATION
    rotate_values_between_points cube $BOT_ROW_FRONT_LEFT_ROTATION
}

MID_ROW_X_SHIFT=1
MID_ROW_FRONT_RIGHT_ROTATION=$(horizontal_rotation_seq " $(( FRONT_X + MID_ROW_X_SHIFT )),$(( FRONT_Y )) $(( RIGHT_X + MID_ROW_X_SHIFT )),$(( RIGHT_Y )) $(( BACK_X + MID_ROW_X_SHIFT )),$(( BACK_Y )) $(( LEFT_X + MID_ROW_X_SHIFT )),$(( LEFT_Y ))")
mid_wall_counter_clockwise_rotation()
{
    rotate_values_between_points cube $MID_ROW_FRONT_RIGHT_ROTATION
}

MID_ROW_FRONT_LEFT_ROTATION=$(horizontal_rotation_seq "$(( FRONT_X + MID_ROW_X_SHIFT )),$(( FRONT_Y )) $(( LEFT_X + MID_ROW_X_SHIFT )),$(( LEFT_Y )) $(( BACK_X + MID_ROW_X_SHIFT )),$(( BACK_Y )) $(( RIGHT_X + MID_ROW_X_SHIFT )),$(( RIGHT_Y ))")
mid_wall_clockwise_rotation()
{
    rotate_values_between_points cube $MID_ROW_FRONT_LEFT_ROTATION
}

RIGHT_ROW_Y_SHIFT=2
FRONT_LEFT_COL_WALL_UP_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${LEFT_X} ${LEFT_Y})
FRONT_LEFT_COL_UP_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y ))")
front_wall_left_col_up_rotation()
{
    rotate_values_between_points cube $FRONT_LEFT_COL_WALL_UP_ROTATION
    rotate_values_between_points cube $FRONT_LEFT_COL_UP_ROTATION
}

FRONT_LEFT_COL_WALL_DOWN_ROTATION=$(same_wall_rotation_seq_clockwise ${LEFT_X} ${LEFT_Y})
FRONT_LEFT_COL_DOWN_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y ))")
front_wall_left_col_down_rotation()
{
    rotate_values_between_points cube $FRONT_LEFT_COL_WALL_DOWN_ROTATION
    rotate_values_between_points cube $FRONT_LEFT_COL_DOWN_ROTATION
}

MID_ROW_Y_SHIFT=1
FRONT_MID_COL_UP_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y + MID_ROW_Y_SHIFT ))")
front_wall_mid_col_up_rotation()
{
    rotate_values_between_points cube $FRONT_MID_COL_UP_ROTATION
}

FRONT_MID_COL_DOWN_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y + MID_ROW_Y_SHIFT ))")
front_wall_mid_col_down_rotation()
{
    rotate_values_between_points cube $FRONT_MID_COL_DOWN_ROTATION
}

FRONT_RIGHT_COL_WALL_UP_ROTATION=$(same_wall_rotation_seq_clockwise ${RIGHT_X} ${RIGHT_Y})
FRONT_RIGHT_COL_UP_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y + RIGHT_ROW_Y_SHIFT ))")
front_wall_right_col_up_rotation()
{
    rotate_values_between_points cube $FRONT_RIGHT_COL_WALL_UP_ROTATION
    rotate_values_between_points cube $FRONT_RIGHT_COL_UP_ROTATION
}

FRONT_RIGHT_COL_WALL_DOWN_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${RIGHT_X} ${RIGHT_Y})
FRONT_RIGHT_COL_DOWN_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( FRONT_X )),$(( FRONT_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_SOUTH},$(( BOT_X )),$(( BOT_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_NORTH},$(( BACK_X )),$(( BACK_Y )) ${SEQ_DIR_SOUTH},$(( TOP_X )),$(( TOP_Y + RIGHT_ROW_Y_SHIFT ))")
front_wall_right_col_down_rotation()
{
    rotate_values_between_points cube $FRONT_RIGHT_COL_WALL_DOWN_ROTATION
    rotate_values_between_points cube $FRONT_RIGHT_COL_DOWN_ROTATION
}

RIGHT_MID_COL_UP_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_EAST},$(( TOP_X + 1 )),$(( TOP_Y)) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_WEST},$(( BOT_X + 1 )),$(( BOT_Y ))")
right_wall_mid_col_up_rotation()
{
    rotate_values_between_points cube $RIGHT_MID_COL_UP_ROTATION
}

RIGHT_MID_COL_DOWN_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_WEST},$(( BOT_X + 1 )),$(( BOT_Y )) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y + MID_ROW_Y_SHIFT )) ${SEQ_DIR_EAST},$(( TOP_X + 1 )),$(( TOP_Y ))")
right_wall_mid_col_down_rotation()
{
    rotate_values_between_points cube $RIGHT_MID_COL_DOWN_ROTATION
}

BACK_WALL_COUNTER_CLOCKWISE_BACK_WALL_ROTATION=$(same_wall_rotation_seq_clockwise ${BACK_X} ${BACK_Y})
BACK_WALL_COUNTER_CLOCKWISE_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_EAST},$(( TOP_X )),$(( TOP_Y )) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y )) ${SEQ_DIR_WEST},$(( BOT_X + 2 )),$(( BOT_Y ))")
back_wall_counter_clockwise_rotation()
{
    rotate_values_between_points cube $BACK_WALL_COUNTER_CLOCKWISE_BACK_WALL_ROTATION
    rotate_values_between_points cube $BACK_WALL_COUNTER_CLOCKWISE_ROTATION
}

BACK_WALL_CLOCKWISE_BACK_WALL_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${BACK_X} ${BACK_Y})
BACK_WALL_CLOCKWISE_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y + RIGHT_ROW_Y_SHIFT )) ${SEQ_DIR_WEST},$(( BOT_X + 2 )),$(( BOT_Y )) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y )) ${SEQ_DIR_EAST},$(( TOP_X )),$(( TOP_Y ))")
back_wall_clockwise_rotation()
{
    rotate_values_between_points cube $BACK_WALL_CLOCKWISE_BACK_WALL_ROTATION
    rotate_values_between_points cube $BACK_WALL_CLOCKWISE_ROTATION
}

FRONT_WALL_COUNTER_CLOCKWISE_FRONT_WALL_ROTATION=$(same_wall_rotation_seq_counter_clockwise ${FRONT_X} ${FRONT_Y})
FRONT_WALL_COUNTER_CLOCKWISE_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y )) ${SEQ_DIR_EAST},$(( TOP_X + 2 )),$(( TOP_Y )) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y + 2 )) ${SEQ_DIR_WEST},$(( BOT_X )),$(( BOT_Y ))")
front_wall_counter_clockwise_rotation()
{
    rotate_values_between_points cube $FRONT_WALL_COUNTER_CLOCKWISE_FRONT_WALL_ROTATION
    rotate_values_between_points cube $FRONT_WALL_COUNTER_CLOCKWISE_ROTATION
}

FRONT_WALL_CLOCKWISE_FRONT_WALL_ROTATION=$(same_wall_rotation_seq_clockwise ${FRONT_X} ${FRONT_Y})
FRONT_WALL_CLOCKWISE_ROTATION=$(rotation_seq "${SEQ_DIR_SOUTH},$(( RIGHT_X )),$(( RIGHT_Y )) ${SEQ_DIR_WEST},$(( BOT_X )),$(( BOT_Y )) ${SEQ_DIR_NORTH},$(( LEFT_X )),$(( LEFT_Y + 2 )) ${SEQ_DIR_EAST},$(( TOP_X + 2 )),$(( TOP_Y ))")
front_wall_clockwise_rotation()
{
    rotate_values_between_points cube $FRONT_WALL_CLOCKWISE_FRONT_WALL_ROTATION
    rotate_values_between_points cube $FRONT_WALL_CLOCKWISE_ROTATION
}

print_controls()
{
    start_r=1
    echo -e "\e[$((start_r));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+1));$((cols+2))H  Controls     |"
    echo -e "\e[$((start_r+2));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+3));$((cols+2))H  Horizontal   |"
    echo -e "\e[$((start_r+4));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+5));$((cols+2))H T - top row   |"
    echo -e "\e[$((start_r+6));$((cols+2))H G - mid row   |"
    echo -e "\e[$((start_r+7));$((cols+2))H B - bot row   |"
    echo -e "\e[$((start_r+8));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+9));$((cols+2))H   Vertical    |"
    echo -e "\e[$((start_r+10));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+11));$((cols+2))H Y - left col  |"
    echo -e "\e[$((start_r+12));$((cols+2))H U - mid col   |"
    echo -e "\e[$((start_r+13));$((cols+2))H I - right col |"
    echo -e "\e[$((start_r+14));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+15));$((cols+2))H    Z-axis     |"
    echo -e "\e[$((start_r+16));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+17));$((cols+2))H H - front     |"
    echo -e "\e[$((start_r+18));$((cols+2))H J - mid       |"
    echo -e "\e[$((start_r+19));$((cols+2))H K - back      |"
    echo -e "\e[$((start_r+20));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+21));$((cols+2))H   Cube rot.   |"
    echo -e "\e[$((start_r+22));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+23));$((cols+2))H R - horizontal|"
    echo -e "\e[$((start_r+24));$((cols+2))H F - vertical  |"
    echo -e "\e[$((start_r+25));$((cols+2))H V - z-axis    |"
    echo -e "\e[$((start_r+26));$((cols+2))H---------------+"
    echo -e "\e[$((start_r+27));$((cols+2))H Hold Shift -  |"
    echo -e "\e[$((start_r+28));$((cols+2))H rev. rotation |"
    echo -e "\e[$((start_r+29));$((cols+2))H S - random    |"
    echo -e "\e[$((start_r+30));$((cols+2))H shuffle       |"
    echo -e "\e[$((start_r+31));$((cols+2))H---------------+"
}

game ()
{
    cube_to_screen $draw_start_rows $draw_start_cols
    back_cube_to_screen $back_cube_draw_start_rows $back_cube_draw_start_cols
    print_screen
    print_controls
    #tput cup $(( rows+1 )) 0
    #debug_print_cube
}

set_pixel ()
{
	tput cup "$1" "$2"
	printf "%s" "$3"
}

set_cursor_below_game ()
{
	tput cup $(($rows+1)) 0
}

declare -r UNKNOWN="unknown"
# execute game loop, then sleep for REFRESH_TIME in a subshell and send SIGALRM to the current process
# thanks to the trap below it will trigger the game loop again
tick() {
    #while true
    #do
        tput cup 0 0
        if [[ "$key" != "$UNKNOWN" ]]; then
            handle_input "$key"
            key=$UNKNOWN
            game
        fi
        #read -rsn1 key
        ( sleep $REFRESH_TIME; kill -s ALRM $$ &> /dev/null )&
    #done
}

declare -r POSSIBLE_INPUTS_FOR_CUBE_ROTATION=( "top_wall_counter_clockwise_rotation" "top_wall_clockwise_rotation" "mid_wall_counter_clockwise_rotation" "mid_wall_clockwise_rotation" "bot_wall_counter_clockwise_rotation" "bot_wall_clockwise_rotation" "front_wall_left_col_down_rotation" "front_wall_left_col_up_rotation" "front_wall_mid_col_down_rotation" "front_wall_mid_col_up_rotation" "front_wall_right_col_down_rotation" "front_wall_counter_clockwise_rotation" "front_wall_clockwise_rotation" "front_wall_right_col_up_rotation" "right_wall_mid_col_down_rotation" "right_wall_mid_col_up_rotation" "back_wall_counter_clockwise_rotation" "back_wall_clockwise_rotation" )

shuffle() {
    for i in {1..50}
    do
        tput cup 0 0
        r=$((RANDOM % ${#POSSIBLE_INPUTS_FOR_CUBE_ROTATION[@]}))
        random_commnd=${POSSIBLE_INPUTS_FOR_CUBE_ROTATION[$r]}
        $random_commnd
        game
        sleep $REFRESH_TIME;
    done
    tput cup 0 0
}
trap tick ALRM

parse_args "$@"
clear_game_area_screen
reset_cube
#cube[$(( FRONT_Y+1 )),$(( FRONT_X+2))]=$WHITE
#print_screen
# start game
tick
#lecho $FRONT_WALL_CLOCKWISE_ROTATION
#echo $TOP_WALL_CLOCKWISE_ROTATION
#echo $TOP_WALL_COUNTER_CLOCKWISE_ROTATION
# poll for user input in loop
for (( ; ; ))
do
	read -rsn 1 key

done
