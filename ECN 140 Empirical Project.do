****************************************************
** ECN 140 Empirical Project – Benjamin Bartel    **
****************************************************

global proj "C:\Users\marcu\OneDrive\Desktop\ECN 140\Empirical Project"
import excel "${proj}\ECN 140 EMPIRICAL PROJECT.xlsx", sheet("COMPOSITE") firstrow
drop if ZHVI <= 0

ds YEAR, not
gen valid_obs = 1
foreach v of varlist `r(varlist)' {
    replace valid_obs = . if missing(`v')
}
estpost summarize `r(varlist)' if valid_obs == 1
esttab using "${proj}\summary_stats.rtf", title("Table 5. Summary Statistics") cells("mean sd min max") label replace
drop valid_obs

gen ln_ZHVI = ln(ZHVI)
gen ratio_pct = RATIO * 100
gen ratio_sq_2 = ratio_pct^2
gen growth_sq = GROWTH^2
gen mhi_sq = MHI^2

****************************************************
** SECTION 1: OLS Models (2022 Only)              **
****************************************************

reg ZHVI RATIO if YEAR == 1
eststo reg_simple
reg ZHVI RATIO GROWTH MHI mhi_sq COASTAL if YEAR == 1
eststo reg_multi_linear
reg ZHVI RATIO GROWTH growth_sq MHI COASTAL if YEAR == 1
eststo reg_quad
esttab reg_simple reg_multi_linear reg_quad using "${proj}\ols_models.rtf", title("Table 1. OLS Regression Results – ZHVI and Permitting (2022)") order(RATIO GROWTH growth_sq MHI mhi_sq COASTAL) varlabels(RATIO "Permit Ratio" GROWTH "GDP Growth Rate" growth_sq "GDP Growth Rate²" MHI "Median Income" mhi_sq "Median Income²" COASTAL "Coastal Dummy") label b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) mtitles("Simple OLS" "Income Quadratic OLS" "Growth Quadratic OLS") nonotes noomitted replace

****************************************************
** SECTION 2: Quadratic Fit (ZHVI on Ratio_pct)   **
****************************************************

reg ln_ZHVI ratio_pct ratio_sq_2 MHI COASTAL if YEAR == 1, vce(robust)
eststo reg_quad_2022
predict ln_zhvi_hat if e(sample)
twoway (scatter ln_ZHVI ratio_pct if YEAR == 1 & ratio_pct <= 5, mcolor(navy) msize(small)) (lowess ln_zhvi_hat ratio_pct if YEAR == 1 & ratio_pct <= 5, bwidth(0.8) lcolor(maroon) lwidth(medthick)), title("Figure 1. Permitting Intensity and Log Housing Prices (2022)") xtitle("Permitting Intensity") ytitle("Log Housing Price") legend(order(1 "Counties" 2 "Smoothed Fit") ring(0) pos(5) region(lstyle(none))) graphregion(color(white)) bgcolor(white) name(quad_plot, replace)
graph export "${proj}\graph_smoothed_quadratic_fit.png", replace as(png) width(2000)

****************************************************
** SECTION 3: Residual Plot – Cross-Section (2022)**
****************************************************

reg ln_ZHVI MHI COASTAL if YEAR == 1
eststo reg_controls_2022
predict zhvi_resid if YEAR == 1, residuals
reg RATIO MHI URBAN GROWTH if YEAR == 1
predict ratio_resid if YEAR == 1, residuals
gen include_resid = !missing(zhvi_resid, ratio_resid) & ratio_resid > 0 & ratio_resid <= 3 & abs(zhvi_resid) <= 2
twoway (scatter zhvi_resid ratio_resid if YEAR == 1 & include_resid, msize(small) mcolor(navy)) (lfit zhvi_resid ratio_resid if YEAR == 1 & include_resid, lcolor(maroon) lwidth(medthick)), title("Figure 2. Adjusted Housing Prices vs. Permitting Intensity (2022)") xtitle("Permitting Intensity (Residual)") ytitle("Log Housing Price (Residual)") legend(order(1 "Counties" 2 "Fitted Trend Line") ring(0) pos(5) region(lstyle(none))) graphregion(color(white)) bgcolor(white)
graph export "${proj}\graph_residual_vs_ratio.png", replace as(png) width(2000)
reg zhvi_resid ratio_resid if YEAR == 1 & include_resid 
eststo reg_resid 
esttab reg_resid using "${proj}\residual_output.rtf", title("Table 2. Residualized Regression – Log Housing Price on Permit Ratio (2022)") label b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) varlabels(ratio_resid "Permit Ratio Residual") nonotes noomitted replace

****************************************************
** SECTION 4: Fixed Effects Panel Regression      **
****************************************************

egen county_id = group(COUNTY)
xtset county_id YEAR
summarize ratio_pct, detail
scalar p1 = r(p1)
scalar p99 = r(p99)
keep if ratio_pct >= p1 & ratio_pct <= p99
xtreg ln_ZHVI ratio_pct ratio_sq_2 GROWTH MHI i.YEAR, fe vce(cluster county_id)
eststo reg_fe
predict ln_ZHVI_hat, xb
predict ln_ZHVI_resid, residuals
twoway (scatter ln_ZHVI_resid ratio_pct if ratio_pct >= 0 & ratio_pct <= 5, mcolor(navy) msize(small)) (lowess ln_ZHVI_resid ratio_pct if ratio_pct >= 0 & ratio_pct <= 5, bwidth(0.8) lcolor(maroon) lwidth(medthick)), title("Figure 3. Within-County Residuals vs. Permitting Intensity (2021–2022)") xtitle("Permitting Intensity (%)") ytitle("Log Housing Price Residual (FE Model)") legend(order(1 "Counties" 2 "Smoothed Fit") ring(0) pos(5) region(lstyle(none))) graphregion(color(white)) bgcolor(white) name(fe_plot, replace)
graph export "${proj}\graph_fe_resid_vs_ratio.png", replace as(png) width(2000)

esttab ft_quad_ols ft_fe using "${proj}\coef_output_ftmodels.rtf", title("Table 3. Coefficient Estimates – Ratio Quadratic vs. FE Model") label b(%9.3f) se(%9.3f) star(* 0.10 ** 0.05 *** 0.01) mtitles("Ratio Quadratic OLS" "Fixed Effects Panel (2021–2022)") order(ratio_pct ratio_sq_2 GROWTH MHI COASTAL) varlabels(ratio_pct "Permit Ratio (%)" ratio_sq_2 "Permit Ratio² (%)" GROWTH "GDP Growth Rate" MHI "Median Income" COASTAL "Coastal Dummy") nonotes noomitted replace

****************************************************
** SECTION 5: Growth vs. Permitting Scatter       **
****************************************************

twoway (scatter GROWTH RATIO if RATIO <= 0.05, mcolor(navy) msize(small)) (lfit GROWTH RATIO if RATIO <= 0.05, lcolor(maroon) lwidth(medthick)), title("Figure 4. Growth vs. Permitting Intensity") xtitle("Permitting Intensity (RATIO)") ytitle("GDP Growth Rate") legend(order(1 "Counties" 2 "Fitted Line") ring(0) pos(5) region(lstyle(none))) graphregion(color(white)) bgcolor(white) name(growth_plot, replace)
graph export "${proj}\graph_growth_vs_ratio.png", replace as(png) width(2000)

****************************************************
** SECTION 6: F-Tests (OLS vs. FE Models)         **
****************************************************

reg ln_ZHVI ratio_pct ratio_sq_2 MHI COASTAL if YEAR == 1
eststo ft_quad_ols
test ratio_pct
test ratio_sq_2
test ratio_pct ratio_sq_2
scalar Fstat_ols = r(F)
scalar pval_ols = r(p)
estadd scalar Ftest = Fstat_ols
estadd scalar pvalue = pval_ols

xtreg ln_ZHVI ratio_pct ratio_sq_2 GROWTH MHI i.YEAR, fe
eststo ft_fe
test ratio_pct ratio_sq_2
scalar Fstat_fe = r(F)
scalar pval_fe = r(p)
estadd scalar Ftest = Fstat_fe
estadd scalar pvalue = pval_fe

esttab ft_quad_ols ft_fe using "${proj}\f_test_results.rtf", title("Table 4. Joint Significance Tests for Permitting Terms") b(%9.2f) se(%9.2f) star(* 0.10 ** 0.05 *** 0.01) mtitles("Ratio Quadratic OLS" "Fixed Effects Panel (2021–2022)") stats(Ftest pvalue, labels("F-Test (Joint)" "P-Value")) varlabels(ratio_pct "Permit Ratio (%)" ratio_sq_2 "Permit Ratio² (%)" MHI "Median Income" COASTAL "Coastal Dummy") label replace

* Core variables
label variable COUNTY          "County"
label variable YEAR            "Year"
label variable ZHVI            "Zillow Home Value Index"
label variable PERMIT          "New Permits Issued"
label variable HOUSING         "Housing Stock"
label variable RATIO           "Permit Ratio"
label variable MHI             "Median Household Income"
label variable GROWTH          "Real GDP Growth Rate"
label variable URBAN           "Urban County Indicator"
label variable COASTAL         "Coastal County Indicator"

* Transformed variables
label variable ln_ZHVI         "Log Housing Price"
label variable ratio_pct       "Ratio (%)"
label variable ratio_sq        "Permit Ratio²"
label variable ratio_sq_2      "ratio_pct²"
label variable growth_sq       "GDP Growth Rate²"
label variable mhi_sq          "Median Income²"

* Residual diagnostics
label variable zhvi_resid      "ZHVI Residual (Cross-Sectional OLS)"
label variable ratio_resid     "Permit Ratio Residual (Cross-Sectional OLS)"
label variable include_resid   "Residual Inclusion Flag (Cross-Sectional OLS)"

* Fitted values and identifiers
label variable ln_zhvi_hat     "Fitted Log ZHVI (Quadratic OLS)"
label variable county_id       "County ID (Fixed Effects Panel ID)"
label variable ln_ZHVI_hat     "Linear Prediction (Fixed Effects Panel)"
label variable ln_ZHVI_resid   "Residuals (Fixed Effects Panel)"

* eststo sample flags
label variable _est_reg_simple     "Sample Marker – Simple OLS (RATIO Only)"
label variable _est_reg_mult~r     "Sample Marker – Income Quadratic OLS (MHI + MHI²)"
label variable _est_reg_quad       "Sample Marker – Growth Quadratic OLS (GROWTH + GROWTH²)"
label variable _est_reg_c~2022     "Sample Marker – Controls-Only OLS (Cross-Section, 2022)"
label variable _est_reg_q~2022     "Sample Marker – Quadratic Fit OLS (ZHVI on ratio_pct²)"
label variable _est_reg_fe         "Sample Marker – Fixed Effects Panel Regression (2021–2022)"
label variable _est_ft_quad~s      "Sample Marker – OLS Model Used in F-Test"
label variable _est_ft_fe          "Sample Marker – FE Model Used in F-Test"

