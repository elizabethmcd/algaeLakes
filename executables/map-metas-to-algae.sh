#! /bin/bash

# Run mapping of short metagenomic reads to reference algae genome

# directory setup
mkdir metagenomes
mkdir refs
mkdir mappingResults

# programs
tar -xvzf BBMap_38.07.tar.gz
tar -xvzf samtools.tar.gz
tar -xzvf python.tar.gz

# python
mkdir home
export PATH=$(pwd)/python/bin:$PATH
export HOME=$(pwd)/home
chmod u+x *.py

# copy over files
ref=$1
meta=$2
outname=$3
refbase=$(basename $ref)
metabase=$(basename $meta)
refname=$(basename $ref .fna)
metarun=$(basename $metabase .tgz)
metaname=$(basename $metarun .mum.QCed.fastq)
cp $1 refs/
cp $2 metagenomes/
cd metagenomes/
tar -xzvf $metabase
cd ../

# Perform mapping
bbmap/bbmap.sh ref=refs/$refbase in=metagenomes/$metarun outm=$outname idtag minid=0.50 nodisk -Xmx48g

# Sorted BAM files
for file in mappingResults/*.bam; do
    outsort=$(basename $file .fastq.bam).sorted.bam;
    ./samtools/bin/samtools sort $file -o mappingResults/$outsort;
done

# Get depth
for file in mappingResults/*.sorted.bam; do
    outdepth=$(basename $file .sorted.bam).depth;
    ./samtools/bin/samtools depth $file > mappingResults/$outdepth;
done

# Sorted, indexed BAM file
for file in mappingResults/*.sorted.bam; do
    ./samtools/bin/samtools index $file;
done

# Reference lengths file
for file in refs/*.fna; do
    python countBases.py $file;
done
cat refs/*.len > refGenomes.len

# Metagenomic reads file
for file in metagenomes/*.fastq; do
    awk '{s++}END{print FILENAME,s/4}' $file >> metaReads.txt;
done

# Create stats file
for file in mappingResults/*.depth; do
    python calc-mapping-stats.py $file;
done

# Bring back statistics and the BAM files with sorted/indexed BAM file, put into one directory, and zip to Gluster
mkdir $refname-vs-$metaname
mv *.coverage.txt $refname-vs-$metaname/
mv mappingResults/*.sorted.bam $refname-vs-$metaname/
mv mappingResults/*.sorted.bam.bai $refname-vs-$metaname/
tar -cvzf $refname-vs-$metaname.tar.gz $refname-vs-$metaname/
cp $refname-vs-$metaname.tar.gz /mnt/gluster/emcdaniel/algae/.

rm -rf refs/
rm -rf metagenomes/
rm -rf mappingResults/
rm *.txt
rm *py
