# writing the command to run dimsum for quick port/test in HPC

# save the WT sequence to a file and load it 


DiMSum --fastqFileDir ../data/ --experimentDesignPath experimentDesign.txt --wildtypeSequence "$(cat wildtype.txt)"
