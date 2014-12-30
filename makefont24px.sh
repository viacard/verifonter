#!/bin/bash

WORKFILE=$1.4096
TMPFILE=$1.tmp
HEXFILE=$1.hex
OUTFILE=$1.vfo

CHARWIDTH=24
IMAGEWIDTH=4096

function ColVal()  {
	echo $(cat $WORKFILE | cut -c$1 | sort | uniq | tr -dc '01')
}

# Create a textfile with 4096 chars on each line from the pbm for easier scanning
cat $1.pbm | sed '1,3d' | tr -dc '01'| fold -w $IMAGEWIDTH > $WORKFILE
cp -f /dev/null $TMPFILE

# Start scanning from the first column in the image
startcol=1

# Create data for all the first 128 ASCII characters
for (( ascii=0; ascii<128; ascii++ )) 
do

  # Find first column with data starting from 'startcol'
  for (( col=$startcol; col<=IMAGEWIDTH; col++ ))
  do
     v1=$(ColVal $col)
     if [ "$v1" -ne "0" ]; then break; fi
  done
  startcol=$col
  thischar=$col
  thischarlast=$(($thischar+$CHARWIDTH))   

  # Display progress
  printf 'Expanding columns for character=%d/128 Reading at column=%d\r' "$ascii" "$col" >&2 

  #Concatenate column by column until four empty columns are found
  for (( col=thischar; col<$thischarlast; col++  ))
  do 
          cv1=$(ColVal $col)
          cv2=$(ColVal $((col+1)))
          cv3=$(ColVal $((col+2)))
          cv4=$(ColVal $((col+3)))
          if [ "$cv1$cv2$cv3$cv4" -eq "0000" ]; then break; fi
          cat $WORKFILE | cut -c$col > /tmp/tmp1
          if [[ -s $TMPFILE ]]; then
                  paste -d \\0 $TMPFILE /tmp/tmp1 > /tmp/tmp2
                  cp /tmp/tmp2 $TMPFILE
          else
                  cp /tmp/tmp1 $TMPFILE
          fi
  done

  #Fill up with more empty filler columns to get a 24 pixels wide character
  printf "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n" > /tmp/tmp1
  for (( fillercol=$col; fillercol<$thischarlast; fillercol++ ))
  do
          paste -d \\0 $TMPFILE /tmp/tmp1 > /tmp/tmp2
          cp /tmp/tmp2 $TMPFILE
	  printf "1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n" > /tmp/tmp1
  done

  startcol=$col

done #ascii
printf '                                                                                                     \r'


# Scan 3 bytes vertically and convert to hex into a file, repeat until all characters are processed
cp -f /dev/null $HEXFILE
col=1
while true
do
	byte1=$(cat $TMPFILE | cut -c$col | head -8 | tr -dc '01' | rev)
	byte2=$(cat $TMPFILE | cut -c$col | head -16 | tail -8 | tr -dc '01' | rev)
	byte3=$(cat $TMPFILE | cut -c$col | tail -8 | tr -dc '01' | rev)
	# break out if all coluns are processed
	if [ "$byte1$byte2$byte3" == "" ]; then break; fi
	# if only the bottommost pixel is set then this is the space character
	if [ "$byte1$byte2$byte3" == "000000000000000010000000" ]; then byte3="00000000"; fi
	printf '%02x %02x %02x\n' "$((2#$byte1))" "$((2#$byte2))" "$((2#$byte3))" >> $HEXFILE
	col=$((col+1))
	if [ "$(($col%$CHARWIDTH))" == "0" ];then >&2 printf 'Converting image data for character %d/128\r' $(($col/$CHARWIDTH)); fi
done
printf '                                                                                                     \r'

#convert hex file to the font data file
cat $HEXFILE | xxd -r -p > $OUTFILE
printf "Created $OUTFILE\r\n"

rm -f $WORKFILE $TMPFILE $HEXFILE
