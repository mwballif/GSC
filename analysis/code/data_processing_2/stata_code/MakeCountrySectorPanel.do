*==============================================================================
* MakeCountrySectorPanel.do
*
* Purpose: Build the country-sector panel, 1965-2014, for 25 regions and for the
*          two-country USA/ROW system, including internationally comparable
*          sectoral price levels.
* Reads:   $GSC_INTER/panel_B.dta, the two socio-economic accounts,
*          pld2023_dataset.dta, bilateral_totals.dta, CountryPanel.csv
* Writes:  CountrySectorPanel.csv, CountrySectorPanel_2country.csv
*
* This is the only file in the Stata half that the experiment touches. The
* sector maps in PARTS 2, 3 and 4 come from $MAN_LR / $SER_LR / $MAN_PLD /
* $SER_PLD and the $GSC_TRADE_TO_GOODS switch in 0_setup.do, so that the price
* index uses the same sector definition as the quantities the MATLAB extractors
* built. Everything else is the baseline file.
*
/* NOTE: makecountrypanel.do must run first; this reads xr from CountryPanel.csv. */
*==============================================================================

do "0_setup.do"

*--- PART 1: WIOT quantities from panel_B --------------------------------------

use "$GSC_INTER/panel_B.dta", clear
rename country country_numcode

* Rename so they do not collide with the SEA series of the same name below.
rename go go_wiot
rename va va_wiot

merge m:1 country_numcode using "$GSC_INTER/country_num_crosswalk.dta", nogen
sort country year
rename sector sector_numcode
gen sector = ""
replace sector = "AGR" if sector_numcode == 1
replace sector = "MAN" if sector_numcode == 2
replace sector = "SER" if sector_numcode == 3

tempfile csy_mat
save `csy_mat'

*--- PART 2: Long Run socio-economic accounts, 1965-2000 -----------------------

use "$GSC_INTER/lr_wiod_sea_final.dta", clear

* Drop Hong Kong, which is not in the 2016 release.
drop if countrycode == "HKG"

reshape long y, i(countrycode var isic3) j(year)
replace var = lower(var)
reshape wide y, i(countrycode year isic3) j(var) string

rename ygo go
rename yva va
rename yii ii
rename ygo_pi go_pi
rename countrycode country

* Build constant-price gross output at the subsector level.
gen go_95 = go / (go_pi / 100)

* Map subsectors to the three broad sectors.
*
/* EXPERIMENT: GtH sits in $MAN_LR rather than $SER_LR. See 0_setup.do. */
gen sector = ""
replace sector = "AGR" if isic3 == "AtB"
foreach s of global MAN_LR {
    replace sector = "MAN" if isic3 == "`s'"
}
foreach s of global SER_LR {
    replace sector = "SER" if isic3 == "`s'"
}

* Aggregate to three sectors and form the implicit sector deflator.
*
/* NOTE: subsectors with missing prices are excluded from the deflator. */
local lrwiod_vars "go va ii"

gen go_for_pi = go if !missing(go_95)
collapse (sum) `lrwiod_vars' go_95 go_for_pi, by(country year sector)
drop if sector == ""

gen go_pi = go_for_pi / go_95
drop go_for_pi

gen source = 0

tempfile lrdata
save `lrdata'

* Keep the country list, to filter the 2016 release to matching countries.
keep country
duplicates drop
tempfile lrcountries
save `lrcountries'

*--- PART 3: WIOD 2016 socio-economic accounts, 2000-2014 ----------------------

use "$GSC_INTER/Socio_economic_Accounts.dta", clear

* Keep only the countries present in the Long Run release.
merge m:1 country using `lrcountries', keep(3) nogen

rename code isic4

* Rename the year columns to g<year>, which is what reshape needs.
foreach v of varlist E-S {
    local lbl : variable label `v'
    rename `v' g`lbl'
}

reshape long g, i(country variable isic4) j(year)
replace variable = lower(variable)
reshape wide g, i(country year isic4) j(var) string

rename ggo go
rename gva va
rename gii ii
rename ggo_pi go_pi
destring go_pi, replace
destring va, replace
destring ii, replace
destring go, replace

* Build constant-price gross output at the subsector level.
gen go_10 = go / (go_pi / 100)

* Map subsectors to the three broad sectors. The three lines are applied in
* order, so a later one overrides an earlier one.
gen sector = ""
replace sector = "AGR" if regexm(isic4, "A")
replace sector = "MAN" if regexm(isic4, "[BCDE]")
replace sector = "SER" if regexm(isic4, "[FGHIJKLMNOPQRSTU]")

* EXPERIMENT: distributive trade and accommodation/food count as goods. G45,
* G46, G47 and I move to MAN, matching M_sectors in extract_data_R16.m.
if $GSC_TRADE_TO_GOODS {
    replace sector = "MAN" if regexm(isic4, "^G") | isic4 == "I"
}

preserve

*--- PART 4: PPP weights from the WIOD 2005 cross-section ----------------------

* Map ISIC4 codes to the PLD subsector classification. This mapping does not
* change with the experiment: trd is G plus I either way. What changes is which
* broad sector trd belongs to, below.
local ppp_sectors "agr min man pu con trd tra bus fin dwe pub oth"
local ppp_aggmap  "A B C DE F GI H JMN K L OPQ RSTU"
local n : word count `ppp_sectors'

gen ppp_sector = ""
forvalues i = 1/`n' {
    local ppp_des : word `i' of `ppp_sectors'
    local ppp_el  : word `i' of `ppp_aggmap'
    replace ppp_sector = "`ppp_des'" if regexm(isic4, "^[`ppp_el']")
}

* Keep 2005 and aggregate to the PLD subsector level.
drop if year != 2005
drop description
collapse (sum) go go_10, by(country ppp_sector)

* Map PLD subsectors to the three broad sectors.
*
/* EXPERIMENT: trd sits in $MAN_PLD rather than $SER_PLD. See 0_setup.do. */
gen sector = ""
replace sector = "AGR" if ppp_sector == "agr"
foreach s of global MAN_PLD {
    replace sector = "MAN" if ppp_sector == "`s'"
}
foreach s of global SER_PLD {
    replace sector = "SER" if ppp_sector == "`s'"
}

* Compute each subsector's gross output share within its broad sector.
bysort country sector: egen go_sect_tot = sum(go)
gen ppp_weight = go / go_sect_tot

keep country ppp_sector sector ppp_weight
tempfile ppp_weights
save `ppp_weights'

restore

*--- PART 5: aggregate the 2016 release to three sectors -----------------------

local lrwiod_vars "go va ii"

gen go_for_pi = go if !missing(go_10)
collapse (sum) `lrwiod_vars' go_10 go_for_pi, by(country year sector)
drop if sector == ""

gen go_pi = go_for_pi / go_10
drop go_for_pi

gen source = 1

*--- PART 6: splice the two releases at 2000 -----------------------------------

append using `lrdata'

merge 1:1 country sector source year using `csy_mat', nogen
tempfile ownprice
save `ownprice'

* Attach the nominal exchange rate, needed to build the price level in PART 8.
import delimited "$GSC_PROC/CountryPanel.csv", clear
keep country year xr
expand 3
bysort country year: gen sector = ""
bysort country year: replace sector = "AGR" if _n == 1
bysort country year: replace sector = "MAN" if _n == 2
bysort country year: replace sector = "SER" if _n == 3

merge 1:m country year sector using `ownprice'
drop if _merge != 3
drop _merge

* Convert the 2016 release from national currency to USD.
replace go = go / xr if source == 1
replace va = va / xr if source == 1
replace ii = ii / xr if source == 1

* Convert the Long Run price index from USD to local currency, matching the
* 2016 release index.
replace go_pi = go_pi * xr if source == 0

* Chain-link the series that have no accounting identity to preserve.
*
/* NOTE: the trade quantities are not spliced here; they come from the matrix. */
local vars "go go_pi va ii va_wiot consump invest"

* Compute the WIOD growth rates.
*
/* NOTE: source must be in the sort, or the 2000 rows tie. */
sort country sector year source
foreach var of local vars {
    by country sector: gen `var'_gr = `var'/`var'[_n-1] if source == 1 & year != 2000
}

* Start the spliced series at the Long Run levels.
foreach var of local vars {
    gen `var'_spliced = `var' if source == 0
}

* Keep the Long Run version of the 2000 splice point.
drop if year == 2000 & source == 1

* Extend forward using the WIOD growth rates.
sort country sector year
foreach var of local vars {
    bysort country sector (year): replace `var'_spliced = `var'_spliced[_n-1] * `var'_gr if source == 1
}

foreach var of local vars {
    replace `var' = `var'_spliced
}

* Take the trade quantities from the single spliced bilateral matrix, replacing
* the separately spliced versions from panel_B.
drop nx go_wiot expend imports exports
merge 1:1 country sector year using "$GSC_INTER/bilateral_totals.dta", ///
    keepusing(go_mat exp_mat xp_mat mp_mat nx_mat) nogen
rename go_mat  go_wiot
rename exp_mat expend
rename xp_mat  exports
rename mp_mat  imports
rename nx_mat  nx

* Check the identities: gross output minus total expenditure must equal exports minus
* imports cell by cell, and net exports must sum to zero across regions.
gen double _idgap = reldif(go_wiot - expend, nx)
qui su _idgap, detail
di as txt "  GO-E vs exports-imports, max |reldif| = " as res %9.2e r(max)
preserve
collapse (sum) nx, by(year)
qui su nx
di as txt "  world net exports, max |sum_i NX_i| = " as res %12.4f max(abs(r(min)),abs(r(max)))
restore
drop _idgap

* xr is kept for PART 8.
keep country year sector xr `vars' nx go_wiot expend imports exports

*--- PART 7: anchor the price index to 2005 ------------------------------------

bysort country sector: gen  go_pi_05     = go_pi if year == 2005
bysort country sector: egen go_pi_05fill = max(go_pi_05)
bysort country sector: replace go_pi = go_pi / go_pi_05fill
drop go_pi_05
compress

*--- PART 8: build internationally comparable price levels ---------------------

preserve

* Load the PLD 2005 benchmark.
use "$GSC_INTER/pld2023_dataset.dta", clear
drop if year != 2005
rename sector ppp_sector
rename countrycode country

merge 1:1 country ppp_sector using `ppp_weights', keep(3) nogen

* Take a gross-output-weighted average PPP for each broad sector.
*
/* NOTE: weights are renormalized over subsectors that have a PPP. */
bysort country sector: egen ppp_wtot = total(cond(!missing(PPP_y), ppp_weight, .))
gen ln_ppp_w = ln(PPP_y) * ppp_weight / ppp_wtot
collapse (sum) ln_ppp_w, by(country sector)
gen ppp = exp(ln_ppp_w)

* Expand the 2005 benchmark to every year.
expand 50
bysort country sector: gen year = 1964 + _n

tempfile ppp_05
save `ppp_05'

restore

* Merge the PPPs into the panel.
*
/* NOTE: keep(1 3) keeps the residual region, which has no price. */
merge 1:1 country sector year using `ppp_05', keep(1 3) nogen

* Form the price level in current USD, relative to USA 2005 = 1. go_pi is the
* within-country index (2005 = 1, local currency), ppp is the 2005 gross output
* PPP and xr the nominal exchange rate, both local currency per USD. For the USA
* ppp and xr are one, so this reduces to go_pi.
gen go_lvl = go_pi * ppp / xr

drop go_pi_05fill ln_ppp_w xr

*--- PART 9: save the 25-region panel ------------------------------------------

export delimited "$GSC_PROC/CountrySectorPanel.csv", replace

*--- PART 10: USA vs ROW two country aggregation -------------------------------
*
* Additive quantities are summed; nx sums cleanly because intra-ROW flows net
* out. Prices are gross-output-weighted geometric means of the LEVELS, taken
* within each year.
*
/* NOTE: gross exports and imports are dropped; intra-ROW trade is domestic here. */
/* NOTE: prices are a mean of LEVELS, not changes, so a cheap entrant lowers the index. */
/* NOTE: go_pi is a local currency index; its cross-country mean is meaningless. */

preserve
keep if country == "USA"
tempfile usa_csp
save `usa_csp'
restore

drop if country == "USA"

local vars_sum "go va ii go_wiot va_wiot expend consump invest nx"
local vars_geo "go_pi go_lvl"
local vars_csp "`vars_sum' `vars_geo'"

sort country sector year

foreach var of local vars_geo {

    * Output shares among the countries that have a price, within sector-year.
    bysort sector year: egen tw_`var' = total(cond(!missing(`var'), go, .))
    gen ws_`var' = go / tw_`var' if !missing(`var')

    * Weighted log level. Summing over countries gives the log geometric mean.
    gen gm_`var' = ws_`var' * ln(`var')
}

collapse (sum) `vars_sum' gm_*, by(sector year)

foreach var of local vars_geo {
    gen `var' = exp(gm_`var')
}

drop gm_*
gen country = "ROW"

append using `usa_csp'
keep country year sector `vars_csp'
order country year sector `vars_csp'
sort country sector year

export delimited "$GSC_PROC/CountrySectorPanel_2country.csv", replace
