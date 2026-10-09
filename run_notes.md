
# Params to make it work!
(done on 17/Sep/26) 

## Strict filtering/analysis/5
- [x] `--fitnessMinInputCountAll=2` remove singletons to reduce spurious variants. *This may not affect the table we see which seems to be before the stage 5?*
## Permissive filtering
- [x] `--indels 'all'` : retains indels otherwise discarded by default
- [x] `--maxSubstitutions 25` : increase from the default of 2; arbitrary 25. 
- [x] `--sequenceType "noncoding"` : defaults to auto looking for premature stop codons, but let's set this
## Memory issues/restart
- [x] use `--retainIntermediateFiles=T` to enable rerun from stage 3 for example when OOM killed. 
	- [x] *beware of large files in the `tmp/` dir ~* need to somehow identify remove before rclone transfer. _Jumps up from 11 GB (epPCR_lokya) to 26 GB (4NCM_madison) with this option_
	- Cleanup notes from GH Copilot
		> With `--retainIntermediateFiles=F`, DiMSum deletes staged intermediate files like:
		- `/tmp/2_trim/*.{fastq,cutadapt.gz,cutadapt2.gz}`
		- `/tmp/3_align/*.{vsearch.gz,vsearch.prefilter.gz}`
		- `/tmp/3_tally/*.{vsearch.gz,unique}`
		- plus some demultiplex/unzip temporary FASTQ files in `tmp/0_demultiplex`-style paths.
	> 	Quick command to find these files ; last bit after `-exec` is to get size
	```sh
	find DiMSum_Project/tmp -type f \
	\( -name "*.fastq" -o -name "*.fastq.gz" -o -name "*.cutadapt.gz" -o -name "*.cutadapt2.gz" -o -name "*.vsearch.gz" -o -name "*.vsearch.prefilter.gz" -o -name "*.unique" \) -exec du -ch {} + | grep total$
	```
- (*later*) Reduce `--numCores` to 1 says Claude. _Runs longer but will use full 30GB so not OOM issue/memory starving. 
	- [x] *can try 3 for starters?* ; 3 cores works fine!
- Notes from Claude AI: **Suggested order:**
	1. `numCores=1` with your current `yield_size` — quick test, no code changes needed elsewhere.
	2. If still OOM, then try `yield_size=1e3` (know that runtime overhead compounds fast at this level — each chunk has fixed overhead, so 1e3 chunk size could mean 100x more chunks than 1e5).
	3. If both combined still OOM, that's a strong signal your per-read memory footprint itself is unusually large (e.g., very long reads/amplicons, or a `ShortRead`/quality-matrix scaling issue) rather than a chunking problem — move to high-mem nodes at that point rather than going lower on `yield_size`.

## Used options
- `--stranded F` : adjusts for strands that are reverse (_happens with amplicons where 2nd PCR is not in a specific direction while adding indexes?_ ) 
	- Added this since I noticed a WT read in reverse orientation initially at similar abundance as the correct orientation!

---
# ---- Run notes -----
## Legend 
_each ## entry has a (x) metric to call out status for glancing the status_
- (S): Successful run
- (F): Failed run
- (P): Partial success, needed rerunning later 
- ( #R): Run in progress
- #O : to do something

## temp : job ids
- 33216081

## Estimate scaling 
- File sizes: not a good predictor ; _need length and depth too!_
	`$ du -h -d 1 .`

| Size | Dataset | Status / resources | Read length | seq/file |
|---|---|---|---|---|
| 1.6G | `./theoAptzNNN_lokya` | _S: 6 GB RAM, 8 cores; 5 samples_ | 98 bp |  |
| 9.2G | `./theoAptzepPCR_lokya` | _S: 6 GB RAM, 8 cores; 5 samples_ | 98 bp |  |
| 8.2G | `./4NCMLibrary_madison` | _F: 30 GB RAM; 8 cores, 8 samples_ | 76 bp | 24M |
| 9.3G | `./3R5library_madison` | _F: 30 GB RAM; 8 cores, 8 samples_ | 282 bp | 102M |
| 38M | `./della_pilot_ez` |  |  |
| 309G | `./archive` |  |  |
_Note:_ file length and size are from the Input, R1 read ~ taken to be representative.
- Claude AI note: seq length influences memory for filtering. that and depth matter more than total size. 
	> check `seff <jobid>` or `sstat -j <jobid> --format=MaxRSS` once it succeeds, to get actual peak RSS per worker or Core.
	- 4NCM, `seff` estimates: I got 20 GB use and 3 h wall time with 3 cores on 4ncm data with 76 bp, 25 m reads/file.
  > So expect ~4x memory from the length increase alone → ~80GB for 3 cores. Depth (4x more reads) doesn't directly add memory, but do request some buffer: round up to ~90-100GB total to be safe.
  > Wall time scaling: total work ≈ length × depth = 16x more data to process. Expect wall time in the 12-48h range
  > Suggested to lower numCores to 1 or 2; _will try this later_

# 8/Oct/26 - post processing 
- created a base script on the NNN 
- Expanding it to 3 different temperatures for Madison's 4NCM
- [x] Test the post processing slurm script on Lokya epPCR (33634156) ; added rclone (33634665)
```sh
sbatch post_process_slurm.sh theoAptzepPCR_lokya
```


for one category of data, we have same enriched and leak columns at the 3 different temperatures. Need to split the data into 3 groups to calculate the stuff and output in 3 different sheets. 

Here's the format: 
("theoAptzNNN_lokya/variant_data_parsed.tsv")

# 1-2/Oct/26+ : v2.0
#v2 : mask except NNNs, lenient cutadapt 3R5 etc. 

## changes 
**for Ns**
- [x] (*moved to `permittedSequence` instead*) explore the masking with small letters in wt sequence
	> **_--wildtypeSequence_** Wild-type nucleotide sequence (A/C/G/T). Lower-case bases (a/c/g/t) indicate internal constant regions to be removed (required if '_--runDemo_'=F)
- ignore cutadapt trimming? ; *might mess up length distribution if not equal?*

**for 3R5
- [x] (*didn't change much; primer dimer issue*) don't trim / remove the `--cutadapt5Second` sequence; _since read is shorter than amplicon.
	- currently `-a`'s 3' end is `required`(from the cutadapt logs); need to force the use of  `-g` instead by feeding in the linked format with optional coded in.
- (*no, this is confusing param but 3 is conservative*) `--cutadaptOverlap` should be more than 3?
---
## 4NCMLibrary
- [ ] Should we relook at including a few indels? _Come back after looking at NNN_lokya data_
	- [ ] (v2.2) Rerun with indels w permitted seq : (33507762)
```sh
sbatch --mem=5G --cpus-per-task=4 --time=0:20:00 slurm_dimsum.sh 4NCMLibrary_madison -- --allow-only-caps-substitutions --indels 'none' --startStage 4
```

- [x] (S; v2.0) filter w permittedSequence, no indels
	- Run tag: 33464284; has 65,534 variants
```sh
sbatch --mem=5G --cpus-per-task=4 --time=0:20:00 slurm_dimsum.sh 4NCMLibrary_madison -- --allow-only-caps-substitutions --startStage 4
```
Distrubition of variant numbers by nham
```R
  Nham_nt count
    <dbl> <int>
1       0     1
2       1    24
3       2   252
4       3  1512
5       4  5670
6       5 13606
7       6 20411
8       7 17496
9       8  6561
```


## NNN_lokya - v2.0+
- [x] (S; v2.2) does permittedSeq + no indels (33464122) ; *down to 4,090 variants now*
	- default req high, not queing: (33463547) 
	- reduce requirements: (33463688) | fix bug with surm options: )
```sh
sbatch --mem=5G --cpus-per-task=4 --time=0:20:00 slurm_dimsum.sh theoAptzNNN_lokya -- --allow-only-caps-substitutions --indels 'none' --startStage 4
```

- [x] (v2.1) Explore `--permittedSequences` instead of masking (33445464)
	- observed same ncols as v2.0 ; Turns out all the fluff were indels (19 / 23 k); 
	- found 20 indels enriched significantly (> 1000 counts in 25 selection) -> saved for later analysis
		- No; _maybe the permittedSeqs is applied after these interim results are written?_
	- [x] Do some exploratory analysis and plotting to select interesting indels to keep.
		- Select >= 50 in any column (interesting indels only) gives total of 4,671 variants (620 of them indels and 4k expected SNPs)
	- Rerun v2.1 again; *keep the final file on scratch with indels ; simplifies future deployment* (33544524)
```sh
sbatch --mem=5G --cpus-per-task=4 --time=0:20:00 slurm_dimsum.sh theoAptzNNN_lokya -- --allow-only-caps-substitutions --startStage 4
```
- [x] (v2.0) explore the masking with small letters in wt sequence for NNN_lokya. (33324501 ;  = rerun with startStage 4)
	- [x] Update log with small caps except the NNN. 
		- [x] (Yes, primers need to be capital!) *see if primers in small caps is an issue!?* ; Causes error that is misleading: `Error: Invalid constant region sequences. Only valid nucleotide sequences allowed (A/C/T/G).` 
	- [x] The conversion to capitalization in the script -> add as an optional trigger and default to capitalizing.
	- [x] Update the filter to remove singletons in input (*assumed spurious?*)
	- result: last run had : 97265 rows ; current run: 23785 ; *still quite higher than the expected 4 k*
	- [x] doing prelim analysis ipynb on this sheet ; 
```sh
sbatch slurm_dimsum.sh theoAptzNNN_lokya
```
With masking rerun: 
```sh
sbatch slurm_dimsum.sh theoAptzNNN_lokya -- --no-capitalize-WT --numCores 8
```
- Intermediate runs with issues: 
	- 33329551: Interrupted dimsum call | 33333226: forgot to pull | 33333331 : something
	- 33333251: start stage can't be 4
	- 33334220: takes too long to start. but left it running
- Distrubution of nham variant numbers
```R
  Nham_nt count
    <dbl> <int>
1       0     1
2       1    18
3       2   135
4       3   540
5       4  1215
6       5  1455
7       6   725
8      NA 19695 # these appear spurious except 20
```


## (S: debugged, proved) 3R5  - v2.0.1
- [x] (*doesn't change anything*) Test out if the cutadapt without the `3First` / `3Second` options works. (33216081)
	- *is unlikely looking at the cutadapt logs of 4NCM.* / 
	- **Result**: Found ==primer dimers==, so cutadapt was doing the right thing by deleting these reads!
	- Logistics: Need less RAM, lets do more cores to try. with start and stop stages
		- Note: Need to run only stage dimsum to avoid copying a mix of old and new data over with rclone. `--section dimsum` before the `-- --dimsum options`
```sh
sbatch --mem=40G --cpus-per-task=12 --time=2:00:00 slurm_dimsum.sh 3R5library_madison -- --startStage 1 --stopStage 2 --numCores 8
```
- [x] To prove this primer dimer thing, let's run a custom `.sh` with fastqc for length distribution before and after cutadapt-special with `--novoseq-trim=20` without trimming primers
	- Command to execute the cutadapt (*within an sinteractive; dimsum mamba env activated*)
```sh
cutadapt --nextseq-trim=20 -o .. data_staging/3R5library_madison/*S1*R1*
```

# 18/Sep/26: v1.2_low numCores, keep intermediate files 
#v1
## (S) 3R5 madison

- [x] (Run.. ; 19/Sep/26) run with 100 GB RAM, 26 cores (numCores=3) and 24 h: `32712083`
```sh
sbatch --mem=100G --cpus-per-task=26 --time=24:00:00 slurm_dimsum.sh 3R5library_madison
```
- [x] Wait on :4NCM iterations with numCores 3 and 1 (and try 1) vs ~~try high mem directly?~~
- (F) (17/Sep/26) Submitted batch job 32673400
	- went OOM on 5 segments after `Filtering aligned reads...` stage in the `dimsum_stage_vsearch.R` script (presumably, since that was the last `_message`

## (S) 4NCM, madison


- [x] Run with numCores 3, and saving intermediate files : 32703637
	```sh
	sbatch slurm_dimsum.sh 4NCMLibrary_madison
	```
- (17/Sep/26) Run stuff: (*failed after 2 h*) Got OOM killed again : 32676685

(_unnecessary_) madison: 4NCM : merge Ls into R
	- No real need to trasnfer data: it's just single file so took the long time to just rename the files ; 
		- transfer data from : /scratch/alpine/c838573989@colostate.edu/data_staging/4NCMLibrary_madison/ to .. projets/data
		- rclone transfer to sharepoint for backup
	- For future reproducibility, you can do either;
	- reset the config/.txt to use the old Lx filenames ; and add a switch to to correct file format `--fastqFileExtension ".fq"`
	- Add a quick helper script to rename the files

# 17/Sep/26 : v1.1_with permissive filtering, low memory optimizations
#v1 = permissive filtering (nham <= 25)
rerun full workflow of Lokya's
## (S) NNN_Lokya

sbatch slurm_dimsum.sh theoAptzNNN_lokya
- [x] (*completed*) Submitted batch job 32677190
- [x] reupload html report file: remove the old report.html (*other fastq reports not essential ~ will be identical too?;*)
```sh
sbatch --mem=2G --cpus-per-task=1 --time=1:00:00 slurm_dimsum.sh theoAptzNNN_lokya --section copy
```
- (F)(failed) sbatch slurm_dimsum.sh theoAptzNNN_lokya -- --startStage 4
	- Submitted batch job 32676881 : failed: file not found

## (S) epPCR_Lokya
- [x] same, completed without the start stage. 32677192.out
- [x] reupload html report file: almost same cmd as above

sbatch slurm_dimsum.sh theoAptzepPCR_lokya -- --startStage 4
(failed) Submitted batch job 32676884

## (F) startStage 4
Rerun lokya's data starting at stage 4: _to save on the initial steps compute time.._
- overwrites old files so saving the table, PDFs, and report.html in a side folder in sharepoint for backup.
- [x] Check if this works or if starting from stage 4 requires fastq files pointed in the results dir instead. Can write a switch for this.
(?) _all stuff was pending so suspicious_
  - Need to have run previously with retainIntermediate files flag.
  - (?) Fails, file names after cutadapt are different; 
```sh
./2_trim/GS2555NNNCM25uMpassedLib_R2_001.fastq.gz.cutadapt1-forward.fastq.gz
./2_trim/GS2556NNNCM50uMpassedLib_R2_001.fastq.gz.cutadapt.untrimmed.fastq.gz
./2_trim/GS2592NNNCM25uMNoTheoLib_R1_001.fastq.gz.cutadapt1-forward.fastq.gz
./2_trim/GS2553NNNCMInputLib_R2_001.fastq.gz.cutadapt.untrimmed.fastq.gz
./2_trim/GS2592NNNCM25uMNoTheoLib_R2_001.fastq.gz.cutadapt1-reverse.fastq.gz
./2_trim/GS2556NNNCM50uMpassedLib_R1_001.fastq.gz.cutadapt1-forward.fastq.gz
```

## (S) demo : della_pilot_ez
sbatch slurm_dimsum.sh
Submitted batch job 32663965


# 16/Sep/26:  v0
#v0 = _First run with default params, was truncating at hamming dist of 2_: labelled `2 mutations_only` / `upto 2 mutations`

## (F?) sbatch slurm_dimsum.sh 3R5library_madison
_what happened here?_ ~ OOM?

---

## (F) sbatch slurm_dimsum.sh 4NCMLibrary_madison
error: due to file extension being `.fq`



---
## (P) sbatch slurm_dimsum.sh theoAptzepPCR_lokya
squeue -j 32625752. Interrupted during `rclone` after 2 h
	`slurmstepd: error: *** JOB 32625752 ON c3cpu-e2-u2 CANCELLED AT 2026-09-16T14:06:13 DUE TO TIME LIMIT ***`


--------
## (P) sbatch slurm_dimsum.sh theoAptzNNN_lokya --section copy
- Run : 32622941.out
- variant python run with partial failed rclone: 32624519.out
- redo rclone copy: 32627078.out

