#!/usr/bin/env python 
import subprocess

input1List = ['s02','s03','s04','s05','s06','s07','s08']
input2List = ['Baseline','Followup']
input3List = ['ffs','tfs','fts','ftc']

for input1 in input1List:
    for input2 in input2List:
		for input3 in input3List:
			sbatch_command = """sbatch --job-name={}_{}_{} --export=INPUT1={},INPUT2={},INPUT3={} submit_simulation.slurm""".format(input1,input2,input3,input1,input2,input3)
			print(sbatch_command)
			# Comment the following 3 lines when testing to prevent jobs from being submitted	
			# exit_status = subprocess.call(sbatch_command, shell=True)
			# if exit_status == 1:
			#	print("Job {0} failed to submit".format(sbatch_command))
            
print("Done submitting jobs!")
