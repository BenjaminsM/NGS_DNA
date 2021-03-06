#Parameter mapping
#string tmpName


#string intermediateDir
#string project
#string logsDir
#string groupname
#string gatkVersion
#string gatkJar
#string indexFile
#string capturedIntervals
#string projectVariantsMergedSortedGz
#string sampleVariantsMergedSnpsVcf
#string sampleVariantsMergedIndelsVcf
#string externalSampleID


module load "${gatkVersion}"

makeTmpDir "${sampleVariantsMergedIndelsVcf}"
tmpSampleVariantsMergedIndelsVcf="${MC_tmpFile}"

makeTmpDir "${sampleVariantsMergedSnpsVcf}"
tmpSampleVariantsMergedSnpsVcf="${MC_tmpFile}"

#select only Indels
java -XX:ParallelGCThreads=1 -Xmx5g -jar "${EBROOTGATK}/${gatkJar}" \
-R "${indexFile}" \
-T SelectVariants \
--variant "${projectVariantsMergedSortedGz}" \
-o "${tmpSampleVariantsMergedIndelsVcf}" \
--selectTypeToInclude INDEL \
-sn "${externalSampleID}"

mv "${tmpSampleVariantsMergedIndelsVcf}" "${sampleVariantsMergedIndelsVcf}"
echo "moved ${tmpSampleVariantsMergedIndelsVcf} to ${sampleVariantsMergedIndelsVcf}"

#Select SNPs and MNPs
java -XX:ParallelGCThreads=1 -Xmx5g -jar "${EBROOTGATK}/${gatkJar}" \
-R "${indexFile}" \
-T SelectVariants \
--variant "${projectVariantsMergedSortedGz}" \
-o "${tmpSampleVariantsMergedSnpsVcf}" \
--selectTypeToExclude INDEL \
-sn "${externalSampleID}"

mv "${tmpSampleVariantsMergedSnpsVcf}" "${sampleVariantsMergedSnpsVcf}"
echo "moved ${tmpSampleVariantsMergedSnpsVcf} to ${sampleVariantsMergedSnpsVcf}"
