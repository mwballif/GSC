*==============================================================================
* 0_setup.do
*
* Purpose: Hold the paths and the experiment's sector definition in one place.
* Reads:   nothing
* Writes:  nothing; sets globals
*
* Every do-file here runs this first, so each one also works standalone. Globals
* are set only when empty, which is how validate.do points the same code at the
* baseline panels.
*
/* NOTE: the baseline in data_processing/ hardcodes its paths and has no setup */
/* file. This one exists because the sector switch has to reach three do-files. */
*==============================================================================

* Input and output directory. The MATLAB extractors write panel_A-D here and
* every panel built below is written back here.
if "$GSC_PROC"  == "" global GSC_PROC  "../../../data/processed_2"
if "$GSC_RAW"   == "" global GSC_RAW   "../../../data/raw"
if "$GSC_CROSS" == "" global GSC_CROSS "../../../data/crosswalks"

global GSC_INTER "$GSC_PROC/intermediate"

capture mkdir "$GSC_PROC"
capture mkdir "$GSC_INTER"

*--- the experiment switch -----------------------------------------------------
* 1 puts distributive trade in MAN rather than SER, which is the experiment.
* 0 restores the baseline sector definition; validate.do uses that to separate
* the port from the experiment.
if "$GSC_TRADE_TO_GOODS" == "" global GSC_TRADE_TO_GOODS 1

*--- sector maps ---------------------------------------------------------------
* These must match the M_sectors vectors in the MATLAB extractors, because the
* price index has to use the same sector definition as the quantities it
* deflates. Three maps move:
*
*   LR socio-economic accounts   GtH   from SER to MAN
*   WIOD 2016 accounts           G*, I from SER to MAN   (handled in PART 3)
*   PLD 2023 subsectors          trd   from SER to MAN   (trd is G plus I)
*
/* NOTE: hotels and restaurants travel with trade because the LR accounts */
/* report G and H as the single code GtH and cannot split them.           */

if $GSC_TRADE_TO_GOODS {
    global MAN_LR  "CtE GtH"
    global SER_LR  "F I JtQ"
    global MAN_PLD "min man pu trd"
    global SER_PLD "con tra bus fin dwe pub oth"
}
else {
    global MAN_LR  "CtE"
    global SER_LR  "F GtH I JtQ"
    global MAN_PLD "min man pu"
    global SER_PLD "con trd tra bus fin dwe pub oth"
}

di as txt "0_setup.do: writing to $GSC_PROC, trade_to_goods = $GSC_TRADE_TO_GOODS"
