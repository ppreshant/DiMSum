
# Params to change
(done on 17/Sep/26) 

## Permissive filtering
- [x] `--indels 'all'` : retains indels otherwise discarded by default
- [x] `--maxSubstitutions 25` : increase from the default of 2; arbitrary 25. 
- [x] `--sequenceType "noncoding"` : defaults to auto looking for premature stop codons, but let's set this
## Memory issues/restart
- [x] use `--retainIntermediateFiles=T` to enable rerun from stage 3 for example when OOM killed. 
	- [ ] *beware of large files in the `tmp/` dir ~* need to somehow identify remove before rclone transfer
	- Cleanup notes from GH Copilot
		> With `--retainIntermediateFiles=F`, DiMSum deletes staged intermediate files like:
		- `/tmp/2_trim/*.{fastq,cutadapt.gz,cutadapt2.gz}`
		- `/tmp/3_align/*.{vsearch.gz,vsearch.prefilter.gz}`
		- `/tmp/3_tally/*.{vsearch.gz,unique}`
		- plus some demultiplex/unzip temporary FASTQ files in `tmp/0_demultiplex`-style paths.
	> 	Quick command to find 
	```sh
	find /home/runner/work/DiMSum/DiMSum/<outputPath>/<projectName>/tmp -type f \
	\( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.cutadapt.gz" -o -name "*.cutadapt2.gz" -o -name "*.vsearch.gz" -o -name "*.vsearch.prefilter.gz" -o -name "*.unique" \)
	```
- [ ] Reduce `--numCores` to 1 says Claude. _Runs longer but will use full 30GB so not OOM issue/memory starving. 
	- [x] *can try 3 for starters?*
- Notes from Claude AI: **Suggested order:**
	1. `numCores=1` with your current `yield_size` — quick test, no code changes needed elsewhere.
	2. If still OOM, then try `yield_size=1e3` (know that runtime overhead compounds fast at this level — each chunk has fixed overhead, so 1e3 chunk size could mean 100x more chunks than 1e5).
	3. If both combined still OOM, that's a strong signal your per-read memory footprint itself is unusually large (e.g., very long reads/amplicons, or a `ShortRead`/quality-matrix scaling issue) rather than a chunking problem — move to high-mem nodes at that point rather than going lower on `yield_size`.

## Used options
- `--stranded F` : adjusts for strands that are reverse (_happens with amplicons where 2nd PCR is not in a specific direction while adding indexes?_ ) 
	- Added this since I noticed a WT read in reverse orientation initially at similar abundance as the correct orientation!

---
# Run notes ---

# 17/Sep/26 : with permissive filtering, low memory optimizations

## Lokya's reruns

- [x] rerun full workflow (see below)
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
(_unnecessary_) madison: 4NCM : merge Ls into R
- No real need to trasnfer data: it's just single file so took the long time to just rename the files ; 
	- transfer data from : /scratch/alpine/c838573989@colostate.edu/data_staging/4NCMLibrary_madison/ to .. projets/data
	- rclone transfer to sharepoint for backup
- For future reproducibility, you can do either;
	- reset the config/.txt to use the old Lx filenames ; and add a switch to to correct file format `--fastqFileExtension ".fq"`
	- Add a quick helper script to rename the files

- [ ] Run stuff: (*failed*) Got OOM killed again 

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


