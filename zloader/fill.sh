#!/bin/bash
LANG=C
FILEIN=gzrom-dtb.bin
FILEOUT=flash.bin
TARGET_SIZE=1048576
FILESIZE=$(stat -c%s "$FILEIN")
val=`expr $TARGET_SIZE - $FILESIZE`
echo $TARGET_SIZE
echo $FILESIZE
cp $FILEIN $FILEOUT
dd if=<(yes $'\xFF' | tr -d "\n") bs=1 count=$val >> $FILEOUT
