#!/bin/bash

yacc -d -y --debug --verbose 22201884.y
echo 'Generated the parser C file as well the header file'
g++ -w -c -o y.o y.tab.c
echo 'Generated the parser object file'
flex 22201884.l
echo 'Generated the scanner C file'
g++ -fpermissive -w -c -o l.o lex.yy.c
# if the above command doesn't work try g++ -fpermissive -w -c -o l.o lex.yy.c
echo 'Generated the scanner object file'
g++ y.o l.o
echo 'All ready, running'
./a.exe 22201884_input.c
echo 'logfile'
cat 22201884_log.txt
echo 'errorfile'
cat 22201884_error.txt
