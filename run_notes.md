
# Params to change
(done on 17/Sep/26) 
- `--indels 'all'` : retains indels otherwise discarded by default
- `--maxSubstitutions 25` : increase from the default of 2; arbitrary 25. 
- `--sequenceType "noncoding"` : defaults to auto looking for premature stop codons, but let's set this

## Used options
- `--stranded F` : adjusts for strands that are reverse 

---
# Run notes ---

# 17/Sep/26 : with permissive filtering, low memory optimizations

## Lokya's reruns

### (failed) Rerun lokya's data starting at stage 4: 
- overwrites old files so saving the table, PDFs, and report.html in a side folder in sharepoint for backup.
- [x] Check if this works or if starting from stage 4 requires fastq files pointed in the results dir instead. Can write a switch for this.
_all stuff was pending so suspicious_
  - Fails, file names after cutadapt are different; 
```sh
./2_trim/GS2555NNNCM25uMpassedLib_R2_001.fastq.gz.cutadapt1-forward.fastq.gz
./2_trim/GS2556NNNCM50uMpassedLib_R2_001.fastq.gz.cutadapt.untrimmed.fastq.gz
./2_trim/GS2592NNNCM25uMNoTheoLib_R1_001.fastq.gz.cutadapt1-forward.fastq.gz
./2_trim/GS2553NNNCMInputLib_R2_001.fastq.gz.cutadapt.untrimmed.fastq.gz
./2_trim/GS2592NNNCM25uMNoTheoLib_R2_001.fastq.gz.cutadapt1-reverse.fastq.gz
./2_trim/GS2556NNNCM50uMpassedLib_R1_001.fastq.gz.cutadapt1-forward.fastq.gz
```


## NNN

sbatch slurm_dimsum.sh theoAptzNNN_lokya
- [x] (*completed*) Submitted batch job 32677190
- [ ] reupload html files

sbatch slurm_dimsum.sh theoAptzNNN_lokya -- --startStage 4
- [x] Submitted batch job 32676881 : failed: file not found


## epPCR 
same, completed without the start stage. 

sbatch slurm_dimsum.sh theoAptzepPCR_lokya -- --startStage 4
Submitted batch job 32676884


## 3R5 madison (*to-fix)
sbatch slurm_dimsum.sh 3R5library_madison
Submitted batch job 32673400
- went OOM on 5 segments after `Filtering aligned reads...` stage in the `dimsum_stage_vsearch.R` script (presumably, since that was the last `_message`

## 4NCM, madison
madison: 4NCM : merge Ls into R
- No real need to trasnfer data: it's just single file so took the long time to just rename the files ; 
  - transfer data from : /scratch/alpine/c838573989@colostate.edu/data_staging/4NCMLibrary_madison/ to .. projets/data
  - rclone transfer to sharepoint for backup
- For future reproducibility, you can do either;
  - reset the config/.txt to use the old Lx filenames ; and add a switch to to correct file format `--fastqFileExtension ".fq"`
  - Add a quick helper script to rename the files

## demo 
sbatch slurm_dimsum.sh
Submitted batch job 32663965
----

# 16/Sep/26: 



## sbatch slurm_dimsum.sh 3R5library_madison
_what happened here?_
---

## sbatch slurm_dimsum.sh 4NCMLibrary_madison
error: due to file extension being `.fq`



---
## sbatch slurm_dimsum.sh theoAptzepPCR_lokya
squeue -j 32625752


--------
## sbatch slurm_dimsum.sh theoAptzNNN_lokya --section copy
- Run : 32622941.out
- variant python run with partial failed rclone: 32624519.out
- redo rclone copy: 32627078.out


