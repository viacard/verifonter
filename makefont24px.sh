#!/bin/bash

WORKFILE=$1.4096
TMPFILE=$1.tmp
HEXFILE=$1.hex
OUTFILE=$1.vfo

function ColVal()  {
	echo $(cat $WORKFILE | cut -c$1 | sort | uniq | tr -dc '01')
}

# Create a textfile with 4096 chars on each line from the pbm for easier scanning
cat $1.pbm | sed '1,3d' | tr -dc '01'| fold -w 4096 > $WORKFILE
cp -f /dev/null $TMPFILE

# Start scanning from the first column in the image
startcol=1

# Create data for all the first 128 ASCII characters
for (( ascii=0; ascii<128; ascii++ )) 
do

  # Find first column with data starting from 'startcol'
  for (( col=$startcol; col<4096; col++ ))
  do
     v1=$(ColVal $col)
     if [ "$v1" -ne "0" ]; then break; fi
  done
  startcol=$col
  thischar=$col
  thischarlast=$((thischar+24))   

  # Display progress
  printf 'Expanding columns for character=%d/128 Reading at column=%d\r' "$ascii" "$col" >&2 

  #Concatenate column by column until four empty columns are found
  for (( col=thischar; col<$thischarlast; col++  ))
  do 
          col2=$((col+1))
          col3=$((col+2))
          col4=$((col+3))
          v1=$(ColVal $col)
          v2=$(ColVal $col2)
          v3=$(ColVal $col3)
          v4=$(ColVal $col4)
          if [ "$v1$v2$v3$v4" -eq "0000" ]; then break; fi
          cat $WORKFILE | cut -c$col > /tmp/tmp1
          if [[ -s $TMPFILE ]]; then
                  paste -d \\0 $TMPFILE /tmp/tmp1 > /tmp/tmp2
                  cp /tmp/tmp2 $TMPFILE
          else
                  cp /tmp/tmp1 CalibriLight20.24
          fi
  done

  #Fill up with more empty columns to get 24 pixels wide character
  printf "0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n0\n" > /tmp/tmp1
  for (( dummycol=$col; dummycol<$thischarlast; dummycol++ ))
  do
          paste -d \\0 $TMPFILE /tmp/tmp1 > /tmp/tmp2
          cp /tmp/tmp2 $TMPFILE
	  printf "1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n1\n" > /tmp/tmp1
  done

  startcol=$col

done #ascii
printf '\r\n'


# Scan 3 bytes vertically and convert to hex into a file, repeat 3072 times
cp -f /dev/null $HEXFILE
col=1
while true
do
	b1=$(cat $TMPFILE | cut -c$col | head -8 | tr -dc '01')
	b2=$(cat $TMPFILE | cut -c$col | head -16 | tail -8 | tr -dc '01')
	b3=$(cat $TMPFILE | cut -c$col | tail -8 | tr -dc '01')
	if [ "$b1$b2$b3" == "" ]; then break; fi
	printf '%02x %02x %02x\n' "$((2#$b1))" "$((2#$b2))" "$((2#$b3))" >> $HEXFILE
	col=$((col+1))
	if [ "$((col%24))" == "0" ];then >&2 printf 'Converting image data for character %d/128\r' $(($col/24)); fi
done
printf '\r\n'

#convert hex file to the font data file
cat $HEXFILE | xxd -r -p > $OUTFILE
printf "Created $OUTFILE\r\n"

rm -f $WORKFILE $TMPFILE $HEXFILE
