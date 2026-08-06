*==============================================================================
* validate.do
*
* Purpose: Check this arm's do-files against the baseline Stata output.
* Reads:   data/processed/panel_A-C.csv and the baseline _2country panels
* Writes:  a scratch copy of the panels in /tmp/gsc_validate, plus a report
*
* Runs the builders here on the BASELINE panels with $GSC_TRADE_TO_GOODS = 0, so
* the sector definition matches data_processing/. Any difference from the CSVs
* that data_processing/stata_code/run.do wrote is a bug in this copy, not in the
* experiment, because the experiment lives in the MATLAB extractors and in the
* sector maps this run switches off.
*
/* NOTE: writes to a scratch directory, never to data/processed. */
/* NOTE: run this from stata_code/, like every other file here. */
*==============================================================================

* Point the builders at the scratch directory and turn the experiment off.
* 0_setup.do sets its globals only when empty, so these win.
global GSC_PROC "/tmp/gsc_validate"
global GSC_TRADE_TO_GOODS 0

capture mkdir "/tmp/gsc_validate"
capture mkdir "/tmp/gsc_validate/intermediate"

foreach p in panel_A panel_B panel_C {
    copy "../../../data/processed/`p'.csv" "$GSC_PROC/`p'.csv", replace
}

*--- run the builders in run.do's order ----------------------------------------

do "1_process_raw_data.do"
do "makeImpExpSectorPanel.do"
do "makecountrypanel.do"
do "MakeCountrySectorPanel.do"

*--- compare -------------------------------------------------------------------
* Scale-aware, as in the R port's validate.R: differences of two large numbers
* (nx) and shares near zero both make a plain relative deviation misleading, so
* every column is scaled by its own root mean square.

capture program drop gsc_cmp
program define gsc_cmp
    syntax anything(name=fname), Keys(string)

    local base "../../../data/processed"
    local test "$GSC_PROC"

    di ""
    di as txt "== `fname' =="

    tempfile A B

    import delimited "`base'/`fname'", clear
    local nA = _N
    quietly ds, has(type numeric)
    local numA "`r(varlist)'"
    save `A'

    import delimited "`test'/`fname'", clear
    local nB = _N
    save `B'

    di as txt "   rows: baseline `nA', this copy `nB'"

    * Numeric columns to compare, excluding the merge keys.
    local cmpvars ""
    foreach v of local numA {
        local iskey 0
        foreach k of local keys {
            if "`v'" == "`k'" local iskey 1
        }
        if !`iskey' local cmpvars "`cmpvars' `v'"
    }

    use `A', clear
    foreach v of local cmpvars {
        rename `v' `v'_s
    }
    keep `keys' *_s
    merge 1:1 `keys' using `B', keep(3) nogen
    di as txt "   matched rows: " _N

    foreach v of local cmpvars {
        capture confirm numeric variable `v'
        if _rc {
            di as txt "     " %-13s "`v'" "  absent from this copy"
            continue
        }
        quietly gen double _d  = abs(`v' - `v'_s)
        quietly gen double _sq = `v'_s^2
        quietly su _sq, meanonly
        local scl = sqrt(r(mean))
        quietly su _d, meanonly
        local dev = r(max) / max(`scl', 1e-12)
        local flag "match"
        if `dev' > 1e-6 local flag "DIFF"
        di as txt "     " %-13s "`v'" "  max dev / scale " as res %9.3e `dev' as txt "   `flag'"
        drop _d _sq
    }
end

gsc_cmp CountryPanel_2country.csv,       keys(country year)
gsc_cmp CountrySectorPanel_2country.csv, keys(country sector year)
gsc_cmp ImpExpSectorPanel_2country.csv,  keys(exporter importer sector year)

di ""
di as txt "validate.do complete."
