#!/bin/bash
prompt="Select usb to serial port:"
options=( $(find /dev/*usbserial* | xargs -0) )

PS3="$prompt "
echo ""
select opt1 in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "Selected usb to serial: $opt1"
        break

    else
        echo "Invalid option. Try another one."
    fi
done

prompt="Select hex file:"
options=( $(find *.hex | xargs -0) )

PS3="$prompt "
echo ""
select opt2 in "${options[@]}" "Quit" ; do 
    if (( REPLY == 1 + ${#options[@]} )) ; then
        exit

    elif (( REPLY > 0 && REPLY <= ${#options[@]} )) ; then
        echo  "Selected hex file: $opt2"
        ./ISPN76E003 -r -p$opt1 $opt2
        break

    else
        echo "Invalid option. Try another one."
    fi
done

echo ""
