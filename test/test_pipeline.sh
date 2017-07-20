set -e 
set -u

workfolder="/groups/umcg-gaf/tmp04/"

cd ${workfolder}/tmp/
if [ -d ${workfolder}/tmp/NGS_DNA ]
then
	rm -rf ${workfolder}/tmp/NGS_DNA/
	echo "removed ${workfolder}/tmp/NGS_DNA/"
fi

echo "pr number: $1"

PULLREQUEST=$1

git clone https://github.com/molgenis/NGS_DNA.git
cd ${workfolder}/tmp/NGS_DNA

git fetch --tags --progress https://github.com/molgenis/NGS_DNA/ +refs/pull/*:refs/remotes/origin/pr/*
COMMIT=$(git rev-parse refs/remotes/origin/pr/$PULLREQUEST/merge^{commit})
echo "checkout commit: COMMIT"
git checkout -f ${COMMIT}

##Copy raw data
cp -r test/rawdata/MY_TEST_BAM_PROJECT/*.fq.gz ${workfolder}/rawdata/ngs/MY_TEST_BAM_PROJECT/

if [ -d ${workfolder}/generatedscripts/PlatinumSubset ] 
then
	rm -rf ${workfolder}/generatedscripts/PlatinumSubset/
fi

if [ -d ${workfolder}/projects/PlatinumSubset ] 
then
	rm -rf ${workfolder}/projects/PlatinumSubset/
fi

if [ -d ${workfolder}/tmp/PlatinumSubset ] 
then
	rm -rf ${workfolder}/tmp/PlatinumSubset/
fi

mkdir ${workfolder}/generatedscripts/PlatinumSubset/

### create testworkflow
cd ${workfolder}/tmp/NGS_DNA/
cp workflow.csv test_workflow.csv 
tail -1 workflow.csv | perl -p -e 's|,|\t|g' | awk '{print "Autotest,test/protocols/Autotest.sh,"$1}' >> test_workflow.csv

rm -f ${workfolder}/logs/PlatinumSubset.pipeline.finished
cp test/results/PlatinumSubset_True.final.vcf.gz /home/umcg-molgenis/NGS_DNA/PlatinumSubset_True.final.vcf.gz
cp test/results/PlatinumSample_NA12878_True.final.vcf.gz /home/umcg-molgenis/NGS_DNA/PlatinumSample_NA12878_True.final.vcf.gz
cp test/results/PlatinumSample_NA12891_True.final.vcf.gz /home/umcg-molgenis/NGS_DNA/PlatinumSample_NA12891_True.final.vcf.gz
cp generate_template.sh ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh

## Grep used version of molgenis compute out of the parameters file
fgrep "computeVersion," parameters.csv > ${workfolder}/generatedscripts/PlatinumSubset/mcVersion.txt

perl -pi -e 's|module load NGS_DNA/3.4.1|EBROOTNGS_DNA=/groups/umcg-gaf/tmp04/tmp/NGS_DNA/|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|PROJECT=projectXX|PROJECT=PlatinumSubset|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|RUNID=runXX|RUNID=run01|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|ngsversion=.*|ngsversion="test";\\|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|create_in-house_ngs_projects_workflow.csv|create_external_samples_ngs_projects_workflow.csv|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|sh \$EBROOTMOLGENISMINCOMPUTE/molgenis_compute.sh|module load Molgenis-Compute/dummy\nsh \$EBROOTMOLGENISMINCOMPUTE/molgenis_compute.sh|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e "s|module load Molgenis-Compute/dummy|module load Molgenis-Compute/\$mcVersion|" ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
perl -pi -e 's|WORKFLOW=\${EBROOTNGS_DNA}/workflow.csv|WORKFLOW=\${EBROOTNGS_DNA}/test_workflow.csv|' ${workfolder}/generatedscripts/PlatinumSubset/generate_template.sh
cp test/PlatinumSubset.csv ${workfolder}/generatedscripts/PlatinumSubset/

cd ${workfolder}/generatedscripts/PlatinumSubset/

sh generate_template.sh 

cd scripts
perl -pi -e 's|module load \"\${ngsversion}\"|EBROOTNGS_DNA=/groups/umcg-gaf/tmp04/tmp/NGS_DNA/\n#string computeVersion\nmodule load Molgenis-Compute/\${computeVersion}|' *.sh
sh submit.sh

cd ${workfolder}/projects/PlatinumSubset/run01/jobs/

perl -pi -e 's|--runDir ${tmpMantaDir}|--region 2:100000-500000 \\\n --runDir ${tmpMantaDir}|' s*_Manta_0.sh

for i in $(ls s*_CoverageCalculations*.sh); do touch $i.finished ; touch ${i%.*}.env; chmod 755 ${i%.*}.env ;done
for i in $(ls s*_Manta_1.sh); do touch $i.finished ; touch ${i%.*}.env; chmod 755 ${i%.*}.env ;done

## "gender cannot be determined for Male NA12891"
for i in $(ls s*_GenderCheck_1.sh); do touch $i.finished ; touch ${i%.*}.env; chmod 755 ${i%.*}.env ;done
for i in $(ls s*_GenderCalculate_1.sh); do touch $i.finished ; touch ${i%.*}.env; chmod 755 ${i%.*}.env ;done
printf "This is a male\n" > //groups/umcg-gaf//tmp04//tmp//PlatinumSubset/run01//PlatinumSample_NA12891.chosenSex.txt
printf "Male\n" >> //groups/umcg-gaf//tmp04//tmp//PlatinumSubset/run01//PlatinumSample_NA12891.chosenSex.txt
perl -pi -e 's|module load test|EBROOTNGS_DNA=/groups/umcg-gaf/tmp04/tmp/NGS_DNA/|' s*_QCStats_*.sh  
perl -pi -e 's|module load test|EBROOTNGS_DNA=/groups/umcg-gaf/tmp04/tmp/NGS_DNA/|' s*_DecisionTree_*.sh  
perl -pi -e 's|module load test|#|' s*_QCReport_0.sh
perl -pi -e 's|countShScripts-3\)\)|countShScripts-4))|' s*_CountAllFinishedFiles_0.sh
perl -pi -e 's|--time=16:00:00|--time=05:59:00|' *.sh
perl -pi -e 's|--time=23:59:00|--time=05:59:00|' *.sh

sh submit.sh --qos=dev

count=0
minutes=0
while [ ! -f /groups/umcg-gaf/tmp04/projects/PlatinumSubset/run01/jobs/Autotest_0.sh.finished ]
do

        echo "not finished in $minutes minutes, sleeping for 1 minute"
        sleep 60
        minutes=$((minutes+1))

        count=$((count+1))
        if [ $count -eq 60 ]
        then
                echo "the test was not finished within 1 hour, let's kill it"
		echo -e "\n"
		for i in $(ls /groups/umcg-gaf/tmp04/projects/PlatinumSubset/run01/jobs/*.sh)
		do
			if [ ! -f $i.finished ]
			then
				echo "$(basename $i) is not finished"
			fi
		done		
                exit 1
        fi
done
echo ""
echo "Test succeeded!"
echo ""

