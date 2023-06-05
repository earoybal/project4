#!/bin/bash

#checking to make sure correct # of arguments given
if [ $# -ne 1 ]
then
    printf "Incorrect number of arguments given. Use format ./seqcheck.sh bpp_file . Where bpp_file is in bpp/phylip format.\n"
    exit
fi

#checking file location to see if it is PWD
fileexist="$(find -maxdepth 1 -name $1 -type f | wc -m)"
if [ $fileexist -ge 1 ]
then

#checking to see if headers have both sequence number and base number
#only works if all headers lack both seq number and base number unfortunately
headerformatcheck="$(cat $1 | grep -Eo '[[:digit:]]+[[:space:]]{1}[[:digit:]]+' | wc -m)"
if [ $headerformatcheck > 0 ]
   then
    
#pattern that will be used to pull out headers
head_pattern='[[:digit:]]+[[:space:]]{1}[[:digit:]]+[[:space:]]{1}[[:digit:]]+'

#getting headers along with their line number
header="$(cat -n $1 | grep -E $head_pattern)"

#adding extra line at end of header so that all loci have a difference of 2 lines between end of sequences and next header lines
extraendline=$(($(cat $1 | wc -l)+1))
header+="\n$extraendline 0 0\n"
printf "$header" > header.txt #assigning it to a file because quotes were getting messy and weird

#for loop to get each loci
for ((i=1;i<$(cat header.txt | wc -l);i++)) #header contains list of line #, seq count, and base count in addition to a dummy line. Using header to iterate b/c its line count it related to loci count.
do
    #this occurs for each loci. Grabs the start and end line of each block of sequences using information from header and cuts them out using awk
    #once again, outputting to a text file to not deal with the weirdness of quotes
    awk -vstart="$(($(cat header.txt | awk -vinit="$i" 'NR==init { print $1 }')+2))" -vend="$(($(cat header.txt | awk -ven="$(($i+1))" 'NR==en { print $1 }')-2))" 'NR>=start && NR<=end { print $0 }' $1 > loci$i.txt
done

#chunk of code that will do all of the seq and base checking
for ((i=1;i<$(cat header.txt | wc -l);i++)) #using header again for the iterator as it will be going through each loci
do
    #checking each loci to see if header sequence count matches what is actually there.
    if [ $(cat loci$i.txt | wc -l) -eq $(cat header.txt | awk -vrow=$i 'NR==row { print $2 }') ]
    then
	printf "Locus $i: no_seqs $(cat header.txt | awk -vrow=$i 'NR==row { print $2 }') matched observed. "
    else
	printf "Locus $i: no_seqs $(cat header.txt | awk -vrow=$i 'NR==row { print $2 }') did not match observed $(cat loci$i.txt | wc -l)"
    fi

    #defining seq_count outside of next for loop as for each loci seq_count will be notched up by 1 for every sequence that has correct number of bases. If at the end of each for loop for each loci seq_count=# of sequences then it is assumed that every sequence had the correct number of bases and output will make that clear.
    seq_count=0

    # this for loop is where # of bases for each sequence is checked
    #ran for each sequence in each loci due to root for loop iterating through each loci
    for ((k=1;k<=$(cat loci$i.txt | wc -l);k++)) #using num of rows in loci to set stop point this time as going over that would be bad
    do
	#for each sequence a file is created that stores the observed # of bases and the expected # of bases.
	printf "$(($(cat loci$i.txt | awk -vline=$k 'NR==line { print $2 }' | wc -m | grep -Eo '[[:digit:]]+')-2))" > obsloci$i$k.txt #observed
	printf "$(cat header.txt | awk -vline=$i 'NR==line { print $3 }' | grep -Eo '[[:digit:]]+')" > exploci$i$k.txt #expected

	#if statement to determine what path to take for each sequence. If sequence has correct num of bases, seq_count is notched up by one. If incorrect then statement giving sequence id and base count is printed.
	if [ $(cat obsloci$i$k.txt) -eq $(cat exploci$i$k.txt) ]
	then
	    seq_count=$(($seq_count+1)) #notching up seq_count
	else
	    #each sequence that didn't match will be printed out, not just one
	    printf "Sequence $(cat loci$i.txt | awk -vseqline=$k 'NR==seqline { print $1 }'): no_sites $(cat exploci$i$k.txt) did not match observed $(cat obsloci$i$k.txt). "
	fi
    done

    #before going to next locus, checking to see if every sequence has the correct num of bases by comparing num of correct sequences to overall num of sequences. If equal then print statement saying exp=obs.
    if [ $seq_count -eq $(cat header.txt | awk -vrow=$i 'NR==row { print $2 }') ]
    then
	printf "no_sites $(cat header.txt | awk -vrow=$i 'NR==row { print $3 }' | grep -Eo '[[:digit:]]+') matched observed."
    fi
    printf "\n"
done

#removing all of the files that I created
rm header.txt
rm loci*.txt
rm exploci*.txt
rm obsloci*.txt

else
    #end of header format check
    printf "Loci headers are not in the correct format. Please include number of sequences for each loci and number of bases in the sequences for each loci in format: num_seq num_base.\n"
fi
    
else
    #end of file existence check
    #result printed to stdout if file isn't in pwd
    printf "File not found. Please place in present working directory.\n"
fi
