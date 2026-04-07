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

# remove highlighted terminal cursor
tput civis
# reset to normal on exit
trap 'tput cnorm;' EXIT
# reset to normal on exit and clean screen on SIGINT (Ctrl-C)
trap 'tput cnorm; clear; exit;' SIGINT

# declare default options
declare -i cols=50
declare -i rows=25
X_TIME=0.1
Y_TIME=0.14
REFRESH_TIME=$X_TIME

# holds a screen matrix in an associative array
declare -A screen
# holds a cube matrix in an associative array
declare -A cube

declare -i draw_start_cols=cols/3
declare -i draw_start_rows=rows/3

# key input from user
key=""

# constants
declare -r EMPTY=" "
declare -r ARROW_UP="A"
declare -r ARROW_DOWN="B"
declare -r ARROW_RIGHT="C"
declare -r ARROW_LEFT="D"
declare -r HORIZONTAL_BAR="-"
declare -r VERTICAL_BAR="|"
declare -r CORNER_ICON="\e[41m \e[0m"
declare -r WHITE_TEXT="\e[37m"
declare -r RED_TEXT="\e[31m"
declare -r GREEN_TEXT="\e[32m"
declare -r YELLOW_TEXT="\e[33m"
declare -r BLUE_TEXT="\e[34m"
declare -r PINK_TEXT="\e[35m"
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
	if [[ "$1" = "$ARROW_UP" ]]; then
		if (( vel_y != 1 )); then
			vel_x=0
			vel_y=-1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$ARROW_DOWN" ]]; then
		if (( vel_y != -1 )); then
			vel_x=0
			vel_y=1
			REFRESH_TIME=$Y_TIME
		fi
	elif [[ "$1" = "$ARROW_RIGHT" ]]; then
        top_wall_clockwise_rotation
	elif [[ "$1" = "$ARROW_LEFT" ]]; then
        top_wall_counter_clockwise_rotation
	else
		:
	fi
}
declare -i LEFT_Y=${N_CUBE}
declare -i LEFT_X=0
declare -i FRONT_Y=${N_CUBE}
declare -i FRONT_X=$(( 1*${N_CUBE} ))
declare -i RIGHT_Y=${N_CUBE}
declare -i RIGHT_X=$(( 2*${N_CUBE} ))
declare -i BACK_Y=${N_CUBE}
declare -i BACK_X=$(( 3*${N_CUBE} ))
declare -i TOP_Y=0
declare -i TOP_X=0
declare -i BOT_Y=$(( 2*${N_CUBE} ))
declare -i BOT_X=0

declare -r BLUE="BLUE"
declare -r GREEN="GREEN"
declare -r WHITE="WHITE"
declare -r YELLOW="YELLOW"
declare -r RED="RED"
declare -r PINK="PINK"
declare -A STARTING_COLORS=( $BLUE $GREEN $WHITE $YELLOW $RED $PING)
declare -A COLOR_MAPPING=( [$BLUE]=$BLUE_FULL [$GREEN]=$GREEN_FULL [$WHITE]=$WHITE_FULL [$YELLOW]=$YELLOW_FULL [$RED]=$RED_FULL [$PINK]=$PINK_FULL )


set_color_to_wall_on_cube()
{
    start_x=$1
    start_y=$2
    color=$3
	for (( x=start_x;x<start_x+N_CUBE;x++ )); do
        for (( y=start_y;y<start_y+N_CUBE;y++ )); do
			cube[$y,$x]=$color
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
    first_array_of_points=${arrays_of_points[0]}
    #echo "first_array_of_points=$first_array_of_points"
    copy_of_first_array_of_values=()
    copy_values_from_2d_map_to_array map_of_values copy_of_first_array_of_values $first_array_of_points 
    #echo "copy_of_first_array_of_values=${copy_of_first_array_of_values[@]}"
    copy_values_from_points_to_points_in_2d_map map_of_values arrays_of_points[3] arrays_of_points[0] 
    copy_values_from_points_to_points_in_2d_map map_of_values arrays_of_points[2] arrays_of_points[3] 
    copy_values_from_points_to_points_in_2d_map map_of_values arrays_of_points[1] arrays_of_points[2] 
    set_value_from_array_to_2d_map map_of_values copy_of_first_array_of_values ${arrays_of_points[1]}
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
        value=${local_map_of_values[$y,$x]}
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
        source_value=${local_map_of_values[$source_y,$source_x]}
        target_value=${local_map_of_values[$target_y,$target_x]}
        #echo "source_x=$source_x, source_y=$source_y, i=$i, target_x=$target_x, target_y=$target_y source_alue=$source_value target_value=$target_value"
        local_map_of_values[$target_y,$target_x]=$source_value
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
        value_before=${local_map_of_values[$y,$x]}
        value_to_set=${values[$i]}
        #echo "setting value x=$x, y=$y, i=$i, value_before=$value_before,value_to_set=$value_to_set"
        local_map_of_values[$y,$x]=$value_to_set
        i=$((i+1))
    done
}

reset_cube()
{
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
            row_shift=$(( $row_shift_each_y*(x-wall_cube_x) ))
        for (( y=wall_cube_y;y<wall_cube_y+N_CUBE;y++ )); do
			color=${cube[$y,$x]}
            color_from_mapping=${COLOR_MAPPING[$color]}
            col_shift=$(( $col_shift_each_x*(y-wall_cube_y) ))
            start_rows=$(( row_shift+wall_start_row+(y-wall_cube_y)*wall_rows_size))
            start_cols=$(( col_shift+wall_start_cols+(x-wall_cube_x)*wall_cols_size))
            color_to_set=$color_from_mapping
            if (( (y-wall_cube_y) % 2 == 1 )); then
                if (( (x-wall_cube_x) % 2 == 1 )); then
                    color_to_set=$DIM$color_from_mapping
                fi
            else 
                if (( (x-wall_cube_x) % 2 == 0 )); then
                    color_to_set=$DIM$color_from_mapping
                fi
            fi
            $draw_method $start_rows $start_cols $color_to_set
		done
	done
    
}

cube_to_screen()
{
    front_row=$1
    front_col=$2

    wall_to_screen draw_front_square $front_row $front_col $FRONT_X $FRONT_Y $FRONT_SQUARE_ROWS_SIZE $FRONT_SQUARE_COLS_SIZE 0 0
    
    right_wall_row=$(( $front_row ))
    right_wall_col=$(( $front_col + FRONT_SQUARE_COLS_SIZE*N_CUBE ))
    wall_to_screen draw_diag_right_square $right_wall_row $right_wall_col $RIGHT_X $RIGHT_Y $RIGHT_SQUARE_ROWS_SIZE $RIGHT_SQUARE_COLS_SIZE -2 0

    top_wall_row=$(( $front_row - TOP_SQUARE_ROWS_SIZE*N_CUBE  ))
    top_wall_col=$(( $front_col + RIGHT_SQUARE_COLS_SIZE*N_CUBE - 1 ))
    wall_to_screen draw_diag_top_square $top_wall_row $top_wall_col $TOP_X $TOP_Y $TOP_SQUARE_ROWS_SIZE $TOP_SQUARE_COLS_SIZE 0 -3
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
            start_x=$((x+i))
            #echo "start_x=$start_x"
            sequence="${sequence}${start_x},${y}_"
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
    for i in {0..2}
    do
        start_y=$((wall_top_left_y+i))
        sequence="${sequence}${wall_top_left_x},${start_y}_"
    done
    sequence="${sequence};"
    echo $sequence
}


TOP_WALL_CLOCKWISE_ROTATION=$(same_wall_rotation_seq_clockwise ${TOP_X} ${TOP_Y})
TOP_ROW_FRONT_LEFT_ROTATION=$(horizontal_rotation_seq "${FRONT_X},${FRONT_Y} ${LEFT_X},${LEFT_Y} ${BACK_X},${BACK_Y} ${RIGHT_X},${RIGHT_Y}")

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

game ()
{
    cube_to_screen $draw_start_rows $draw_start_cols
    print_screen
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

# execute game loop, then sleep for REFRESH_TIME in a subshell and send SIGALRM to the current process
# thanks to the trap below it will trigger the game loop again
tick() {
	tput cup 0 0
	handle_input "$key"
    key="unknown"
	game
	( sleep $REFRESH_TIME; kill -s ALRM $$ &> /dev/null )&
}
trap tick ALRM

parse_args "$@"
clear_game_area_screen
reset_cube
#print_screen
# start game
tick
# poll for user input in loop
for (( ; ; ))
do
	read -rsn 1 key
done
